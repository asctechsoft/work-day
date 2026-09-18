# WorkDay — Chấm công & Tính lương

App Flutter chấm công hằng ngày và tự tính lương cuối tháng cho cả cơ sở.
Bản đơn giản: **3 tab • mỗi cơ sở một tài khoản • không phân quyền trong cơ sở**.

- **Package**: `com.campany.tickgo` (bản dev: `dev.asctechsoft`)
- **Firebase project**: `tick-go` (Firestore + Authentication) · bản dev dùng `dev-asc`
- **Nền tảng**: Android (iOS đã có sẵn thư mục, cần thêm `GoogleService-Info.plist`)

---

## 1. Chạy app

Có **hai môi trường**, chọn bằng cờ `--flavor` (xem mục 1.1) — mọi lệnh chạy
hoặc build Android đều phải có cờ này:

```bash
flutter pub get
flutter run --flavor dev                       # chạy hằng ngày, dữ liệu test (dev-asc)
flutter run --flavor product                   # chạy trên DỮ LIỆU THẬT — cẩn thận
flutter build apk --release --flavor product   # APK giao cho người dùng
```

APK ra ở `build/app/outputs/flutter-apk/app-product-release.apk`.

Trong VS Code, bấm F5 rồi chọn cấu hình có sẵn: **Dev Debug** ·
**Product Debug** · **Dev Profile** · **Product Release** (`.vscode/launch.json`).

### 1.1. Hai môi trường

| flavor | Firebase project | applicationId | Tên app trên máy |
|---|---|---|---|
| `dev` | `dev-asc` | `dev.asctechsoft` | WorkDay Dev |
| `product` | `tick-go` | `com.campany.tickgo` | WorkDay — **dữ liệu thật** |

- Gradle nhúng `google-services.json` theo flavor: bản dev lấy
  `android/app/src/dev/google-services.json`, bản product lấy
  `android/app/google-services.json`.
- Tầng Dart chọn cấu hình tương ứng qua `lib/core/firebase_env.dart`
  (`firebaseOptions`), đọc chính cờ `--flavor` nên hai tầng không thể lệch nhau.
- Không truyền `--flavor` thì tầng Dart rơi về **product** — đừng bỏ cờ.
- `android/app/google-services_dev.json` là bản tải từ console giữ để đối chiếu;
  tải lại thì cập nhật cả nó lẫn bản trong `src/dev/`.

---

## 2. Cần làm trên Firebase Console (một lần)

### 2.1. Bật đăng nhập Email/Password

`Authentication` → `Sign-in method` → bật **Email/Password**.

Mỗi cơ sở tự tạo tài khoản của mình: ở màn Đăng nhập bấm **"Tạo cơ sở mới"**,
nhập tên cơ sở + email + mật khẩu (≥ 6 ký tự). Lần tạo này cần có mạng.

> **Phải dùng email thật** để còn liên hệ được với khách. Tài khoản cũ kiểu
> `admin` (app tự hiểu là `admin@tickgo.app`) vẫn đăng nhập được bình thường.
>
> **App không có "Quên mật khẩu".** Khách quên mật khẩu thì bạn vào
> `Console → Authentication → Users`, mở menu ⋮ của user đó rồi chọn
> **Reset password** (gửi mail đặt lại) hoặc đổi mật khẩu trực tiếp. Người
> đang đăng nhập được thì tự đổi ở `Cài đặt → Thông tin tài khoản`.

### 2.2. Dán Security Rules

`Firestore Database` → `Rules` → dán nội dung file [`firestore.rules`](firestore.rules) → **Publish**.

Rules cách ly các cơ sở với nhau: một tài khoản chỉ đọc/ghi được nhánh
`companies/{uid}` của chính nó.

### 2.3. Tài khoản tổng (không bắt buộc)

Muốn có một tài khoản xem được báo cáo của **tất cả** cơ sở (chỉ đọc):

1. Lấy `uid` của tài khoản đó ở `Authentication` → `Users`.
2. Dán uid vào hàm `isSuperAdmin()` trong `firestore.rules` rồi **Publish** lại.
3. Ở `Firestore Database`, mở document `users/{uid}` của tài khoản đó, thêm
   trường `role` = `super` (để app hiện menu "Quản lý cơ sở" trong tab Cài đặt).

Bước 3 chỉ ảnh hưởng menu; quyền đọc thật do bước 2 quyết định. Tài khoản tổng
**không ghi được gì** vào dữ liệu của khách.

> Tài khoản tổng vẫn có 3 tab của riêng nó (rỗng, vì nó không phải cơ sở nào).
> Chỗ nó cần dùng là `Cài đặt → Quản lý cơ sở`: chọn cơ sở để xem bảng lương
> theo kỳ, xuất .xlsx, và xem **đánh giá app** cơ sở đó đã gửi.

---

## 3. Cấu trúc dữ liệu Firestore

Dữ liệu mỗi cơ sở nằm gọn trong một nhánh, `{cid}` = uid Firebase của chủ cơ sở:

| Collection | Doc ID | Nội dung |
|---|---|---|
| `companies` | `{cid}` | `orgName`, `ownerAccount`, `active`, `createdAt` |
| `companies/{cid}/employees` | tự sinh | `name`, `dailySalary`, `otRate`, `phone`, `active`, `createdAt` |
| `companies/{cid}/attendance` | `{employeeId}_{yyyy-MM-dd}` | `employeeId`, `workDate`, `month`, `status`, `workUnits`, `overtimeMinutes` |
| `companies/{cid}/settings` | `app` | `orgName`, `currency`, `otPresets`, `workHoursPerDay`, `payPeriodStartDay`, mức lương mặc định |
| `companies/{cid}/reviews` | tự sinh | Đánh giá app: `stars` (1–5), `comment`, `appVersion`, `createdAt` |
| `users` | `{uid}` | `account`, `displayName`, `companyId`, `role`, `lastLoginAt` |

**Doc ID của `attendance` được ghép từ nhân viên + ngày**, nên một nhân viên chỉ
có đúng một bản ghi cho một ngày. Chấm lại là ghi đè, không bao giờ cộng trùng.

`companyId` chính là `uid` của chủ cơ sở, nên app biết ngay đường dẫn dữ liệu
của mình mà không phải đọc thêm document nào — mở app offline vẫn vào được.

Firestore bật offline persistence: mất mạng vẫn chấm công được, có mạng lại thì
tự đồng bộ.

---

## 4. Nghiệp vụ

### Quy tắc chấm công

| Trạng thái | Số công | Khi nào dùng |
|---|---|---|
| **Đi làm** | 1 | Làm đủ ngày |
| **Nửa công** | 0,5 | Có đến làm nhưng về giữa chừng |
| **Tuỳ chỉnh** | nhập tay theo giờ | Làm không tròn nửa ngày (ví dụ 5-6 tiếng) - nhập số giờ đã làm, app tự quy đổi ra công theo "Số giờ công/ngày" ở Cài đặt để tính lương; màn hình luôn hiện lại theo **giờ** ("6h"), không hiện số công, để khỏi nhầm với ngày công |
| **Nghỉ** | 0 | Không đi làm |
| **Chưa chấm** | – | Chưa có dữ liệu, không tính công cũng không tính nghỉ |

Tăng ca (30p / 1h / 1h30 / 2h / tự nhập theo phút) ghi **riêng** với số công và không
làm thay đổi số công của ngày đó.

### Thao tác trên màn Chấm công

| Việc cần làm | Cách làm |
|---|---|
| Chấm cả danh sách đi làm | Nút **Tất cả đi làm** |
| Đổi một người sang Nghỉ | Chạm vào **ô trạng thái** |
| Nửa công, Tuỳ chỉnh (nhập giờ), hoặc bỏ chấm khi bấm nhầm | Chạm nút **⌄** ở cuối dòng nhân viên |
| Nhập tăng ca | Chạm vào **ô giờ** bên phải, nhập theo **phút** (90 = 1h30) |
| Chấm bù ngày cũ | Chạm vào **ngày** trên thanh tiêu đề để mở lịch |
| Xem lại luật chấm công | Nút **?** góc trên phải |

Lịch chọn ngày hiện **cả kỳ lương** (ví dụ 28/08 → 27/09) chứ không cắt theo
tháng dương lịch, và tô màu từng ngày để biết ngày nào đã chấm:
**xanh** = chấm đủ cả danh sách · **cam** = mới chấm được một phần ·
**không màu** = chưa chấm ngày nào.

Mỗi ô ngày có **số âm lịch** nhỏ bên dưới; mùng 1 âm hiện cả tháng ("1/8", có
chữ "N" nếu là tháng nhuận). Ngày âm đầy đủ kèm can chi ("Âm lịch 24/7 Bính
Ngọ") nằm ở thẻ trên cùng của lịch, còn thanh chọn ngày ở tab Chấm công luôn
hiện dòng "Âm 24/7" ngay dưới ngày dương.

- Bấm nhầm "Tất cả đi làm" → chọn **Hoàn tác** trong thông báo hiện ra.
- Chấm nhầm một người → chạm nút **⌄** ở cuối dòng của họ → **Bỏ chấm công**, đưa về "Chưa chấm".
- **Không chấm được cho ngày chưa tới.** Phải đợi đúng sang ngày đó. Ngày đã
  qua thì vẫn chấm bù và sửa lại bình thường.
- Ô thống kê **Đã chấm 2/12** cho biết còn bao nhiêu người chưa chấm.

### Công thức tính lương

```
Lương công   = Tổng công    × Lương/ngày
Tiền tăng ca = Tổng giờ OT  × Đơn giá OT/giờ
Tổng lương   = Lương công   + Tiền tăng ca
```

Đặt đơn giá OT = 0 nếu cơ sở không trả tăng ca riêng.
Lương **luôn tính lại** từ dữ liệu công của kỳ đang chọn — không có
trạng thái chốt/khoá bảng lương.

### Kỳ lương tuỳ chỉnh

Mặc định kỳ lương trùng đúng tháng dương lịch (01 → hết tháng).
Nếu cơ sở chốt công giữa tháng, vào `Cài đặt → Thiết lập chung → Kỳ lương`
và chọn ngày bắt đầu:

| Ngày bắt đầu | Kỳ của tháng 09/2026 |
|---|---|
| 1 (mặc định) | 01/09 → 30/09 |
| 26 | 26/08 → 25/09 |
| 16 | 16/08 → 15/09 |

Kỳ luôn **kết thúc trong tháng được chọn**. Chọn được ngày 1–28.

Ở tab Tổng quan, dòng **"Tính công 01/09 - 30/09/2026"** ngay dưới tên kỳ luôn
cho biết kỳ đang xem gồm những ngày nào. Chạm vào tên kỳ để mở **danh sách kỳ**
— chọn thẳng kỳ cần xem thay vì bấm ‹ › nhiều lần; kỳ đang diễn ra có nhãn
riêng và có nút **Về kỳ này**.

### Tải bảng công ra Excel

Tab **Tổng quan** → nút tải ở góc trên phải, hoặc thẻ **Chốt kỳ** ở cuối kiểu
xem **Bảng lương** → **Tải bảng công (.xlsx)**. App dựng file rồi mở khay chia sẻ để lưu về máy,
gửi Zalo hoặc đẩy lên Drive.

File trình bày **theo chiều dọc, mỗi nhân viên một khối** (không phải bảng
ngang mỗi ngày một cột) — vừa khổ A4 khi in dọc, chỉ 5 cột cố định: Ngày ·
Thứ · Trạng thái · Công · OT (giờ). Mỗi khối nhân viên gồm:

- Tên nhân viên, Lương/ngày, Đơn giá OT/giờ.
- Một dòng cho mỗi ngày trong kỳ, cột Trạng thái viết chữ đầy đủ ("Đi làm",
  "Nửa công", "Nghỉ", "Chưa chấm", hoặc "Tuỳ chỉnh (6h)" — viết theo **giờ**,
  không phải số công thập phân, để khỏi nhầm với ngày công).
- Dòng TỔNG (tổng công, tổng OT), Số ngày nghỉ, Lương công, Tiền OT, và
  **TỔNG LƯƠNG**.

Cuối file là khối **TỔNG CỘNG TOÀN BỘ CƠ SỞ** cộng dồn tất cả nhân viên.
Số tiền là **số thật** trong Excel (không phải chữ) nên cộng/lọc/sửa công
thức được luôn.

---

## 5. Ba tab

| Tab | Dùng để | Màn con |
|---|---|---|
| **Chấm công** | Dùng hằng ngày | Chọn ngày · Tất cả đi làm · Đi làm/Nửa công/Nghỉ · Tăng ca |
| **Tổng quan** | Xem kết quả kỳ | Thống kê kỳ · Bảng lương từng người · Biểu đồ · Chi tiết nhân viên · Tải bảng công |
| **Cài đặt** | Cấu hình dữ liệu | Tài khoản · Danh sách nhân viên · Lương & tăng ca · Thiết lập chung · Đánh giá ứng dụng · Giới thiệu |

Lần đầu vào app hiện **dialog chào mừng** giới thiệu 3 tính năng chính (chấm
công hằng ngày, tổng hợp công cuối tháng, tính lương tự động). Chỉ hiện một
lần cho mỗi tài khoản trên mỗi máy.

Luồng hằng ngày: mở app → tab Chấm công (mặc định hôm nay) → bấm
**"Tất cả đi làm"** → sửa lại người nghỉ → thêm OT cho ai tăng ca → xong.

Từ tab Tổng quan bấm vào một nhân viên → xem chi tiết kỳ → bấm vào một ngày
để quay về tab Chấm công đúng ngày đó và sửa.

### Hai kiểu xem ở tab Tổng quan

| Kiểu xem | Nội dung |
|---|---|
| **Bảng lương** | Bảng lương từng người, thẻ **Đáng chú ý** (ai lương cao nhất, thấp nhất, nghỉ nhiều nhất, tăng ca nhiều nhất) và thẻ **Chốt kỳ** để tải file |
| **Biểu đồ** | **Quỹ lương theo thời gian** — từng tháng, từng quý, hoặc từng năm |

Biểu đồ có ba nút **Tháng** / **Quý** / **Năm**:

- **Tháng** — biểu đồ miền 12 kỳ trong năm. **Chạm vào một chấm** để xem quỹ
  lương kỳ đó: hiện thông báo kèm khoảng ngày, và một dòng số tiền ngay dưới
  biểu đồ. Tháng chưa tới thì không vẽ chấm.
- **Quý** / **Năm** — cột dọc, số tiền viết sẵn dưới mỗi cột.

Trục luôn bắt đầu từ 0; khoảng đang diễn ra được đánh dấu riêng vì con số còn
tăng tiếp. Quỹ lương của kỳ cũ được tính lại theo **mức lương hiện tại** của
từng người — app không lưu lịch sử thay đổi lương.

---

## 6. Cấu trúc code

```
lib/
├── main.dart                       dựng MaterialApp, mở thẳng màn chào (splash)
├── firebase_options.dart           cấu hình Firebase bản thật (project tick-go)
├── firebase_options_dev.dart       cấu hình Firebase bản dev (project dev-asc)
├── core/
│   ├── firebase_env.dart           chọn project theo --flavor đang build
│   ├── theme.dart                  bảng màu, gradient và ThemeData
│   ├── formatters.dart             định dạng tiền VND, ngày tháng tiếng Việt, giờ OT
│   ├── pay_period.dart             khoảng ngày của một kỳ lương
│   ├── lunar.dart                  đổi ngày dương sang âm lịch Việt Nam
│   └── app_events.dart             liên lạc giữa các tab (nhảy tới một ngày cụ thể)
├── models/                         Employee · AttendanceRecord · MonthlySummary · AppSettings · Company
├── services/
│   ├── auth_service.dart           đăng nhập, đăng ký cơ sở, đổi mật khẩu
│   ├── data_service.dart           toàn bộ truy cập Firestore + hàm tổng hợp kỳ
│   └── export_service.dart         xuất bảng công ra .xlsx và mở khay chia sẻ
├── widgets/
│   ├── common.dart                 widget dùng chung
│   ├── highlights_card.dart        thẻ "Đáng chú ý" (lương cao/thấp nhất...)
│   └── payroll_trend_chart.dart    biểu đồ quỹ lương theo quý / theo năm
└── screens/
    ├── splash_screen.dart          màn chào: logo + 3 chấm chạy, khởi tạo Firebase
    ├── auth_gate.dart              điều hướng theo trạng thái đăng nhập
    ├── intro_screen.dart           màn mở app
    ├── login_screen.dart           đăng nhập
    ├── register_screen.dart        tạo cơ sở mới
    ├── admin/                      tài khoản tổng: danh sách cơ sở + báo cáo (chỉ đọc)
    ├── home_shell.dart             bottom navigation 3 tab
    ├── attendance/                 tab Chấm công + màn tìm nhân viên, lịch chọn ngày,
    │                               bảng trạng thái và OT
    ├── overview/                   tab Tổng quan + chi tiết nhân viên, bảng chọn kỳ
    └── settings/                   tab Cài đặt và 5 màn con
```

## 7. Kiểm thử

```bash
flutter analyze     # không còn cảnh báo
flutter test        # 37 test: công thức lương, quy tắc chấm công, kỳ lương, âm lịch, định dạng
```

---

## 8. Xoá sạch dữ liệu để bàn giao

Sau khi chạy thử, xoá dữ liệu để khách bắt đầu từ trắng:

Dữ liệu nằm trong `companies/{companyId}` nên phải chỉ rõ xoá **cơ sở nào**.
`companyId` = `uid` của chủ cơ sở, xem ở `Console → Authentication → Users`.

```powershell
.\tools\reset_data.ps1 -Company <uid>                   # xoá sạch cơ sở đó
.\tools\reset_data.ps1 -Company <uid> -KeepEmployees    # giữ nhân viên, chỉ xoá công
.\tools\reset_data.ps1 -Company <uid> -KeepSettings     # giữ thiết lập chung
.\tools\reset_data.ps1 -Company <uid> -Project dev-asc  # dọn cơ sở bên bản DEV
```

Mặc định script chạy trên project thật `tick-go`; muốn dọn bản dev thì thêm
`-Project dev-asc` (bản bash: `--project dev-asc`).

Trong Git Bash / macOS thì dùng `./tools/reset_data.sh --company <uid>` với
`--keep-employees`, `--keep-settings`.

- Cần [Firebase CLI](https://firebase.google.com/docs/cli):
  `npm install -g firebase-tools` rồi `firebase login` một lần.
- Script **hỏi lại**: phải gõ đúng chữ `XOA` mới chạy.
- **Không hoàn tác được** — Firestore không có thùng rác. Muốn giữ bản sao thì
  vào tab Tổng quan tải file .xlsx trước.
- Tài khoản đăng nhập nằm ở **Firebase Authentication**, không nằm trong
  Firestore nên script không xoá được. Vào `Console → Authentication → Users`
  xoá đúng user có uid đó — chưa xoá thì tài khoản vẫn đăng nhập được nhưng
  không còn cơ sở nào, app hiện danh sách rỗng.

### 8.1. Di trú dữ liệu từ bản một-tài-khoản

Cơ sở nào đã dùng bản cũ (dữ liệu nằm ở gốc: `employees`, `attendance`,
`settings`, `app_user`) thì chuyển sang cấu trúc mới bằng:

```bash
npm install firebase-admin
node tools/migrate_to_company.js --key ./service-account.json --company <uid>
node tools/migrate_to_company.js --key ./service-account.json --company <uid> --commit
```

- Bỏ `--commit` là chạy thử: chỉ in ra sẽ chuyển bao nhiêu document, không ghi gì.
- Lấy `uid` bằng cách cho chủ cơ sở đăng nhập một lần trên bản mới.
- Script **giữ nguyên doc ID** nên chạy lại nhiều lần cũng không sinh bản ghi
  công trùng ngày.
- Script **không xoá** dữ liệu cũ ở gốc. Kiểm tra app chạy đúng rồi hãy xoá tay
  trong Console — rules mới đã chặn hết 4 collection cũ nên chúng chỉ còn
  chiếm chỗ.
- Service account tải ở `Console → Project settings → Service accounts`.
  **Đừng commit file đó vào git.**

---

## 9. Không có trong bản này (đúng theo đặc tả)

Phân quyền trong một cơ sở (một cơ sở = một tài khoản; ngoài ra chỉ có tài
khoản tổng chỉ đọc, xem §2.3) · bộ phận, chức vụ, duyệt công, khoá bảng lương ·
AI Scan bảng giấy, GPS, khuôn mặt, QR, máy chấm công · tạm ứng, thưởng, phụ cấp,
khấu trừ, nghỉ phép, ca làm và báo cáo nâng cao.
