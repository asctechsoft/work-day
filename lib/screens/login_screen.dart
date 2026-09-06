import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/auth_service.dart';
import '../widgets/common.dart';
import 'intro_screen.dart';

/// Đăng nhập tài khoản duy nhất của app.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _account = TextEditingController();
  final _password = TextEditingController();

  bool _remember = true;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final auth = AuthService.instance;
    final last = await auth.getLastAccount();
    final remember = await auth.getRemember();
    if (!mounted) return;
    setState(() {
      _account.text = last;
      _remember = remember;
    });
  }

  @override
  void dispose() {
    _account.dispose();
    _password.dispose();
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
      await AuthService.instance.signIn(
        account: _account.text,
        password: _password.text,
        remember: _remember,
      );
      // _AuthGate ở main.dart tự chuyển sang màn 3 tab khi đã đăng nhập.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Đăng nhập không thành công. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(backgroundColor: AppColors.surface, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                const Center(child: AppLogo(size: 96)),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'WorkDay',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Quản lý công việc mỗi ngày',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 32),

                TextFormField(
                  controller: _account,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'Tài khoản',
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.textMuted,
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Vui lòng nhập tài khoản'
                      : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
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

                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
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
                            _error!,
                            style: const TextStyle(
                              color: AppColors.absent,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                      : const Text('Đăng nhập'),
                ),
                const SizedBox(height: 6),

                InkWell(
                  onTap: () => setState(() => _remember = !_remember),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _remember,
                            activeColor: AppColors.primary,
                            visualDensity: VisualDensity.compact,
                            onChanged: (v) =>
                                setState(() => _remember = v ?? false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Lưu đăng nhập',
                          style: TextStyle(
                            color: AppColors.textBody,
                            fontSize: 14.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'Chỉ 1 tài khoản sử dụng cho toàn bộ app',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: _busy ? null : _showFirstRunHelp,
                    child: const Text(
                      'Lần đầu sử dụng?',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFirstRunHelp() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SectionTitle('Lần đầu sử dụng'),
            SizedBox(height: 12),
            Text(
              'App chỉ dùng một tài khoản duy nhất.\n\n'
              'Lần đăng nhập đầu tiên, hãy nhập tài khoản và mật khẩu '
              'bạn muốn dùng lâu dài (mật khẩu tối thiểu 6 ký tự). '
              'App sẽ tự tạo tài khoản đó cho cơ sở của bạn.\n\n'
              'Những lần sau chỉ cần đăng nhập bằng đúng thông tin này.',
              style: TextStyle(height: 1.55, color: AppColors.textBody),
            ),
          ],
        ),
      ),
    );
  }
}
