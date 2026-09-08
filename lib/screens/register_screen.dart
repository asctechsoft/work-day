import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/auth_service.dart';
import 'intro_screen.dart';

/// Tạo một cơ sở mới: tài khoản chủ + dữ liệu ban đầu của cơ sở đó.
///
/// Mỗi tài khoản là chủ của đúng một cơ sở, dữ liệu nằm trong
/// `companies/{uid}` (xem `firestore.rules`). Vì vậy màn này **bắt buộc dùng
/// email thật** - còn liên hệ được với khách, và người quản trị đặt lại được
/// mật khẩu cho họ từ Firebase Console khi cần.
///
/// Cần mạng: tạo tài khoản Firebase Auth không làm offline được. Sau khi có
/// tài khoản rồi thì chấm công offline vẫn bình thường.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orgName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _orgName.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await AuthService.instance.registerCompany(
        orgName: _orgName.text,
        email: _email.text,
        password: _password.text,
        remember: true,
      );
      // Tạo xong là đã đăng nhập luôn: `AuthGate` tự chuyển sang 3 tab.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Không tạo được cơ sở. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Tạo cơ sở mới')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            28 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 4),
                const Center(child: AppLogo(size: 76)),
                const SizedBox(height: 18),
                const Text(
                  'Mỗi cơ sở có một tài khoản riêng. Dữ liệu chấm công của '
                  'cơ sở này hoàn toàn tách biệt với các cơ sở khác.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _orgName,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'Tên cơ sở',
                    prefixIcon: Icon(
                      Icons.store_outlined,
                      color: AppColors.textMuted,
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Vui lòng nhập tên cơ sở'
                      : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _email,
                  autocorrect: false,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'Email của chủ cơ sở',
                    prefixIcon: Icon(
                      Icons.mail_outline_rounded,
                      color: AppColors.textMuted,
                    ),
                  ),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: 'Mật khẩu',
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.textMuted,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Mật khẩu phải có ít nhất 6 ký tự'
                      : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _confirm,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    hintText: 'Nhập lại mật khẩu',
                    prefixIcon: Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.textMuted,
                    ),
                  ),
                  validator: (v) => (v != _password.text)
                      ? 'Hai mật khẩu chưa giống nhau'
                      : null,
                ),

                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _ErrorBox(_error!),
                ],

                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Tạo cơ sở'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Lần tạo cơ sở cần có mạng. Sau đó chấm công không cần '
                  'mạng vẫn được, dữ liệu tự đồng bộ khi có mạng lại.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Bắt buộc email thật để còn gửi được mail đặt lại mật khẩu.
  static String? _validateEmail(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Vui lòng nhập email';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
    return ok ? null : 'Email chưa đúng định dạng';
  }
}

/// Khung báo lỗi đỏ, dùng chung kiểu với màn đăng nhập.
class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.absentSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.absent,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.absent, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}
