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
2. **Nhiều cơ sở, mỗi tài khoản chủ là một cơ sở.** Dữ liệu nằm trong
   `companies/{companyId}`, và `companyId` **chính là uid Firebase của chủ**
   (xem §4 và `firestore.rules`). Ngoài đó chỉ có một vai thứ hai duy nhất:
   **tài khoản tổng, CHỈ ĐỌC**, khai bằng danh sách uid trong `isSuperAdmin()`
   của rules. Không thêm vai nào khác, không có màn quản lý user, một cơ sở
   vẫn chỉ có một tài khoản đăng nhập.
   > Đặc tả gốc là "một tài khoản duy nhất, không phân quyền". Người dùng yêu
   > cầu chuyển sang nhiều cơ sở ngày 08/09/2026 (mỗi khách một cơ sở, kèm một
   > tài khoản tổng chỉ đọc để họ xem báo cáo của tất cả khách). Đây là ngoại
   > lệ thứ ba được mở, sau nửa công (§0.4) và âm lịch (§5.2.2).
   > **Cách ly là do cấu trúc, không do câu query**: mọi truy cập đi qua
   > `DataService._root` nên không có chỗ nào để quên lọc `companyId`.
3. **Một nhân viên chỉ có một bản ghi công cho một ngày.** Chấm lại = ghi đè
   document cũ, tuyệt đối không tạo bản ghi mới (xem §4).
4. **Chỉ có 5 trạng thái**: Đi làm = 1 công · **Nửa công = 0,5 công** ·
   **Tuỳ chỉnh = công nhập tay (0,05–1)** · Nghỉ = 0 công · Chưa chấm = chưa
   có dữ liệu. Không có phép, đi muộn, ca làm, hay loại công nào khác.
   > Đặc tả gốc cấm nửa công ("Không có trạng thái nửa công... Nếu sau này
   > cần thì mới bổ sung"). Người dùng đã yêu cầu bổ sung vào 07/09/2026 cho
   > trường hợp "đến làm rồi về giữa chừng" - đây là ngoại lệ đầu tiên trong số
   > các ngoại lệ đã mở (đa cơ sở ở §0.2, âm lịch ở §5.2.2).
   > Số công của ba trạng thái cố định (Đi làm/Nửa công/Nghỉ) nằm ở
   > `AttendanceStatus.workUnits` — đó là nguồn duy nhất, đừng tính lại
   > `status == present ? 1 : 0` ở bất kỳ đâu.
   > **Tuỳ chỉnh là ngoại lệ tiếp theo**, người dùng yêu cầu ngày 17/09/2026
   > cho trường hợp làm không tròn nửa ngày (ví dụ 5-6 tiếng trên 8 tiếng
   > chuẩn) - nhập theo **số giờ đã làm**, app tự quy đổi ra công theo
   > `AppSettings.workHoursPerDay`. Trạng thái này **không** có số công cố
   > định trong enum: `AttendanceStatus.custom.workUnits` luôn trả về `0` chỉ
   > để làm giá trị mặc định an toàn, số công thật nằm ở
   > `AttendanceRecord.workUnits` do người dùng nhập - đọc trực tiếp ở đó,
   > đừng suy ra từ enum. `AttendanceRecord.forDay`/`copyWith` bắt buộc nhận
   > tham số `workUnits` khi trạng thái là Tuỳ chỉnh, ba trạng thái còn lại
   > vẫn tự lấy số công cố định của mình như cũ.
   > **Hiện số công của Tuỳ chỉnh ra màn hình luôn viết theo giờ** (`Fmt.
   > customWorkHours`, ví dụ "6h", "5h30"), không viết số công thập phân
   > ("0,75c") - người dùng phản hồi ngày 17/09/2026 rằng số công thập phân dễ
   > nhầm thành số ngày công. Việc quy đổi ra công (để tính lương) vẫn diễn
   > ra ở tầng dữ liệu như trên, chỉ riêng lớp hiển thị mới đổi sang giờ.
5. **OT lưu riêng với công.** OT không bao giờ làm thay đổi `workUnits`.
   OT không được âm, có thể bằng 0, và **độc lập với trạng thái** (đặc tả cho
   phép Nghỉ vẫn có OT — đừng "sửa" thành reset OT về 0).
6. **Không chốt/khoá bảng lương.** Không có DRAFT/LOCKED. Lương luôn được
   tính lại từ dữ liệu công của kỳ đang chọn. Thẻ "Chốt kỳ" (cuối kiểu xem
   "Bảng lương" ở tab Tổng quan) chỉ là xuất file, không khoá gì cả.
7. **Nhân viên đã nghỉ vẫn giữ toàn bộ lịch sử công.** Chỉ ẩn khỏi danh sách
   chấm công của ngày mới (`active: false`), không xoá dữ liệu. Khi xuất file
   vẫn phải gộp họ nếu có công trong kỳ (`DataService.employeesForExport`).
8. **Không chấm công cho ngày chưa tới.** Nút tiến ngày, lịch chọn ngày
   (`showAttendanceDatePicker`, tham số `lastDate`) và mọi lệnh ghi đều chặn
   ở hôm nay. Ngày đã qua thì vẫn chấm bù được bình thường.
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
flutter run --flavor dev         # chạy hằng ngày, đâm vào Firebase dev-asc
flutter run --flavor product     # chạy trên DỮ LIỆU THẬT — cẩn thận
flutter build apk --release --flavor product   # -> build/app/outputs/flutter-apk/app-product-release.apk
flutter build apk --debug --flavor dev --target-platform android-arm64
flutter pub run flutter_launcher_icons   # sinh lại icon từ assets/images/logo.png
```

**`--flavor` là bắt buộc** cho mọi lệnh chạy/build Android (xem §3.1). Quên nó
thì Gradle báo lỗi thiếu flavor; `flutter analyze` và `flutter test` thì không
cần vì không đụng tới Android.

**Lưu ý môi trường (Windows):** `dart` trên PATH là bản cũ 3.4.4, không chạy
được package của project (cần ^3.12). **Luôn dùng `flutter pub run ...`**,
đừng dùng `dart run ...`. Cũng **đừng chạy `dart format`**: formatter 3.4.4
theo style cũ, nó viết lại cả file và làm diff phình lên hàng trăm dòng không
liên quan. Sửa thụt lề bằng tay.

**Xoá dữ liệu để bàn giao** (không hoàn tác được, script hỏi lại trước khi
chạy — cần `firebase-tools` và `firebase login`):

Dữ liệu nằm trong `companies/{companyId}` nên script **bắt buộc** phải biết
xoá cơ sở nào (`companyId` = uid của chủ, xem Console > Authentication > Users):

```powershell
.\tools\reset_data.ps1 -Company <uid>                  # xoá sạch cơ sở đó
.\tools\reset_data.ps1 -Company <uid> -KeepEmployees   # chỉ xoá dữ liệu công
.\tools\reset_data.ps1 -Company <uid> -Project dev-asc # dọn cơ sở bên bản DEV
```

Bản bash: `tools/reset_data.sh --company <uid>` (`--keep-employees`,
`--keep-settings`, `--project`).
Tài khoản đăng nhập nằm ở Firebase Authentication nên script không xoá được,
phải vào Console xoá tay — script in sẵn đường dẫn.

**Di trú dữ liệu từ bản một-tài-khoản** (4 collection ở gốc → `companies/{uid}`),
chỉ cần chạy một lần cho cơ sở cũ:

```bash
npm install firebase-admin
node tools/migrate_to_company.js --key ./service-account.json --company <uid>
node tools/migrate_to_company.js --key ./service-account.json --company <uid> --commit
```

Không có `--commit` là chạy thử, không ghi gì. Script **giữ nguyên doc ID** nên
chạy lại nhiều lần cũng không sinh bản ghi công trùng ngày, và **không xoá** dữ
liệu cũ ở gốc — kiểm tra app chạy đúng rồi xoá tay trong Console.

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
├── main.dart                    CHỈ dựng MaterialApp + nền gradient, home =
│                                SplashScreen. Không chờ Firebase ở đây (xem §5.4)
├── firebase_options.dart        VIẾT TAY từ google-services.json, chỉ có Android
├── firebase_options_dev.dart    y hệt nhưng cho project dev-asc (xem §3.1)
├── core/
│   ├── firebase_env.dart        chọn project theo --flavor (firebaseOptions)
│   ├── theme.dart               AppColors + AppGradients + AppTheme.build()
│   ├── formatters.dart          Fmt (tiền VND, ngày tiếng Việt, giờ OT) + ThousandsFormatter
│   ├── pay_period.dart          PayPeriod - khoảng ngày của một kỳ lương
│   ├── lunar.dart               LunarDate - đổi ngày dương sang âm lịch VN
│   └── app_events.dart          jumpToDate / requestTab
├── models/                      Employee · AttendanceRecord · AttendanceStatus
│                                · MonthlySummary · AppSettings · Company
│                                · AppReview
├── services/
│   ├── auth_service.dart        đăng nhập · đăng ký cơ sở · đổi mật khẩu
│   ├── data_service.dart        TOÀN BỘ truy cập Firestore + summarize()
│   │                            (mọi đường dẫn qua companies/{companyId})
│   └── export_service.dart      xuất bảng công ra .xlsx rồi mở khay chia sẻ
├── widgets/
│   ├── common.dart              EmployeeAvatar · StatTile · StatRow · StatGrid
│   │                            · GradientButton
│   │                            · PeriodSelector · SearchBox · EmptyState
│   │                            · TagChip · AppCard · SectionTitle · showToast()
│   ├── highlights_card.dart     thẻ "Đáng chú ý" ở kiểu xem "Bảng lương"
│   └── payroll_trend_chart.dart quỹ lương theo tháng / quý / năm (xem §5.1)
└── screens/
    ├── splash_screen.dart       màn chào + khởi tạo Firebase (xem §5.4)
    ├── auth_gate.dart           chưa login -> IntroScreen, đã login -> HomeShell;
    │                            gán DataService.companyId = uid (xem §4)
    ├── intro_screen.dart        + AppLogo (dùng lại ở login và about)
    ├── login_screen.dart        + nút Tạo cơ sở mới
    ├── register_screen.dart     tạo cơ sở mới (tên cơ sở + email + mật khẩu)
    ├── welcome_dialog.dart      dialog chào mừng, chỉ hiện lần đầu (xem §5.5)
    ├── admin/                   company_list_screen · company_report_screen
    │                            (tài khoản tổng, CHỈ ĐỌC - xem §0.2)
    ├── home_shell.dart          NavigationBar 3 tab, IndexedStack
    ├── attendance/              attendance_tab · attendance_search_screen
    │                            · attendance_actions (thao tác ghi dùng chung)
    │                            · attendance_row (một dòng chấm công)
    │                            · date_picker_dialog · ot_picker_sheet
    │                            · status_picker_sheet
    ├── overview/                overview_tab · employee_month_screen
    │                            · period_picker_sheet
    └── settings/                settings_tab + 5 màn con + review_screen
                                 (dialog "đánh giá app", không phải màn push)
```

**Quy tắc**: mọi câu lệnh Firestore phải nằm trong `data_service.dart`.
Không gọi `FirebaseFirestore.instance` trực tiếp từ màn hình.

---

## 3. Firebase

- Project thật: `tick-go` · package Android: `com.campany.tickgo`
- `android/app/google-services.json` đã có sẵn.
- `lib/firebase_options.dart` **viết tay**, chỉ khai báo Android. Nếu thêm iOS/Web
  thì chạy `flutterfire configure`, đừng sửa tay tiếp.
- Auth: Email/Password. **Đăng ký bắt buộc email thật** (`RegisterScreen` chặn
  chuỗi không đúng dạng email) để còn liên hệ được với khách và để người quản
  trị đặt lại mật khẩu cho họ từ Console. Tài khoản cũ không có `@` vẫn đăng
  nhập được: `AuthService.normalizeAccount` ghép `@tickgo.app` như trước.
- **Không có "Quên mật khẩu" trong app** — đã làm rồi bỏ theo yêu cầu người
  dùng (08/09/2026). Đừng thêm lại. Khách quên mật khẩu thì xử lý ở
  `Console → Authentication → Users` (Reset password). Người còn đăng nhập
  được thì tự đổi ở màn "Thông tin tài khoản" (`AuthService.changePassword`,
  vẫn giữ).
- Rules ở `firestore.rules`: cách ly theo `request.auth.uid == companyId`, và
  một danh sách uid cho tài khoản tổng (chỉ đọc). **Không có `get()` trong
  rules** → không tốn thêm read cho mỗi lượt đọc/ghi; đừng đổi sang kiểu tra
  `users/{uid}.companyId` bằng `get()`.
  Sửa rules xong phải **Publish trong Console**, file trong repo chỉ là bản gốc.
- Offline persistence **bật sẵn** (đặt trong `SplashScreen._bootstrap`). App
  phải chấm công được khi mất mạng.

### 3.1. Môi trường dev / product (2 Firebase project)

Tách môi trường bằng **product flavor** của Gradle, KHÔNG bằng `--dart-define`
tự đặt — quên truyền một lần là bản test ghi thẳng vào dữ liệu thật.

| flavor | Firebase project | applicationId | Nhãn app | google-services.json |
|---|---|---|---|---|
| `dev` | `dev-asc` | `dev.asctechsoft` | WorkDay Dev | `android/app/src/dev/google-services.json` |
| `product` | `tick-go` | `com.campany.tickgo` | WorkDay | `android/app/google-services.json` — **DỮ LIỆU THẬT** |

- Plugin `google-services` đọc `src/<flavor>/google-services.json` trước, không
  thấy mới lấy file ở gốc `android/app/` → bản dev tự lấy `dev-asc`, bản product
  lấy file gốc. **Đừng xoá/đổi tên file gốc.** `android/app/google-services_dev.json`
  là bản tải từ console giữ nguyên để đối chiếu; bản Gradle thực sự đọc là copy
  trong `src/dev/` — tải lại từ console thì cập nhật **cả hai**.
- `applicationId` phải khớp ĐÚNG `package_name` khai trong json tương ứng, lệch
  một ký tự là Gradle báo `No matching client found for package name`.
- Nhãn app lấy từ `manifestPlaceholders["appLabel"]`, `AndroidManifest.xml` để
  `android:label="${appLabel}"` — đừng ghi tên cứng lại vào manifest.
- **Tầng Dart chọn project qua `appFlavor`** (`lib/core/firebase_env.dart` →
  `firebaseOptions`), do chính Flutter tool ghi vào bản build từ cờ `--flavor`
  nên không thể lệch với google-services.json mà Gradle đã nhúng.
  `lib/firebase_options.dart` = prod, `lib/firebase_options_dev.dart` = dev
  (chỉ Android; nền tảng khác **ném lỗi** thay vì rơi về prod).
- **MỌI** `Firebase.initializeApp` phải dùng `firebaseOptions`; hiện chỉ có một
  chỗ là `SplashScreen._bootstrap`. Thêm FirebaseApp phụ nào cũng phải truyền
  options này.
- Không truyền `--flavor` thì `appFlavor == null` → rơi về **prod**. Vì vậy
  `--flavor` là bắt buộc; VS Code đã có sẵn 4 cấu hình trong `.vscode/launch.json`.
- **`dev.asctechsoft` là applicationId dùng chung với app BizGo Dev** (cùng app
  Android trong project `dev-asc`), nên hai bản dev đè nhau khi cài trên cùng
  máy. Dữ liệu vẫn tách vì collection không trùng nhau
  (`employees`/`attendance`/`settings`/`app_user` so với `orders`/`products`/…).
  Muốn cài song song thì đăng ký app Android mới trong console `dev-asc`
  (ví dụ `dev.asctechsoft.tickgo`) rồi thay cả hai file json + `applicationId`.
- Dọn dữ liệu dev: `.\tools\reset_data.ps1 -Project dev-asc` (script chỉ xoá 4
  collection của WorkDay nên không đụng dữ liệu app khác trong `dev-asc`).
- **iOS/Web chưa có flavor.** Làm iOS thì phải thêm scheme + `GoogleService-Info.plist`
  riêng cho từng flavor.

---

## 4. Mô hình dữ liệu

Dữ liệu của mỗi cơ sở nằm gọn trong một nhánh. `{cid}` = `companyId` =
**uid Firebase của chủ cơ sở** (§0.2).

| Collection | Doc ID | Trường |
|---|---|---|
| `companies` | `{cid}` | `orgName`, `ownerAccount`, `active`, `createdAt` |
| `companies/{cid}/employees` | tự sinh | `name`, `nameLower`, `dailySalary`, `otRate`, `phone`, `active`, `createdAt` |
| `companies/{cid}/attendance` | `{employeeId}_{yyyy-MM-dd}` | `employeeId`, `workDate`, `month`, `status`, `workUnits`, `overtimeMinutes`, `updatedAt` |
| `companies/{cid}/settings` | `app` | `orgName`, `currency`, `otPresets`, `workHoursPerDay`, `defaultDailySalary`, `defaultOtRate`, `payPeriodStartDay` |
| `companies/{cid}/reviews` | tự sinh | `stars` (1..5), `comment`, `appVersion`, `createdAt` |
| `users` | `{uid}` | `account`, `displayName`, `companyId`, `role`, `lastLoginAt` |

**Doc ID ghép của `attendance` chính là cơ chế chống trùng của luật §0.3.**
Đừng đổi sang ID tự sinh — làm vậy là phá quy tắc "một bản ghi mỗi ngày".

- **Mọi đường dẫn dựng qua `DataService._root`** (`companies/{companyId}`).
  `companyId` được gán **đúng một chỗ**: `AuthGate` map theo `authState`
  (`companyId = uid`, đăng xuất thì về `null`). Đừng gán ở chỗ khác, và đừng
  quay lại `_db.collection('employees')` ở gốc — rules đã chặn hết gốc.
- `DataService.forCompany(id)` là bản trỏ vào **cơ sở khác**, chỉ dùng cho màn
  báo cáo của tài khoản tổng. Đừng đổi `DataService.instance.companyId` để
  xem cơ sở khách: làm vậy là ba tab của chính người dùng đổi dữ liệu dưới
  chân họ.
- `users/{uid}.role` **chỉ để UI biết có hiện menu "Quản lý cơ sở" hay không**.
  Chặn thật nằm ở `isSuperAdmin()` trong rules (danh sách uid). Rules cũng
  không cho client tự ghi `role`, nhưng dù có sửa được cũng chẳng đọc thêm
  được gì.
- Đăng nhập **không còn tự tạo tài khoản** như bản một-tài-khoản: giờ gõ sai
  email một lần là sinh ra một cơ sở rỗng. Tạo cơ sở đi qua đúng
  `AuthService.registerCompany` → `DataService.createCompany` (ghi 3 document
  trong **một batch**, hoặc có đủ hoặc không có gì).

- `month` (`yyyy-MM`) vẫn được ghi kèm mỗi bản ghi, nhưng phần tổng hợp đã
  chuyển sang lọc theo khoảng `workDate` (xem §4.1).
- `overtimeMinutes` là **số phút** (0/30/60/90/120…), không phải giờ.
  Hiển thị trong app qua `Fmt.otHours()` → `25p` · `1h` · `1h30`.
  **Không quay lại giờ thập phân (`0,4h`)**: người dùng đọc "0.4h" thành 40
  phút trong khi thực tế là 25 phút. Vì lý do đó mọi ô nhập OT (bảng chọn ở
  tab Chấm công và "Thêm mốc tăng ca" ở Cài đặt) đều **nhập theo phút**, làm
  tròn về mốc 5 phút, tối đa 24 giờ.
  Riêng file .xlsx vẫn ghi giờ thập phân kiểu bảng công giấy — dùng
  `Fmt.otHoursDecimal()` (`1,5`), đừng dùng `otHours()` ở đó.
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
- **Thanh chọn kỳ luôn hiện khoảng ngày** — `subLabel: 'Tính công
  ${period.rangeLabel}'` ở cả tab Tổng quan và màn chi tiết nhân viên. Bản đầu
  chỉ hiện khi kỳ lệch tháng dương lịch, người dùng phản hồi *"công của tháng
  đó từ ngày nào đến ngày nào chưa hiện được"*: kể cả kỳ trùng tháng dương
  lịch thì đó vẫn là câu hỏi đầu tiên họ đặt ra. Đừng ẩn lại theo
  `isCalendarMonth`.
- **Chạm vào tên kỳ mở bảng chọn kỳ** (`showPeriodPicker`,
  `overview/period_picker_sheet.dart`): liệt kê 24 kỳ gần nhất kèm khoảng ngày
  đầy đủ, kỳ đang diễn ra có nhãn "Đang diễn ra", cuối bảng có nút "Về kỳ
  này". Chỉ có hai nút ‹ › là không đủ — muốn xem kỳ nửa năm trước phải bấm
  sáu lần. Không liệt kê kỳ chưa bắt đầu vì xem chỉ ra bảng rỗng.

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
  **Không rút gọn số tiền** kiểu "22,4 tr" — đã có `Fmt.moneyCompact()` và bị
  bỏ vì người dùng chê khó đọc. Ô chật thì đổi bố cục, đừng cắt con số.
- Ô thống kê **có icon tròn** (`StatTile.icon` / `StatItem.icon`): nền vòng
  tròn lấy chính màu của ô ở `alpha 0.12` nên không phải thêm hằng số màu mới.
  Bộ icon đang dùng, giữ đồng bộ giữa các màn: người `groups_rounded` · công
  `check_rounded` · nghỉ `nightlight_round` · tăng ca
  `access_time_filled_rounded` · tiền `payments_rounded`.
- Ô thống kê: `StatRow` cho 3–4 giá trị ngắn (số ngày, số người) nằm một hàng;
  **`StatGrid` (2 cột) cho giá trị dài như số tiền** — bốn ô tiền trên một
  hàng thì chữ dính sát viền. `StatItem.unit` viết đơn vị nhỏ sau con số
  ("111 **công**", "22.400.000 **đ**") để đọc là hiểu ngay đơn vị gì.
- Màu: chỉ lấy từ `AppColors`, dải màu chuyển lấy từ `AppGradients`. Không
  hardcode `Color(0x...)` hay tự dựng `LinearGradient` trong màn hình.
  `present` xanh lá, `absent` đỏ, `overtime` cam, `info` xanh dương,
  `custom` tím (trạng thái Tuỳ chỉnh — tách riêng khỏi `info` đã dùng cho
  Nửa công để hai trạng thái không lẫn màu nhau).
- **Nền app là gradient** (`AppGradients.page`: `#E6FBF4` → `#F8FCFB` 35% →
  `#F5F9FB`), dựng **đúng một lần** ở `MaterialApp.builder` trong `main.dart`.
  Vì vậy `scaffoldBackgroundColor` và `appBarTheme.backgroundColor` đều để
  `Colors.transparent` — đặt màu đục cho `Scaffold` hoặc `AppBar` của một màn
  là che mất nền chung, đừng làm. Thẻ / ô nhỏ vẫn dùng `surface` (trắng) và
  `background` (#F4F6F8) như cũ để nổi trên nền gradient.
  **Mở màn mới bằng `pushScreen(context, ManHinh())`** (`widgets/common.dart`),
  **không dùng `MaterialPageRoute` nữa** — `appPageRoute` phía sau nó lo đúng
  hai việc mà từng màn hay quên:
  1. **Nền.** Nền chung nằm *sau* toàn bộ Navigator, mà `Scaffold` thì trong
     suốt, nên màn mới không có gì che và nhìn xuyên thẳng xuống màn cũ — hai
     AppBar chồng chữ lên nhau, người dùng phản hồi *"xấu quá"*, rồi lần thứ
     hai *"sao nhiều màn để trong suốt vậy"*. Route bọc `PageBackground` (vẫn
     đúng `AppGradients.page` nên nhìn không khác nền chung; đây không phải
     "đặt màu đục cho `Scaffold`" bị cấm ở trên).
  2. **Chuyển cảnh.** Nền đục thôi vẫn chưa đủ: chuyển cảnh mặc định của
     Android (`ZoomPageTransitionsBuilder`) làm mờ dần *cả hai* màn, nên giữa
     chừng chính cái nền vừa thêm cũng đang mờ và vẫn nhìn xuyên. Route dùng
     `SlideTransition` trượt ngang — màn mới đục sẵn từ đầu, che dần màn cũ,
     không lúc nào thấy hai màn cùng lúc.

  Lần đầu chỉ màn tìm nhân viên tự dựng `PageRouteBuilder` riêng, còn 8 màn
  push bằng `MaterialPageRoute` thì vẫn trong suốt — bài học: **cách push phải
  nằm ở một chỗ dùng chung**, đừng bắt từng màn tự nhớ bọc nền.
- **Nút hành động chính dùng `GradientButton`** (`widgets/common.dart`), không
  phải `ElevatedButton`: gradient ngang xanh ngọc → mint, vòng tròn trắng bọc
  icon, mũi tên ở mép phải. Chỉ dành cho nút được bấm nhiều nhất trên màn
  ("Tất cả đi làm"); nút thường vẫn là `ElevatedButton` để nó không tranh
  chú ý.
  Mỗi màu có 2–3 mức: `*Soft` cho nền mảng lớn (chip, thẻ), `*Medium` cho ô
  nhỏ như ô ngày trong lịch — nền `*Soft` ở ô cỡ 45px nhìn ra gần như trắng.
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

Bản kế tiếp gồm 3 thẻ, và **hai trong ba đã bị bỏ** theo yêu cầu người dùng
(07/09/2026) vì *"thừa, không cần thiết"*:

| Thẻ | Số phận |
|---|---|
| ~~Quỹ lương chia làm gì~~ (thanh 2 màu: lương công / tăng ca) | **Đã xoá** — tổng quỹ lương đã nằm ở `StatGrid` đầu màn, tỉ lệ 99%/1% thì thanh chẳng nói thêm gì |
| ~~Ngày công trong kỳ~~ (thanh 3 màu: đủ ngày / nửa công / nghỉ) | **Đã xoá** — tổng công cũng đã có ở `StatGrid` |
| Đáng chú ý | **Giữ**, nhưng chuyển sang kiểu xem **Bảng lương**, nằm ngay dưới bảng số (`widgets/highlights_card.dart`) |

Đừng dựng lại hai thẻ đã xoá. Bài học: **một con số đã hiện ở đầu màn thì
đừng vẽ lại thành thanh ở giữa màn.**

Nguyên tắc rút ra, áp dụng cho mọi biểu đồ thêm sau này:
**chỉ vẽ thanh khi các phần chênh nhau rõ rệt; còn lại viết thẳng tên và số.**

Tab "Biểu đồ" hiện chỉ còn **"Quỹ lương theo thời gian"**
(`widgets/payroll_trend_chart.dart`, người dùng yêu cầu 07/09/2026) — ngoại lệ
*có điều kiện* của nguyên tắc trên: trục ngang là thời gian nên hình vẽ có
nghĩa kể cả khi các giá trị xấp xỉ nhau, vì hình dáng thay đổi mới là thứ cần
nhìn. Ba chế độ, hai kiểu vẽ:

| Chế độ | Kiểu vẽ | Cách đọc số |
|---|---|---|
| **Tháng** (12 kỳ của năm) | **Biểu đồ miền** vẽ bằng `CustomPaint` | **Chạm vào chấm** → toast + dòng số tiền dưới biểu đồ |
| **Quý** (4 quý) · **Năm** (3 năm) | Cột dọc | Số tiền viết sẵn dưới mỗi cột |

Vì sao tháng phải là miền + chạm: 12 cột thì mỗi cột rộng chưa tới 25px,
không viết nổi "22.375.000" dưới chân. Nhưng **không được** chỉ có hình mà
không tra được số — đó đúng là lỗi đã mắc hai lần ở trên. Nên chấm phải chạm
được, và điểm chạm bắt **theo ô chia đều** (`dx / (width / n)`), không bắt
trúng chấm 4px — bấm mãi không được thì coi như không có.

Năm điều bắt buộc giữ:

- Trục dọc **luôn bắt đầu từ 0**, đừng cắt trục để "phóng to phần chênh lệch".
- Điểm / cột nằm **giữa ô của nó** (`x = width * (i + 0.5) / n`) để khớp với
  hàng nhãn bên dưới (mỗi nhãn một `Expanded`); miền kéo phẳng ra hai mép cho
  đỡ hụt hai đầu.
- Gộp theo **kỳ lương** chứ không theo tháng dương lịch — quý của một kỳ lấy
  từ `PayPeriod.quarter` (tính theo tháng chốt kỳ, cùng quy ước với `title`).
- Khoảng **đang diễn ra** phải đánh dấu riêng (màu nhạt / chữ "đang diễn ra"),
  nếu không người dùng tưởng quỹ lương tự nhiên tụt hẳn.
- Khoảng **chưa tới** (`_Bucket.future`) thì **không vẽ điểm** — kéo đường về
  0 ở các tháng chưa tới thì nhìn như quỹ lương rơi xuống đáy.

Dữ liệu đọc một lần cho cả khoảng bằng `DataService.getRecordsBetween()` rồi
chia nhóm ở client, mỗi kỳ cộng tiền bằng `DataService.totalPayrollOf()` —
đừng gọi Firestore một lần cho mỗi kỳ. Quỹ lương kỳ cũ tính theo **mức lương
hiện tại** của từng người (app không lưu lịch sử lương); thẻ có ghi chú câu
này, đừng bỏ đi.

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
| Nửa công / Tuỳ chỉnh / bỏ chấm | Chạm nút ⌄ cuối dòng → bảng chọn | Ít gặp, chấp nhận 2 chạm (Tuỳ chỉnh thêm 1 hộp nhập giờ) |
| Tăng ca | Chạm chip giờ bên phải | Độc lập với trạng thái |

- Chip trạng thái chỉ xoay vòng **Đi làm ↔ Nghỉ**. Nửa công và Tuỳ chỉnh cố ý
  *không* nằm trong vòng xoay này — nếu thêm vào, người dùng phải chạm 2–3
  lần mới về được trạng thái mong muốn, hỏng luôn mục tiêu tốc độ. Chạm chip
  của một ngày đang Tuỳ chỉnh vẫn đưa thẳng về Nghỉ (giống Nửa công), không
  quay vòng qua Đi làm trước.
- "Tất cả đi làm" có **Hoàn tác** trong SnackBar 6 giây
  (`DataService.restoreDay`), vì một cú bấm nhầm sửa cùng lúc cả chục bản ghi.
- Bỏ chấm = **xoá hẳn document** (`clearRecord`), không phải ghi trạng thái
  `NONE`. "Chưa chấm" nghĩa là không có bản ghi.
- Nút "?" trên thanh tiêu đề mở bảng giải thích 5 trạng thái + các thao tác
  (`showAttendanceHelp`). Người dùng không rành công nghệ nên cần chỗ tra.
- **Điểm chạm mở bảng chọn phải luôn nhìn thấy được.** Bản đầu để cả vùng tên
  làm điểm chạm nhưng không vẽ gì, người dùng phản hồi "không thấy điểm chạm
  vào gì cả" → vùng chạm vô hình = vùng chạm không tồn tại. Bản thứ hai vẽ nút
  ⋯ chen giữa tên và chip trạng thái, người dùng chê xấu. **Bản hiện tại**:
  một `IconButton` mũi tên xuống (`keyboard_arrow_down_rounded`) ở **cuối
  dòng**, sau chip OT — đứng riêng ở mép phải nên không cắt ngang tên, vẫn rõ
  là bấm được. Đừng đưa nó trở lại giữa dòng. **Cả dòng** cũng mở đúng bảng
  chọn đó — `Material` + `InkWell` bọc toàn bộ `Row`, nút mũi tên chỉ là chỗ
  để *nhìn thấy* thao tác. Giữ cả hai, đừng bỏ vùng chạm của dòng đi.
  Dùng `Material(shape:)` chứ không `Container(decoration:)` cho nền dòng:
  `InkWell` nằm trong `Container` có màu thì gợn nước bị nền che, chạm xong
  không thấy phản hồi gì.
- **Ô tìm kiếm ở tab là nút, không phải ô nhập.** Chạm vào mở hẳn màn
  `AttendanceSearchScreen` (`attendance_search_screen.dart`): AppBar có nút
  back + tiêu đề giữa, ô nhập tự bật bàn phím, dưới là kết quả chiếm cả màn.
  Lý do: ô tìm kiếm nằm dưới thanh chọn ngày + 4 ô thống kê + nút "Tất cả đi
  làm", gõ tại chỗ thì bàn phím bật lên che gần hết danh sách, còn chưa tới
  hai dòng kết quả. Ô ở tab dùng `SearchBox(readOnly: true, onTap: ...)` nên
  vẫn nhìn y hệt ô nhập — người dùng bấm vào theo thói quen.
  Màn tìm kiếm **có đủ mọi thao tác chấm công** như ở tab (chip trạng thái,
  chip OT, bảng chọn đầy đủ) — dùng chung `AttendanceActions` và
  `AttendanceRow`, đừng chép lại logic ghi ở hai nơi. Số thứ tự trong kết quả
  lọc lấy **vị trí trong danh sách gốc**, để khớp với số nhìn thấy ở tab.
- **Không thêm dòng gợi ý thao tác dạng chữ trên đầu danh sách.** Đã có
  (`_RowHint`, kèm `WidgetSpan` vẽ nút ⋯) và bị gỡ theo yêu cầu người dùng:
  chú thích dài trên đầu bảng chỉ tốn chỗ. Chỗ tra cứu thao tác là nút "?"
  ở thanh tiêu đề.

### 5.2.1. Lịch chọn ngày (`date_picker_dialog.dart`)

Không dùng `showDatePicker` của Material — lịch mặc định chỉ biết tháng dương
lịch và không biết gì về dữ liệu công. Người dùng phản hồi: *"các ngày nó
đang không biểu hiện rõ của một tháng ngày công"*. Bản tự viết phải giữ được
hai điều sau, đừng rút gọn mất:

- **Lưới vẽ theo kỳ lương, không theo tháng dương lịch.** Cơ sở chốt "28 tháng
  trước → 27 tháng này" thì nhìn vào phải thấy đúng dải đó liền một mạch, chứ
  không bị cắt đôi ở mốc mùng 1. Nút ‹ › chuyển **kỳ**, tiêu đề dùng
  `PayPeriod.title` + `rangeLabel`. Kỳ chứa một ngày dựng bằng
  `PayPeriod.current(startDay, now: day)`. **Đừng thêm nhãn tháng ("T9") vào
  trong ô ngày** — đã làm và bị người dùng yêu cầu bỏ: khoảng ngày của kỳ nằm
  sẵn ở tiêu đề ngay trên lưới, nhãn trong ô chỉ làm ô ba dòng thêm chật.
- **Mỗi ngày mang dấu tình trạng chấm công**: đã chấm đủ cả danh sách · mới
  chấm được một phần · chưa chấm. Số liệu lấy từ `watchPeriod` (đếm bản ghi
  mỗi `workDate`) so với `watchActiveEmployees().length`. Danh sách nhân viên
  chưa về (`length == 0`) thì coi như "đã chấm đủ", tránh nháy một lượt màu
  cam rồi mới đổi lại.
- **Ô ngày phải đánh dấu bằng cả ba thứ: nền + viền + màu chữ.** Bản đầu chỉ
  tô nền `presentSoft` / `overtimeSoft`, người dùng phản hồi *"màu sắc của
  chấm đủ, chấm thiếu không thể hiện rõ"* — ô chỉ rộng ~45px nên hai màu
  *Soft* nhìn ra gần như trắng. Nay dùng `presentMedium` / `overtimeMedium`
  (đậm vừa, thêm vào `AppColors` đúng cho việc này) kèm viền và chữ cùng tông.
  Hôm nay giữ viền `primary` dày 2.2px để vẫn nổi giữa các ô cùng màu.
  Ô bo góc **8px**, không phải hình tròn — bán kính 18px trên ô ~48px làm ô
  thành cái vòng tròn, người dùng không muốn kiểu đó.
- **Ngày của kỳ trước / kỳ sau vẫn được vẽ, chỉ để mờ** (`isOutside`,
  `Opacity 0.42`) — ô trắng trơn ở đầu và cuối lưới làm người dùng tưởng lịch
  bị lỗi. Chạm vào một ngày mờ thì `_selectDay` tự nhảy sang kỳ chứa ngày đó,
  đây là cách chuyển kỳ nhanh hơn nút ‹ ›. Ngày ngoài kỳ **không** vẽ dấu
  tình trạng nào: `watchPeriod` chỉ đọc kỳ đang xem nên không biết gì về
  chúng, vẽ "chưa chấm" là nói sai. Lưới cố định 6 hàng (42 ô) như lịch giấy
  nên chiều cao không nhảy khi chuyển kỳ.
- Dưới lưới **chỉ một dòng**, vừa là chú giải màu vừa là số liệu: ô màu đứng
  ngay cạnh con số ("▪ 4 ngày chấm đủ · ▪ 2 ngày chấm thiếu · 25 ngày chưa
  chấm"), mục nào bằng 0 thì ẩn. Bản đầu tách làm hai phần — bốn mục chú giải
  rồi thêm một câu tổng kết — người dùng chê rối và thừa. **Chỉ đếm ngày đã
  qua**: kỳ đang diễn ra mà đếm cả ngày chưa tới thì lúc nào cũng hiện một con
  số đáng lo mà người dùng không sửa được.
- Thẻ ngày đang chọn **chỉ hai dòng**: ngày dương ("Thứ hai, 31/08/2026") và
  ngày âm kèm can chi. Đừng thêm lại dòng "Ngày 31 tháng 8, 2026" — nó nói
  đúng điều dòng trên đã nói; cũng đừng thêm lại câu "chỉ chọn được ngày hôm
  nay trở về trước", ngày chưa tới đã để mờ và bấm không được.

### 5.2.2. Âm lịch (`core/lunar.dart`)

Cơ sở của người dùng tính công theo lịch âm, nên **mọi chỗ hiện ngày đều kèm
ngày âm**: số nhỏ dưới từng ô trong lịch, dòng phụ trên thanh chọn ngày
(`Fmt.lunarBrief`), và dòng đầy đủ kèm can chi ở thẻ ngày đang chọn
(`Fmt.lunarFull`). Đây là bổ sung ngoài đặc tả gốc, do người dùng yêu cầu
ngày 07/09/2026 — giống ngoại lệ "nửa công" ở §0.4.

- `LunarDate.fromSolar()` cài thuật toán Hồ Ngọc Đức (thiên văn Jean Meeus).
  **Múi giờ cố định +7** — lịch Việt Nam và lịch Trung Quốc thỉnh thoảng lệch
  nhau đúng một ngày vì điểm sóc rơi vào hai ngày khác nhau ở hai múi giờ.
  Đừng đổi `_timeZone` sang 8, cũng đừng thay bằng package âm lịch nào (app
  cố ý không phụ thuộc thư viện lịch, kể cả `intl`).
- Các phép chia trong thuật toán phải **làm tròn xuống** (`_int` = `floor`),
  không dùng `~/` — có biểu thức ra số âm, `~/` cắt về 0 thì sai kết quả.
- Test khoá bằng mốc lịch in: mùng 1 Tết 2023–2026, rằm Trung thu 2024, tháng
  6 nhuận Ất Tỵ 2025 và tháng 2 nhuận Quý Mão 2023. Sửa gì trong `lunar.dart`
  thì các test đó phải còn xanh.
- Trong lưới, mùng 1 âm hiện cả tháng ("1/8", thêm "N" nếu tháng nhuận) và tô
  đậm hơn — đó là mốc người dùng dò nhiều nhất.

### 5.2.3. Nút Lưu ở các màn Cài đặt

- **Nút Lưu không được nằm cuối `ListView`.** Body của `Scaffold` không tự
  tránh thanh điều hướng của Android, nên nút cuối danh sách bị che — người
  dùng phản hồi *"không vuốt được lên để bấm nút lưu"*. Màn "Thiết lập chung"
  đã chuyển nút xuống `bottomNavigationBar` bọc `SafeArea`; ba màn còn lại
  (`account_screen`, `salary_settings_screen`, `employee_form_screen`) cộng
  `MediaQuery.viewPaddingOf(context).bottom` vào padding đáy.
- **Màn dài thì thêm nút Lưu ở `AppBar`**, chỉ hiện khi có thay đổi thật
  (`_hasChanges` so giá trị đang nhập với `_settings` vừa tải). Sau khi lưu
  phải gán `_settings = next` — không thì nút cứ sáng mãi dù chẳng còn gì để
  lưu.
- Kèm `PopScope` hỏi lại khi bấm back mà còn thay đổi chưa lưu.
- **Mọi `showModalBottomSheet` phải bọc `SafeArea`** (và `SingleChildScrollView`
  nếu là bảng nhiều chữ). Bảng chọn của Material **không** tự tránh thanh điều
  hướng Android — `useSafeArea` mặc định là `false` — nên dòng cuối bị thanh đó
  đè lên; người dùng phản hồi *"lỗi đè lên này thấp quá"* ở bảng "Lần đầu sử
  dụng". Bốn bảng hiện có (`ot_picker`, `status_picker`, `showAttendanceHelp`,
  `period_picker`) đều đã bọc, thêm bảng mới thì làm y như vậy.

### 5.3. Xuất file

`ExportService.exportAndShare()` dựng .xlsx bằng package `excel` rồi mở khay
chia sẻ của hệ điều hành (`share_plus`) để người dùng lưu / gửi Zalo / lên Drive.
File ghi vào thư mục tạm (`path_provider`), không ghi thẳng vào Downloads —
Android scoped storage.

**Bố cục dọc, mỗi nhân viên một khối** (đổi ngày 18/09/2026 theo yêu cầu người
dùng — bản đầu là bảng ngang kiểu bảng công giấy, mỗi ngày một cột, nhưng một
tháng 30 ngày thì bảng có tới ~40 cột, người dùng phản hồi *"để ngang mất lắm"*
khi in, muốn *"vừa khổ A4"*). Chỉ 5 cột cố định
(`ExportService._colDate/_colWeekday/_colStatus/_colUnits/_colOt`): Ngày · Thứ
· Trạng thái · Công · OT (giờ) — tổng cộng ~73 đơn vị độ rộng, vừa một trang
A4 dọc. Mỗi nhân viên là một khối xếp từ trên xuống:

1. Banner tên (`"{STT}. {Tên}"`, nền xanh nhạt như tiêu đề cột).
2. Lương/ngày, Đơn giá OT/giờ.
3. Bảng ngày: mỗi ngày trong kỳ một dòng, cột Trạng thái viết chữ đầy đủ
   ("Đi làm", "Nửa công", "Nghỉ", "Chưa chấm", hoặc "Tuỳ chỉnh (6h)" —
   `ExportService._statusLabel`, dùng `Fmt.customWorkHours` chứ không viết
   số công thập phân, cùng lý do đã nêu ở §0.4). Cột Công là số công thật
   (`r.workUnits`), cột OT là số giờ OT nếu có.
4. Dòng TỔNG (tổng công + tổng OT của kỳ), Số ngày nghỉ, Lương công, Tiền OT,
   TỔNG LƯƠNG, rồi một dòng trống ngăn với khối kế tiếp.

Cuối file là khối "TỔNG CỘNG TOÀN BỘ CƠ SỞ" cùng khuôn dạng, rồi phần ghi chú.

**Đây là kiểu "một nhân viên xem chi tiết dễ, đọc dọc từ trên xuống"**, đánh
đổi lấy file dài hơn hẳn (10-20 người × ~40 dòng/người), người dùng đã được
hỏi và chọn kiểu này thay vì gộp tất cả nhân viên vào một bảng dài duy nhất
(mỗi dòng một cặp nhân viên-ngày) — nếu sau này cần đổi hướng, hỏi lại người
dùng trước, đừng tự quay lại bảng ngang.

`excel` (gói Dart) **không hỗ trợ đặt khổ giấy / hướng in** (đã tra, phiên bản
4.0.6 không có API nào cho `pageSetup`/orientation) — cách duy nhất để file
"vừa khổ A4 dọc" là giữ bảng ít cột như trên, không thể ép hướng in bằng code.

Tiền vẫn luôn ghi bằng `DoubleCellValue` + `numberFormat: '#,##0'`
(`ExportService._cellMoney`/`_cellMoneyBold`, ghép nhãn ở cột Ngày và số tiền
ở cột Thứ qua `_putLabelMoney`) để Excel hiểu là số, không phải chuỗi — đừng
đổi sang `TextCellValue`, kể cả khi ghép chung một dòng "nhãn: giá trị" cho
gọn trông có vẻ tiện hơn.

### 5.4. Khởi động app — đừng chờ gì trong `main()`

Bản đầu `main()` `await Firebase.initializeApp()` + `applyRememberPolicyOnStart()`
**rồi mới** `runApp`, nên lúc mở app người dùng nhìn màn trắng của hệ thống mấy
giây: *"mới đầu bật lên hiện màn này lâu vậy"*. Thứ tự hiện tại:

1. `main()` chỉ khoá hướng màn hình rồi `runApp` ngay — **không `await` gì**.
2. `home` là `SplashScreen`: hiện logo `assets/images/img_splash.png`, tên app,
   ba chấm chạy; **trong lúc đó** mới `Firebase.initializeApp`, bật offline
   persistence và áp chính sách "Lưu đăng nhập".
3. Xong thì `pushReplacement` sang `AuthGate` (fade 350ms) → `IntroScreen` hoặc
   `HomeShell`.

- Splash hiện **tối thiểu 5 giây** (`_minShow`) — con số do người dùng chọn,
  đừng tự rút xuống. Nó chờ *song song* với việc khởi tạo nên không cộng thêm
  vào thời gian mở app.
- Khởi tạo lỗi (thường là mất mạng lần đầu chạy) thì hiện lỗi + nút **Thử
  lại**, đừng để ba chấm chạy mãi.
- Nền màn chào của **hệ thống** (Android, trước khi Flutter vẽ khung đầu) đặt
  bằng `@color/splash_background` = `#E6FBF4` — đúng màu đỉnh `AppGradients.page`
  — ở `values/`, `values-night/`, `values-v31/` (Android 12+ dùng
  `windowSplashScreenBackground`) và cả `drawable*/launch_background.xml`. Sửa
  màu gradient thì sửa luôn mấy file đó, không thì mở app sẽ loé một khung
  trắng.
- `DataService`/`AuthService` là singleton lười khởi tạo, chỉ chạm tới sau
  splash nên không cần Firebase lúc `main()`. **Đừng** tạo instance của chúng ở
  cấp thư viện (top-level) — làm vậy là gọi `FirebaseFirestore.instance` trước
  khi init và crash.

### 5.5. Dialog chào mừng và phần đánh giá app

Cả hai do người dùng yêu cầu ngày 08/09/2026.

**Dialog chào mừng** (`screens/welcome_dialog.dart`) — `showWelcomeIfFirstTime`,
gọi từ `HomeShell.initState` trong `addPostFrameCallback`:

- **Chỉ hiện một lần cho mỗi tài khoản trên mỗi máy** (khoá
  `welcome_seen_<uid>` trong `SharedPreferences`). Đừng đổi thành mỗi lần mở
  app: tab Chấm công có mục tiêu xong 10–20 người trong 15–30 giây (§5.2),
  chèn một cú bấm vào mỗi buổi sáng là phá đúng mục tiêu đó. Khoá ghép `uid`
  chứ không dùng một khoá chung, để máy dùng cho hai cơ sở thì cơ sở thứ hai
  vẫn được chào.
- Ghi khoá **sau khi** dialog đóng, không phải trước khi mở — tắt app giữa lúc
  đang đọc thì lần sau vẫn được chào.
- Phải gọi sau khung hình đầu: trong `initState` chưa có `Overlay` để đẩy
  dialog lên.
- **Phải đợi màn Home thành route trên cùng** (`_waitUntilHomeIsTop`) rồi mới
  hiện. Bản đầu hiện ngay và người dùng phản hồi *"sao lại tắt đi nhỉ"*:
  `LoginScreen`/`RegisterScreen` dọn stack bằng `popUntil((r) => r.isFirst)`,
  mà `HomeShell` mount **trước** lệnh đó (`AuthGate` đổi nội dung route đầu
  ngay khi `authState` đổi, còn `popUntil` chỉ chạy khi `signIn` await xong)
  → dialog vừa đẩy lên bị chính `popUntil` kia pop mất. Chờ quá 10s thì
  không hiện và **không ghi khoá**, để lần mở app sau chào lại.
- Đóng bằng nút X góc trên phải hoặc nút "Bắt đầu" — cả hai gọi thẳng
  `Navigator.pop()`. `barrierDismissible: false` chặn chạm ra ngoài,
  `PopScope(canPop: false)` chặn cử chỉ back của hệ thống; `canPop` không ảnh
  hưởng tới `Navigator.pop()` gọi tay nên hai nút trên vẫn đóng được bình
  thường.
- **Giao diện theo mẫu người dùng đưa 08/09/2026** (ảnh chụp màn tương tự):
  nền `assets/images/img_bg_welcome.png` phủ sau toàn dialog, icon lịch+tick
  ghép huy hiệu đồng hồ ở góc (`_CalendarClockIcon` — hai icon Material lồng
  nhau bằng `Stack`, không phải ảnh vẽ riêng), tiêu đề + phụ đề, ba dòng tính
  năng (`_FeatureRow`: icon tròn nền nhạt + tiêu đề cùng màu + mô tả — hai
  dòng đầu xanh dương `info`/`infoSoft`, dòng cuối cam `overtime`/
  `overtimeSoft`, đúng màu ảnh mẫu), dòng "Bạn chỉ cần 3 tab: ...", rồi
  `GradientButton` full-width. Bản đầu tiên (chưa theo ảnh mẫu) có thêm nút
  phụ "Thêm nhân viên ngay" chuyển sang tab Cài đặt — **đã bỏ** khi đổi giao
  diện vì ảnh mẫu chỉ có một nút hành động; cần lại thì chuyển tab qua
  `AppEvents.requestTab`, **không** `HomeShell.of(context)` (dialog là route
  nằm cùng cấp `HomeShell` trong Overlay, xem §6).
- Ảnh nền nằm ở `assets/images/` như mọi ảnh khác của app (đã khai báo trong
  `pubspec.yaml` qua `assets/images/`) — đừng để lẻ ở `assets/` gốc, thêm ảnh
  mới ở đó sẽ không được đóng gói.

**Đánh giá app** (`screens/settings/review_screen.dart`, `showReviewDialog`) —
**là một dialog nổi trên tab Cài đặt, không phải màn `push` riêng.** Bản đầu
dựng thành `ReviewScreen` (cả `Scaffold`) rồi lại đổi vì người dùng muốn xem
ảnh mẫu (dialog kiểu "rate us" phổ biến: linh vật `assets/images/img_rate.png`
+ tiêu đề + 5 sao + nút "Đánh giá ngay" + "Để sau") — **đừng quay lại kiểu
`Scaffold` toàn màn**, giữ đúng khuôn dialog.

- **`showReviewDialog(context)` gọi thẳng, không qua `pushScreen`.** Bên trong
  `showDialog<bool>` trả về `true` khi bấm "Đánh giá ngay", `false`/`null` khi
  "Để sau" hoặc nút X.
- **Mở Play Store *sau khi* dialog đã đóng**, dùng `context` của màn Cài đặt
  (tham số của `showReviewDialog`) — *không* dùng `context` bên trong
  `_ReviewDialog` để `launchUrl`/`showToast`: dialog đã `pop` thì context đó
  mất, gọi vào là ăn lỗi hoặc không hiện gì. Đây là lý do hàm tách làm hai
  lớp: `_ReviewDialog` chỉ `pop(true/false)`, còn việc mở Store nằm ở
  `showReviewDialog` — thấy y hệt bẫy "màn được `push`" ở §6 nhưng lần này là
  dialog với context bên ngoài.
- 5 sao **sáng lần lượt khi mở dialog** (`_animateStars`, mặc định 5 sao) và
  chạy lại nếu chạm chọn số sao khác — hiệu ứng dùng
  `ScaleTransition(scale: animation, ...)`, **không phải** tham số
  `animation:` (đó là lỗi build đã gặp — `ScaleTransition` không có tham số
  đó, tham số đúng là `scale`).
- Bấm "Đánh giá ngay" ghi số sao **không chờ** (`.catchError` nuốt lỗi) rồi
  `pop(true)` ngay — đây là hành động rời màn, lỗi ghi (mất mạng) không được
  cản việc mở Store.
- Ghi vào **`companies/{cid}/reviews`**, không phải collection riêng ở gốc:
  nhánh con của cơ sở đã được rules cho phép sẵn (chủ ghi, tài khoản tổng đọc)
  nên **không phải sửa và Publish lại `firestore.rules`**. Thêm collection ở
  gốc là phải sửa rules, đừng làm.
- Mỗi lượt gửi là một document mới, không ghi đè — đây *không* phải dữ liệu
  công nên không cần cơ chế chống trùng của §0.3.
- Tài khoản tổng xem lượt gần nhất của cơ sở ở `CompanyReportScreen`
  (`DataService.latestReview`, `orderBy createdAt` + `limit 1` → vẫn không cần
  composite index). Đọc lỗi thì bỏ qua thẻ đó, đừng để cả màn báo cáo chết.
- **Play Store**: cờ `kOnPlayStore` trong `review_screen.dart` đang `false` vì
  app giao bằng file APK — bấm "Đánh giá ngay" lúc này chỉ hiện toast cảm ơn,
  chưa mở được Store thật. Lên store rồi đổi cờ thành `true` là nút mở thẳng
  `_playStoreUrl` (`url_launcher`, dependency thêm riêng cho việc này), không
  phải sửa gì khác.

---

## 6. Bẫy đã gặp

- **`EmptyState` tràn khi bàn phím bật.** Nó nằm trong `Expanded` ở tab Chấm
  công; gõ vào ô tìm nhân viên mà không ra kết quả thì chỗ trống còn chưa tới
  200px, `Column` cao ~200px sinh vạch vàng đen. Đã bọc `LayoutBuilder`: chiều
  cao bị bó thì cho cuộn (`SingleChildScrollView` + `ConstrainedBox(minHeight)`),
  còn **chiều cao vô hạn thì trả thẳng nội dung** — `EmptyState` cũng được
  dùng bên trong `ListView` ở tab Tổng quan, bọc viewport lồng viewport không
  giới hạn là lỗi ngay. Widget nào đặt được ở cả hai chỗ đều phải theo mẫu này.
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
