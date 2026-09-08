<#
.SYNOPSIS
    Xoá dữ liệu Firestore của MỘT cơ sở WorkDay.

.DESCRIPTION
    Từ bản nhiều cơ sở, dữ liệu của mỗi khách nằm trong companies/{companyId},
    và companyId chính là uid Firebase của chủ cơ sở. Vì vậy script bắt buộc
    phải biết xoá cơ sở NÀO - xem uid trong
    Console > Authentication > Users, hoặc mở Firestore > companies.

    Xoá các collection con: attendance, employees, settings; kèm document
    companies/{id} và users/{id} khi xoá sạch.

    KHÔNG THỂ HOÀN TÁC. Firestore không có thùng rác.

.PARAMETER Company
    companyId của cơ sở = uid Firebase của chủ cơ sở. BẮT BUỘC.

.PARAMETER Project
    Firebase project id. Mặc định: tick-go (bản dev: dev-asc).

.PARAMETER KeepEmployees
    Giữ lại danh sách nhân viên, chỉ xoá dữ liệu công.

.PARAMETER KeepSettings
    Giữ lại thiết lập chung (tên cơ sở, mốc OT, ngày chốt kỳ, mức lương mặc định).

.EXAMPLE
    .\tools\reset_data.ps1 -Company aBc123XyZ...
    Xoá sạch dữ liệu của cơ sở đó, kể cả hồ sơ người dùng.

.EXAMPLE
    .\tools\reset_data.ps1 -Company aBc123XyZ... -KeepEmployees -KeepSettings
    Chỉ xoá dữ liệu công, giữ nhân viên và thiết lập.

.EXAMPLE
    .\tools\reset_data.ps1 -Company aBc123XyZ... -Project dev-asc
    Dọn dữ liệu của bản DEV.

.NOTES
    Cần Firebase CLI: npm install -g firebase-tools
    Rồi đăng nhập một lần:  firebase login
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Company,
    [string]$Project = 'tick-go',
    [switch]$KeepEmployees,
    [switch]$KeepSettings
)

$ErrorActionPreference = 'Stop'

# --------------------------------------------------------- Kiểm tra Firebase CLI

$firebase = Get-Command firebase -ErrorAction SilentlyContinue
if ($null -eq $firebase) {
    Write-Host 'Chua co Firebase CLI.' -ForegroundColor Red
    Write-Host 'Cai bang:  npm install -g firebase-tools'
    Write-Host 'Roi dang nhap:  firebase login'
    exit 1
}

# ------------------------------------------------------ Danh sach can xoa

$root = "companies/$Company"
$wipeAll = (-not $KeepEmployees) -and (-not $KeepSettings)

$targets = @("$root/attendance")
if (-not $KeepEmployees) { $targets += "$root/employees" }
if (-not $KeepSettings) { $targets += "$root/settings" }
# Xoa sach thi bo luon document co so va ho so nguoi dung.
if ($wipeAll) {
    $targets += $root
    $targets += "users/$Company"
}

Write-Host ''
Write-Host '=====================================================' -ForegroundColor Yellow
Write-Host ' XOA DU LIEU WORKDAY - KHONG THE HOAN TAC' -ForegroundColor Yellow
Write-Host '=====================================================' -ForegroundColor Yellow
Write-Host ''
Write-Host ("Firebase project : {0}" -f $Project)
Write-Host ("Co so (companyId): {0}" -f $Company)
Write-Host ("Se xoa           : {0}" -f ($targets -join ', '))
if ($KeepEmployees) { Write-Host 'Giu lai          : danh sach nhan vien' -ForegroundColor Green }
if ($KeepSettings) { Write-Host 'Giu lai          : thiet lap chung' -ForegroundColor Green }
Write-Host ''

# ------------------------------------------------------------- Xac nhan

$answer = Read-Host 'Go dung chu XOA (chu in hoa) roi Enter de tiep tuc'
if ($answer -ne 'XOA') {
    Write-Host 'Da huy, khong xoa gi.' -ForegroundColor Green
    exit 0
}

# --------------------------------------------------------------- Thuc hien

foreach ($path in $targets) {
    Write-Host ''
    Write-Host ("Dang xoa {0} ..." -f $path) -ForegroundColor Cyan
    # --recursive: xoa ca document con; --force: khong hoi lai (da hoi o tren).
    firebase firestore:delete $path --recursive --force --project $Project
    if ($LASTEXITCODE -ne 0) {
        Write-Host ("Loi khi xoa {0}. Dung lai." -f $path) -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

Write-Host ''
Write-Host 'Xong. Da xoa du lieu Firestore cua co so nay.' -ForegroundColor Green
Write-Host ''

if ($wipeAll) {
    Write-Host 'CON MOT VIEC PHAI LAM TAY:' -ForegroundColor Yellow
    Write-Host '  Tai khoan dang nhap nam trong Firebase Authentication, khong nam'
    Write-Host '  trong Firestore nen script nay khong xoa duoc.'
    Write-Host ''
    Write-Host ("  Mo: https://console.firebase.google.com/project/{0}/authentication/users" -f $Project)
    Write-Host ("  Xoa user co uid {0}." -f $Company)
    Write-Host '  Chua xoa user thi tai khoan do van dang nhap duoc nhung khong con'
    Write-Host '  co so nao - app se hien danh sach rong.'
    Write-Host ''
}
