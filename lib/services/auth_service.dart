import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App chỉ có MỘT tài khoản sử dụng - không có role, không có permission.
///
/// Người dùng nhập "Tài khoản" (ví dụ: admin). Nếu chuỗi nhập không phải
/// email thì tự ghép thêm hậu tố nội bộ để dùng với Firebase Auth.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _domain = 'tickgo.app';
  static const _kRemember = 'remember_login';
  static const _kLastAccount = 'last_account';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authState => _auth.authStateChanges();

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _db.collection('app_user').doc('main');

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

  /// Đăng nhập tài khoản duy nhất.
  ///
  /// Lần chạy đầu tiên (chưa có tài khoản nào trong hệ thống) sẽ tự tạo
  /// tài khoản này để người dùng không phải vào Firebase Console.
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
      final maybeFirstRun = e.code == 'user-not-found' ||
          e.code == 'invalid-credential' ||
          e.code == 'INVALID_LOGIN_CREDENTIALS';
      if (!maybeFirstRun) throw AuthFailure(_message(e));
      await _createFirstAccount(email, password);
    }

    await _userDoc.set({
      'account': email,
      'displayName': displayAccount(email),
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _saveRemember(remember, account.trim());
  }

  /// Tạo tài khoản duy nhất ở lần chạy đầu tiên.
  ///
  /// Không thể hỏi Firestore trước khi đăng nhập (rules chặn khi chưa có auth),
  /// nên thứ tự là: tạo tài khoản -> lúc này đã có auth -> mới kiểm tra xem app
  /// đã có chủ chưa. Nếu đã có thì huỷ luôn tài khoản vừa tạo.
  Future<void> _createFirstAccount(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      // Tài khoản đã tồn tại nghĩa là bước đăng nhập ở trên sai mật khẩu.
      if (e.code == 'email-already-in-use') {
        throw const AuthFailure('Sai tài khoản hoặc mật khẩu.');
      }
      throw AuthFailure(_message(e));
    }

    final existing = await _userDoc.get();
    final owner = existing.data()?['account'] as String?;
    if (existing.exists && owner != null && owner != email) {
      // App đã có tài khoản khác -> giữ nguyên tài khoản cũ.
      await _auth.currentUser?.delete();
      throw AuthFailure(
        'App đã có tài khoản "${displayAccount(owner)}". '
        'Hãy đăng nhập bằng tài khoản đó.',
      );
    }
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
