import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data_service.dart';

/// Đăng nhập / đăng ký. **Mỗi tài khoản là chủ của đúng một cơ sở**, và
/// `companyId` của cơ sở đó chính là `uid` của tài khoản (xem
/// `firestore.rules` và [DataService]).
///
/// Người dùng đăng ký bằng email thật để tự đặt lại được mật khẩu. Tài khoản
/// kiểu cũ không có `@` (ví dụ `admin`) vẫn đăng nhập được: [normalizeAccount]
/// ghép hậu tố nội bộ như trước.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _domain = 'tickgo.app';
  static const _kRemember = 'remember_login';
  static const _kLastAccount = 'last_account';

  /// Giá trị `role` của tài khoản tổng trong `users/{uid}`.
  ///
  /// Chỉ để UI biết có hiện menu "Quản lý cơ sở" hay không - chặn thật nằm ở
  /// `firestore.rules` (danh sách uid trong `isSuperAdmin()`). Client tự sửa
  /// `role` thì rules vẫn không cho đọc thêm gì.
  static const superRole = 'super';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authState => _auth.authStateChanges();

  /// Hồ sơ người dùng: `users/{uid}`. Thay cho `app_user/main` của bản
  /// một-tài-khoản.
  DocumentReference<Map<String, dynamic>> get _userDoc {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthFailure('Chưa đăng nhập.');
    return _db.collection('users').doc(uid);
  }

  /// Tài khoản đang đăng nhập có phải tài khoản tổng không.
  static bool isSuperAccount(Map<String, dynamic> profile) =>
      profile['role'] == superRole;

  static String normalizeAccount(String input) {
    final v = input.trim();
    return v.contains('@') ? v : '$v@$_domain';
  }

  /// Phần hiển thị của tài khoản (bỏ hậu tố nội bộ).
  static String displayAccount(String email) =>
      email.endsWith('@$_domain') ? email.split('@').first : email;

  Future<bool> getRemember() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kRemember) ?? true;
  }

  Future<String> getLastAccount() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kLastAccount) ?? '';
  }

  Future<void> _saveRemember(bool remember, String account) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kRemember, remember);
    if (remember) {
      await p.setString(_kLastAccount, account);
    } else {
      await p.remove(_kLastAccount);
    }
  }

  /// Nếu lần trước người dùng không tick "Lưu đăng nhập" thì đăng xuất
  /// phiên còn sót lại khi mở app.
  Future<void> applyRememberPolicyOnStart() async {
    if (_auth.currentUser == null) return;
    if (!await getRemember()) {
      await _auth.signOut();
    }
  }

  /// Đăng nhập vào cơ sở của tài khoản này.
  ///
  /// **Cố ý KHÔNG tự tạo tài khoản khi đăng nhập** như bản một-tài-khoản
  /// trước đây: giờ mỗi tài khoản là một cơ sở riêng, gõ sai email một lần là
  /// sinh ra một cơ sở rỗng. Muốn có cơ sở mới thì đi qua [registerCompany].
  Future<void> signIn({
    required String account,
    required String password,
    required bool remember,
  }) async {
    final email = normalizeAccount(account);
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    }

    // Không ghi `displayName` ở đây: người dùng đã tự đặt tên hiển thị thì
    // mỗi lần đăng nhập lại ghi đè về tên tài khoản là mất công họ sửa.
    await _userDoc.set({
      'account': email,
      'companyId': _auth.currentUser!.uid,
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _saveRemember(remember, account.trim());
  }

  /// Tạo tài khoản mới **và** cơ sở của tài khoản đó.
  ///
  /// Thứ tự buộc phải là: tạo tài khoản Auth trước (để có `uid` và để rules
  /// cho ghi), rồi mới ghi dữ liệu cơ sở. Nếu bước ghi thất bại thì xoá luôn
  /// tài khoản vừa tạo - thà không có gì còn hơn để lại một tài khoản đăng
  /// nhập được nhưng không có cơ sở nào.
  ///
  /// Cần mạng: `createUserWithEmailAndPassword` không chạy offline được. Sau
  /// khi có tài khoản rồi thì chấm công offline vẫn bình thường.
  Future<void> registerCompany({
    required String orgName,
    required String email,
    required String password,
    required bool remember,
  }) async {
    final mail = normalizeAccount(email);
    final name = orgName.trim();

    final UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: mail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    }

    final user = cred.user!;
    try {
      // companyId = uid của chủ, đúng quy ước của firestore.rules.
      await DataService.instance.createCompany(
        companyId: user.uid,
        orgName: name,
        account: mail,
      );
    } catch (e) {
      await user.delete().catchError((_) {});
      throw AuthFailure('Không tạo được cơ sở: $e');
    }

    // Gửi mail xác minh nhưng KHÔNG chặn dùng app: chặn thì mạng kém một lát
    // là khách không vào được app dù đã trả tiền.
    try {
      await user.sendEmailVerification();
    } catch (_) {}

    await _saveRemember(remember, mail);
  }

  Future<void> updateDisplayName(String name) async {
    await _userDoc.set({'displayName': name}, SetOptions(merge: true));
    await _auth.currentUser?.updateDisplayName(name);
  }

  Future<void> changePassword(String current, String next) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthFailure('Chưa đăng nhập.');
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: current),
      );
      await user.updatePassword(next);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    }
  }

  Stream<Map<String, dynamic>> watchAccount() =>
      _userDoc.snapshots().map((s) => s.data() ?? const <String, dynamic>{});

  Future<void> signOut() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kRemember, false);
    await _auth.signOut();
  }

  String _message(FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'Tài khoản không hợp lệ.',
        'user-disabled' => 'Tài khoản đã bị khoá.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' ||
        'INVALID_LOGIN_CREDENTIALS' =>
          'Sai tài khoản hoặc mật khẩu.',
        'weak-password' => 'Mật khẩu phải có ít nhất 6 ký tự.',
        'email-already-in-use' => 'Tài khoản này đã tồn tại.',
        'too-many-requests' =>
          'Bạn thử quá nhiều lần. Vui lòng đợi một lát rồi thử lại.',
        'network-request-failed' => 'Không có kết nối mạng.',
        'operation-not-allowed' =>
          'Firebase chưa bật đăng nhập Email/Password. '
              'Hãy bật trong Firebase Console > Authentication.',
        'requires-recent-login' => 'Vui lòng đăng nhập lại rồi thử lại.',
        _ => e.message ?? 'Đăng nhập không thành công.',
      };
}

class AuthFailure implements Exception {
  final String message;
  const AuthFailure(this.message);
  @override
  String toString() => message;
}
