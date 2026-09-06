# CLAUDE.md — WorkDay (tick-go)

App Flutter **chấm công hằng ngày + tự tính lương cuối tháng** cho một cơ sở nhỏ
(10–20 nhân viên). Bản đơn giản: **1 tài khoản duy nhất • 3 tab • không phân quyền**.

Người dùng thật là chủ cơ sở, không rành công nghệ, thao tác bằng một tay trên
điện thoại phổ thông. Mọi quyết định về UI phải ưu tiên: **chữ to, nút to, ít thao tác**.

---

## 0. LUẬT CỨNG — đọc trước khi sửa bất cứ thứ gì

Đây là các ràng buộc nghiệp vụ từ file đặc tả gốc
(`Dac_ta_App_Cham_Cong_Tinh_Luong_Don_Gian (1).docx`). **Không được vi phạm**,
kể cả khi thấy "thêm cái này thì hay hơn".

1. **Đúng 3 tab**: Chấm công · Tổng quan · Cài đặt. Không thêm tab thứ 4.
2. **Không phân quyền**: không role, không permission, không nhiều tài khoản,
   không màn quản lý user. Chỉ một document `app_user/main`.
3. **Một nhân viên chỉ có một bản ghi công cho một ngày.** Chấm lại = ghi đè
   document cũ, tuyệt đối không tạo bản ghi mới (xem §4).
4. **Chỉ có 4 trạng thái**: Đi làm = 1 công · **Nửa công = 0,5 công** ·
   Nghỉ = 0 công · Chưa chấm = chưa có dữ liệu. Không có phép, đi muộn,
   ca làm, hay loại công nào khác.
   > Đặc tả gốc cấm nửa công ("Không có trạng thái nửa công... Nếu sau này
   > cần thì mới bổ sung"). Người dùng đã yêu cầu bổ sung vào 07/09/2026 cho
   > trường hợp "đến làm rồi về giữa chừng". Đây là ngoại lệ duy nhất được mở.
   > Số công của mỗi trạng thái nằm ở `AttendanceStatus.workUnits` — đó là
   > nguồn duy nhất, đừng tính lại `status == present ? 1 : 0` ở bất kỳ đâu.
5. **OT lưu riêng với công.** OT không bao giờ làm thay đổi `workUnits`.
   OT không được âm, có thể bằng 0, và **độc lập với trạng thái** (đặc tả cho
   phép Nghỉ vẫn có OT — đừng "sửa" thành reset OT về 0).
6. **Không chốt/khoá bảng lương.** Không có DRAFT/LOCKED. Lương luôn được
   tính lại từ dữ liệu công của kỳ đang chọn. Thẻ "Chốt kỳ" ở tab Tổng quan
   chỉ là xuất file, không khoá gì cả.
7. **Nhân viên đã nghỉ vẫn giữ toàn bộ lịch sử công.** Chỉ ẩn khỏi danh sách
   chấm công của ngày mới (`active: false`), không xoá dữ liệu. Khi xuất file
   vẫn phải gộp họ nếu có công trong kỳ (`DataService.employeesForExport`).
8. **Không chấm công cho ngày chưa tới.** Nút tiến ngày, `showDatePicker`
   (`lastDate`) và mọi lệnh ghi đều chặn ở hôm nay. Ngày đã qua thì vẫn chấm
   bù được bình thường.
9. **Ngoài phạm vi — không được tự thêm**: AI Scan bảng giấy, GPS, khuôn mặt,
   QR, máy chấm công, tạm ứng, thưởng, phụ cấp, khấu trừ, nghỉ phép, duyệt công,
   audit log, bộ phận, chức vụ, báo cáo nâng cao.

Nếu người dùng yêu cầu một thứ nằm trong danh sách §0.9, cứ làm theo yêu cầu
của họ, nhưng **nói rõ một câu** rằng nó nằm ngoài phạm vi bản đơn giản.

---

## 1. Lệnh hay dùng

```bash
flutter pub get
flutter analyze                  # phải luôn "No issues found!" trước khi báo xong
flutter test                     # test logic nghiệp vụ, phải xanh hết
flutter run                      # cần máy Android cắm sẵn
flutter build apk --release      # -> build/app/outputs/flutter-apk/app-release.apk
flutter pub run flutter_launcher_icons   # sinh lại icon từ assets/images/logo.png
```

**Lưu ý môi trường (Windows):** `dart` trên PATH là bản cũ 3.4.4, không chạy
được package của project (cần ^3.12). **Luôn dùng `flutter pub run ...`**,
đừng dùng `dart run ...`.

Chạy một test lẻ:
```bash
flutter test --plain-name "Lương công = tổng công"
```

---

## 2. Kiến trúc

Không dùng state management package nào. Cố ý giữ đơn giản:

- **Dữ liệu**: `StreamBuilder` đọc thẳng từ Firestore. Không cache tay,
  không repository layer chồng lớp.
- **State màn hình**: `StatefulWidget` + `setState`.
- **Liên lạc giữa các tab**: `AppEvents` (`lib/core/app_events.dart`) —
  hai `ValueNotifier` toàn cục.
- **Singleton**: `DataService.instance`, `AuthService.instance`.

```
lib/
├── main.dart                    khởi tạo Firebase, bật offline persistence,
│                                _AuthGate: chưa login -> IntroScreen, đã login -> HomeShell
├── firebase_options.dart        VIẾT TAY từ google-services.json, chỉ có Android
├── core/
│   ├── theme.dart               AppColors + AppTheme.build()
│   ├── formatters.dart          Fmt (tiền VND, ngày tiếng Việt, giờ OT) + ThousandsFormatter
│   ├── pay_period.dart          PayPeriod - khoảng ngày của một kỳ lương
│   └── app_events.dart          jumpToDate / requestTab
├── models/                      Employee · AttendanceRecord · AttendanceStatus
│                                · MonthlySummary · AppSettings
├── services/
│   ├── auth_service.dart        đăng nhập tài khoản duy nhất
│   ├── data_service.dart        TOÀN BỘ truy cập Firestore + summarize()
│   └── export_service.dart      xuất bảng công ra .xlsx rồi mở khay chia sẻ
├── widgets/
│   ├── common.dart              EmployeeAvatar · StatTile · StatRow · PeriodSelector
│   │                            · SearchBox · EmptyState · TagChip · AppCard
│   │                            · SectionTitle · showToast()
│   └── salary_chart.dart        3 thẻ tổng hợp của tab "Biểu đồ" (xem §5.1)
└── screens/
    ├── intro_screen.dart        + AppLogo (dùng lại ở login và about)
    ├── login_screen.dart
    ├── home_shell.dart          NavigationBar 3 tab, IndexedStack
    ├── attendance/              attendance_tab · ot_picker_sheet · status_picker_sheet
    ├── overview/                overview_tab · employee_month_screen
    └── settings/                settings_tab + 5 màn con
```

**Quy tắc**: mọi câu lệnh Firestore phải nằm trong `data_service.dart`.
Không gọi `FirebaseFirestore.instance` trực tiếp từ màn hình.

---

## 3. Firebase

- Project: `tick-go` · package Android: `com.campany.tickgo`
- `android/app/google-services.json` đã có sẵn.
- `lib/firebase_options.dart` **viết tay**, chỉ khai báo Android. Nếu thêm iOS/Web
  thì chạy `flutterfire configure`, đừng sửa tay tiếp.
- Auth: Email/Password. Tài khoản không cần là email — `AuthService.normalizeAccount`
  tự ghép `@tickgo.app` nếu người dùng gõ `admin`.
- **Lần đăng nhập đầu tiên tự tạo tài khoản** nếu `app_user/main` chưa tồn tại
  (kiểm tra bằng `Source.server`; đọc lỗi thì coi như đã có, để không lỡ tạo
  tài khoản thứ hai).
- Rules ở `firestore.rules` — chỉ một điều kiện `request.auth != null`.
- Offline persistence **bật sẵn** trong `main.dart`. App phải chấm công được
  khi mất mạng.

---

## 4. Mô hình dữ liệu

| Collection | Doc ID | Trường |
|---|---|---|
| `app_user` | `main` | `account`, `displayName`, `lastLoginAt` |
| `employees` | tự sinh | `name`, `nameLower`, `dailySalary`, `otRate`, `phone`, `active`, `createdAt` |
| `attendance` | `{employeeId}_{yyyy-MM-dd}` | `employeeId`, `workDate`, `month`, `status`, `workUnits`, `overtimeMinutes`, `updatedAt` |
| `settings` | `app` | `orgName`, `currency`, `otPresets`, `workHoursPerDay`, `defaultDailySalary`, `defaultOtRate`, `payPeriodStartDay` |

**Doc ID ghép của `attendance` chính là cơ chế chống trùng của luật §0.3.**
Đừng đổi sang ID tự sinh — làm vậy là phá quy tắc "một bản ghi mỗi ngày".

- `month` (`yyyy-MM`) vẫn được ghi kèm mỗi bản ghi, nhưng phần tổng hợp đã
  chuyển sang lọc theo khoảng `workDate` (xem §4.1).
- `overtimeMinutes` là **số phút** (0/30/60/90/120…), không phải giờ.
  Hiển thị qua `Fmt.otHours()`.
- Mọi query hiện tại chỉ dùng equality **hoặc** range trên đúng một trường,
  phần lọc còn lại làm ở client → **không cần composite index nào**.
  Giữ nguyên như vậy nếu được: thêm `where('employeeId')` cạnh range
  `workDate` là Firestore đòi tạo index ngay.

### 4.1. Kỳ lương (`PayPeriod`)

Nhiều cơ sở không chốt lương theo tháng dương lịch mà theo kiểu "26 tháng
trước đến 25 tháng này". `settings.payPeriodStartDay` (1..28) quyết định điều
đó, `lib/core/pay_period.dart` dựng khoảng ngày.

- `startDay = 1` → kỳ trùng đúng tháng dương lịch.
- `startDay = 26` → **kỳ của tháng N** là `26/(N-1)` đến `25/N`.
  Quy ước: kỳ luôn *kết thúc* trong tháng được chọn.
- Giới hạn 1..28 để không vướng tháng 2 và tháng 30 ngày. Đừng nới ra 29–31.
- Kỳ có thể vắt qua hai tháng nên **không được** tổng hợp bằng `month ==`.
  Dùng `DataService.watchPeriod()` / `getPeriod()` lọc theo khoảng `workDate`.
  `workDate` là chuỗi `yyyy-MM-dd` nên so sánh chuỗi chính là so sánh ngày.
- UI luôn hiện kèm khoảng ngày (`PayPeriod.rangeLabel`) khi kỳ không trùng
  tháng dương lịch, để người dùng không hiểu nhầm "Kỳ 09" là tháng 9.

### Công thức lương — đặt ở `MonthlySummary`, đừng viết lại chỗ khác

```
basePay  = totalWorkUnits × dailySalary
otPay    = (overtimeMinutes / 60) × otRate
totalPay = basePay + otPay
```

`otRate = 0` là hợp lệ và có nghĩa "cơ sở không trả OT riêng".

---

## 5. Quy ước code

- **Comment và mọi chuỗi hiển thị đều bằng tiếng Việt có dấu.** Tên biến/hàm
  tiếng Anh. Giữ nguyên phong cách này khi thêm code.
- **Không dùng `intl`.** Đã cố tình gỡ khỏi dependencies để khỏi phải
  `initializeDateFormatting`. Mọi định dạng đi qua `Fmt` trong
  `core/formatters.dart` — thêm hàm mới ở đó, đừng format tay tại chỗ.
- Tiền hiển thị: `Fmt.currency()` → `5.200.000đ`. Ô nhập tiền: dùng
  `ThousandsFormatter()` + đọc lại bằng `parseMoney()`.
- Màu: chỉ lấy từ `AppColors`. Không hardcode `Color(0x...)` trong màn hình.
  `present` xanh lá, `absent` đỏ, `overtime` cam, `info` xanh dương.
- Widget dùng lại phải nằm ở `widgets/common.dart`.
- Thông báo cho người dùng: `showToast(context, '...')`, có `error: true` khi lỗi.
- Sau `await`, luôn kiểm tra `if (!mounted) return;` trước khi đụng `context`.
- Text scale bị khoá trong khoảng 0.9–1.25 ở `main.dart` để bảng chấm công
  không vỡ trên máy đặt cỡ chữ lớn.

### 5.1. Tab "Biểu đồ" — TUYỆT ĐỐI không quay lại một-thanh-mỗi-người

Đã thử **hai lần** và thất bại cả hai:

1. Mỗi nhân viên một thanh xanh đặc dài theo tổng lương → *"nhìn đau mắt"*.
2. Vẫn một thanh mỗi người nhưng mảnh hơn, hai màu, có vạch trung bình, giới
   hạn 8 người → *"vẫn nhìn khó hiểu quá"*.

Nguyên nhân gốc không nằm ở cách tô màu: **lương trong một cơ sở gần như bằng
nhau** (1,6tr–2,1tr). Thanh nào cũng dài 90–100%, nên biểu đồ không mang thông
tin. Thêm nữa, phần so sánh từng người **đã có sẵn** ở tab "Danh sách nhân
viên" dưới dạng bảng số — vẽ lại bằng thanh chỉ là nói lại điều đã nói, kém
chính xác hơn.

Bản hiện tại bỏ hẳn kiểu đó, gồm 3 thẻ:

| Thẻ | Nội dung | Vì sao hợp lý |
|---|---|---|
| Quỹ lương chia làm gì | **Một** thanh 2 màu: lương công / tăng ca | Tỉ lệ chênh rõ (95% / 5%) nên thanh có nghĩa |
| Ngày công trong kỳ | **Một** thanh 3 màu: đủ ngày / nửa công / nghỉ | Cũng là tỉ lệ thật |
| Đáng chú ý | Lương cao nhất · thấp nhất · nghỉ nhiều nhất · tăng ca nhiều nhất, kèm **tên và số** | Trả lời thẳng, không bắt đo độ dài thanh |

Nguyên tắc rút ra, áp dụng cho mọi biểu đồ thêm sau này:
**chỉ vẽ thanh khi các phần chênh nhau rõ rệt; còn lại viết thẳng tên và số.**

Hai bẫy kỹ thuật đã dính, đừng lặp lại:
- `Expanded(flex:)` lấy **thẳng số tiền** làm flex thì tràn `int` 32-bit
  (2 triệu × 1000 > 2^31) và thanh vẽ sai tỉ lệ. `_StackedBar` quy mọi thứ về
  phần nghìn (`value / total * 1000`) trước khi làm flex.
- **Đừng** đổi trục sang kiểu "phóng to phần chênh lệch" (thanh bắt đầu từ mức
  thấp nhất thay vì từ 0). Nhìn tách bạch hơn nhưng bóp méo tỉ lệ, người dùng
  sẽ tưởng người này lương gấp mấy lần người kia.

### 5.2. Thao tác ở tab Chấm công — đừng làm chậm nó đi

Mục tiêu là chấm xong 10–20 người trong 15–30 giây. Vì vậy các thao tác được
xếp theo mức độ hay dùng, **đừng gộp hết vào một bảng chọn**:

| Thao tác | Cách làm | Vì sao |
|---|---|---|
| Cả danh sách đi làm | Nút "Tất cả đi làm" | Trường hợp phổ biến nhất |
| Đổi 1 người sang Nghỉ | Chạm chip trạng thái (1 chạm) | Sửa lẻ sau khi chấm cả loạt |
| Nửa công / bỏ chấm | Chạm nút ⋯ cạnh tên → bảng chọn | Ít gặp, chấp nhận 2 chạm |
| Tăng ca | Chạm chip giờ bên phải | Độc lập với trạng thái |

- Chip trạng thái chỉ xoay vòng **Đi làm ↔ Nghỉ**. Nửa công cố ý *không* nằm
  trong vòng xoay này — nếu thêm vào, người dùng phải chạm 2–3 lần mới về được
  trạng thái mong muốn, hỏng luôn mục tiêu tốc độ.
- "Tất cả đi làm" có **Hoàn tác** trong SnackBar 6 giây
  (`DataService.restoreDay`), vì một cú bấm nhầm sửa cùng lúc cả chục bản ghi.
- Bỏ chấm = **xoá hẳn document** (`clearRecord`), không phải ghi trạng thái
  `NONE`. "Chưa chấm" nghĩa là không có bản ghi.
- Nút "?" trên thanh tiêu đề mở bảng giải thích 4 trạng thái + các thao tác
  (`showAttendanceHelp`). Người dùng không rành công nghệ nên cần chỗ tra.
- **Nút ⋯ cạnh tên phải luôn hiện.** Bản đầu để cả vùng tên làm điểm chạm
  nhưng không vẽ gì, người dùng phản hồi "không thấy điểm chạm vào gì cả".
  Vùng chạm vô hình = vùng chạm không tồn tại. Dòng gợi ý `_RowHint` cũng vẽ
  đúng nút đó bằng `WidgetSpan` thay vì tả bằng chữ.

### 5.3. Xuất file

`ExportService.exportAndShare()` dựng .xlsx bằng package `excel` rồi mở khay
chia sẻ của hệ điều hành (`share_plus`) để người dùng lưu / gửi Zalo / lên Drive.
File ghi vào thư mục tạm (`path_provider`), không ghi thẳng vào Downloads —
Android scoped storage.

Bố cục file bám đúng bảng công giấy: mỗi nhân viên một dòng, mỗi ngày một cột,
`X` = đi làm, `N` = nghỉ, ô trống = chưa chấm, số phía sau = giờ OT
(ví dụ `X1,5`). Cuối bảng là các cột tổng hợp và dòng TỔNG CỘNG.

Tiền ghi bằng `DoubleCellValue` + `numberFormat: '#,##0'` để Excel hiểu là số,
không phải chuỗi — đừng đổi sang `TextCellValue`.

---

## 6. Bẫy đã gặp

- **`HomeShell.of(context)` không hoạt động từ màn được `push`.** Route đẩy lên
  nằm cùng cấp với `HomeShell` trong Overlay, không phải con của nó. Từ màn con
  muốn chuyển tab thì dùng `AppEvents.editAttendanceOn(day)` /
  `AppEvents.requestTab`. Chỉ widget nằm *trong* `IndexedStack` mới gọi
  `HomeShell.of(context)` được (ví dụ nút "Mở Cài đặt" ở `attendance_tab`).
- **Heredoc bash với file Dart dài hay lỗi quoting.** Dùng thẳng công cụ
  Write/Edit cho file lớn.
- `markAllPresent` chia lô 450 thao tác vì Firestore giới hạn 500 ops/batch.
- Xoá nhân viên: `employee_list_screen` gọi `countAttendanceOf()` trước, có
  ngày công rồi thì chặn xoá và bảo chuyển sang "Đã nghỉ" (luật §0.7).

---

## 7. Định nghĩa "xong"

Một thay đổi chỉ được coi là xong khi:

1. `flutter analyze` → **No issues found!**
2. `flutter test` → xanh hết. Đụng vào công thức lương hoặc quy tắc chấm công
   thì **phải thêm test** vào `test/widget_test.dart`.
3. Không vi phạm luật nào ở §0.
4. Nếu đổi mô hình dữ liệu hoặc thêm màn hình → cập nhật `README.md` và file này.
