# WorkDay — Chấm công & Tính lương

App Flutter chấm công hằng ngày và tự tính lương cuối tháng cho cả cơ sở.
Bản đơn giản: **1 tài khoản duy nhất • 3 tab • không phân quyền**.

- **Package**: `com.campany.tickgo`
- **Firebase project**: `tick-go` (Firestore + Authentication)
- **Nền tảng**: Android (iOS đã có sẵn thư mục, cần thêm `GoogleService-Info.plist`)

---

## 1. Chạy app

```bash
flutter pub get
flutter run                      # chạy trên máy Android đang cắm
flutter build apk --release      # xuất file APK để cài cho máy khác
```

APK debug đã build sẵn tại `build/app/outputs/flutter-apk/app-debug.apk`.

---

## 2. Cần làm trên Firebase Console (một lần)

### 2.1. Bật đăng nhập Email/Password

`Authentication` → `Sign-in method` → bật **Email/Password**.

Sau đó mở app, ở màn Đăng nhập nhập tài khoản và mật khẩu bạn muốn dùng
(mật khẩu ≥ 6 ký tự). **Lần đầu tiên app sẽ tự tạo tài khoản đó** — không cần
vào Console tạo user thủ công. Những lần sau chỉ đăng nhập bằng đúng thông tin này.

> Tài khoản không cần là email. Gõ `admin` thì app tự hiểu là `admin@tickgo.app`.

### 2.2. Dán Security Rules

`Firestore Database` → `Rules` → dán nội dung file [`firestore.rules`](firestore.rules) → **Publish**.

Rules chỉ có một điều kiện: đã đăng nhập thì đọc/ghi được (vì app không có phân quyền).

---

## 3. Cấu trúc dữ liệu Firestore

| Collection | Doc ID | Nội dung |
|---|---|---|
| `app_user` | `main` | Tài khoản duy nhất: `account`, `displayName`, `lastLoginAt` |
| `employees` | tự sinh | `name`, `dailySalary`, `otRate`, `phone`, `active`, `createdAt` |
| `attendance` | `{employeeId}_{yyyy-MM-dd}` | `employeeId`, `workDate`, `month`, `status`, `workUnits`, `overtimeMinutes` |
| `settings` | `app` | `orgName`, `currency`, `otPresets`, `workHoursPerDay`, `payPeriodStartDay`, mức lương mặc định |

**Doc ID của `attendance` được ghép từ nhân viên + ngày**, nên một nhân viên chỉ
có đúng một bản ghi cho một ngày. Chấm lại là ghi đè, không bao giờ cộng trùng.

Firestore bật offline persistence: mất mạng vẫn chấm công được, có mạng lại thì
tự đồng bộ.

---

## 4. Nghiệp vụ

### Quy tắc chấm công

| Trạng thái | Số công | Khi nào dùng |
|---|---|---|
| **Đi làm** | 1 | Làm đủ ngày |
| **Nửa công** | 0,5 | Có đến làm nhưng về giữa chừng |
| **Nghỉ** | 0 | Không đi làm |
| **Chưa chấm** | – | Chưa có dữ liệu, không tính công cũng không tính nghỉ |

Tăng ca (0,5h / 1h / 1,5h / 2h / tự nhập) ghi **riêng** với số công và không
làm thay đổi số công của ngày đó.

### Thao tác trên màn Chấm công

| Việc cần làm | Cách làm |
|---|---|
| Chấm cả danh sách đi làm | Nút **Tất cả đi làm** |
| Đổi một người sang Nghỉ | Chạm vào **ô trạng thái** |
| Nửa công, hoặc bỏ chấm khi bấm nhầm | Chạm nút **⋯** cạnh tên nhân viên |
| Nhập tăng ca | Chạm vào **ô giờ** bên phải |
| Xem lại luật chấm công | Nút **?** góc trên phải |

- Bấm nhầm "Tất cả đi làm" → chọn **Hoàn tác** trong thông báo hiện ra.
- Chấm nhầm một người → chạm nút **⋯** cạnh tên họ → **Bỏ chấm công**, đưa về "Chưa chấm".
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

Kỳ luôn **kết thúc trong tháng được chọn**. Tab Tổng quan hiện rõ khoảng ngày
ngay dưới tên kỳ để không nhầm lẫn. Chọn được ngày 1–28.

### Tải bảng công ra Excel

Tab **Tổng quan** → nút tải ở góc trên phải, hoặc thẻ **Chốt kỳ** ở cuối màn →
**Tải bảng công (.xlsx)**. App dựng file rồi mở khay chia sẻ để lưu về máy,
gửi Zalo hoặc đẩy lên Drive.

File có dạng đúng như bảng công giấy: mỗi nhân viên một dòng, mỗi ngày một cột.

| Ký hiệu | Nghĩa |
|---|---|
| `X` | Đi làm (1 công) |
| `1/2` | Nửa công (0,5 công) |
| `N` | Nghỉ (0 công) |
| ô trống | Chưa chấm |
| `X+1,5` | Đi làm + 1,5 giờ tăng ca |

Kèm các cột tổng hợp: Tổng công · Nửa ngày · Nghỉ · Tổng OT · Lương/ngày ·
Đơn giá OT · Lương công · Tiền OT · **TỔNG LƯƠNG**, và một dòng TỔNG CỘNG ở cuối.
Số tiền là **số thật** trong Excel nên cộng/lọc/sửa công thức được luôn.

---

## 5. Ba tab

| Tab | Dùng để | Màn con |
|---|---|---|
| **Chấm công** | Dùng hằng ngày | Chọn ngày · Tất cả đi làm · Đi làm/Nửa công/Nghỉ · Tăng ca |
| **Tổng quan** | Xem kết quả kỳ | Thống kê kỳ · Bảng lương từng người · Biểu đồ · Chi tiết nhân viên · Tải bảng công |
| **Cài đặt** | Cấu hình dữ liệu | Tài khoản · Danh sách nhân viên · Lương & tăng ca · Thiết lập chung · Giới thiệu |

Luồng hằng ngày: mở app → tab Chấm công (mặc định hôm nay) → bấm
**"Tất cả đi làm"** → sửa lại người nghỉ → thêm OT cho ai tăng ca → xong.

Từ tab Tổng quan bấm vào một nhân viên → xem chi tiết kỳ → bấm vào một ngày
để quay về tab Chấm công đúng ngày đó và sửa.

---

## 6. Cấu trúc code

```
lib/
├── main.dart                       khởi tạo Firebase + điều hướng gốc theo trạng thái đăng nhập
├── firebase_options.dart           cấu hình Firebase (sinh từ google-services.json)
├── core/
│   ├── theme.dart                  bảng màu và ThemeData
│   ├── formatters.dart             định dạng tiền VND, ngày tháng tiếng Việt, giờ OT
│   ├── pay_period.dart             khoảng ngày của một kỳ lương
│   └── app_events.dart             liên lạc giữa các tab (nhảy tới một ngày cụ thể)
├── models/                         Employee · AttendanceRecord · MonthlySummary · AppSettings
├── services/
│   ├── auth_service.dart           đăng nhập tài khoản duy nhất, đổi mật khẩu
│   ├── data_service.dart           toàn bộ truy cập Firestore + hàm tổng hợp kỳ
│   └── export_service.dart         xuất bảng công ra .xlsx và mở khay chia sẻ
├── widgets/
│   ├── common.dart                 widget dùng chung
│   └── salary_chart.dart           3 thẻ tổng hợp của tab "Biểu đồ"
└── screens/
    ├── intro_screen.dart           màn mở app
    ├── login_screen.dart           đăng nhập
    ├── home_shell.dart             bottom navigation 3 tab
    ├── attendance/                 tab Chấm công + bảng chọn trạng thái và OT
    ├── overview/                   tab Tổng quan + chi tiết nhân viên theo kỳ
    └── settings/                   tab Cài đặt và 5 màn con
```

## 7. Kiểm thử

```bash
flutter analyze     # không còn cảnh báo
flutter test        # 27 test: công thức lương, quy tắc chấm công, kỳ lương, định dạng
```

---

## 8. Không có trong bản này (đúng theo đặc tả)

Phân quyền và nhiều tài khoản · bộ phận, chức vụ, duyệt công, khoá bảng lương ·
AI Scan bảng giấy, GPS, khuôn mặt, QR, máy chấm công · tạm ứng, thưởng, phụ cấp,
khấu trừ, nghỉ phép, ca làm và báo cáo nâng cao.
