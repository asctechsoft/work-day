import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';

/// Tài khoản duy nhất của app: đổi tên hiển thị và mật khẩu.
/// Không có danh sách user, không có role hay permission.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _auth = AuthService.instance;
  final _displayName = TextEditingController();
  bool _busy = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _auth.currentUser;
    final fallback = user?.email == null
        ? ''
        : AuthService.displayAccount(user!.email!);
    try {
      final snap = await _auth.watchAccount().first;
      if (!mounted) return;
      setState(() {
        _displayName.text = (snap['displayName'] as String?) ?? fallback;
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _displayName.text = fallback;
        _loaded = true;
      });
    }
  }

  @override
  void dispose() {
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _displayName.text.trim();
    if (name.isEmpty) {
      showToast(context, 'Tên hiển thị không được để trống', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await _auth.updateDisplayName(name);
      if (mounted) showToast(context, 'Đã lưu tên hiển thị');
    } catch (e) {
      if (mounted) showToast(context, 'Không lưu được: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePassword() async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (result == null) return;

    setState(() => _busy = true);
    try {
      await _auth.changePassword(result.$1, result.$2);
      if (mounted) showToast(context, 'Đã đổi mật khẩu');
    } on AuthFailure catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    } catch (e) {
      if (mounted) showToast(context, 'Không đổi được mật khẩu: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount() async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (password == null) return;

    setState(() => _busy = true);
    try {
      await _auth.deleteAccount(password);
      if (!mounted) return;
      // Route gốc (AuthGate) đã tự đổi sang IntroScreen/OnboardingScreen
      // ngay khi authState về null, nhưng màn này là một route được `push`
      // nằm TRÊN route gốc đó - phải pop hết mới thấy được (giống bẫy
      // `popUntil` sau đăng nhập ở `login_screen.dart`).
      Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthFailure catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    } catch (e) {
      if (mounted) showToast(context, 'Không xoá được tài khoản: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;
    final account = user?.email == null
        ? '-'
        : AuthService.displayAccount(user!.email!);

    return Scaffold(
      appBar: AppBar(title: const Text('Thông tin tài khoản')),
      body: !_loaded
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                28 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Tài khoản đăng nhập'),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(
                            Icons.badge_outlined,
                            size: 20,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              account,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Mỗi cơ sở dùng một tài khoản riêng. Trong cơ sở không '
                        'có phân quyền, không có nhiều người dùng.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Tên hiển thị'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _displayName,
                        decoration: const InputDecoration(
                          hintText: 'Ví dụ: Chủ cơ sở',
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: _busy ? null : _saveName,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                        ),
                        child: const Text('Lưu tên hiển thị'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Bảo mật'),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _changePassword,
                        icon: const Icon(Icons.lock_reset_rounded, size: 20),
                        label: const Text('Đổi mật khẩu'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          minimumSize: const Size.fromHeight(46),
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Xoá tài khoản'),
                      const SizedBox(height: 6),
                      const Text(
                        'Tài khoản sẽ không đăng nhập lại được. Dữ liệu công '
                        'và lương của cơ sở vẫn được giữ lại - liên hệ hỗ trợ '
                        'nếu sau này cần khôi phục đăng nhập.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _deleteAccount,
                        icon: const Icon(
                          Icons.delete_forever_rounded,
                          size: 20,
                        ),
                        label: const Text('Xoá tài khoản'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.absent,
                          minimumSize: const Size.fromHeight(46),
                          side: const BorderSide(color: AppColors.absentSoft),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (_next.text.length < 6) {
      setState(() => _error = 'Mật khẩu mới phải có ít nhất 6 ký tự');
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _error = 'Xác nhận mật khẩu chưa khớp');
      return;
    }
    Navigator.of(context).pop((_current.text, _next.text));
  }

  @override
  Widget build(BuildContext context) {
    // `Dialog` thường (không phải `AlertDialog`): `AlertDialog` tự bọc nội
    // dung trong `IntrinsicWidth`, nên dù đặt `insetPadding` nhỏ, dialog vẫn
    // co lại theo đúng độ rộng nội dung rồi mới được `Align` ra giữa - phần
    // dư ra hai bên nhìn như margin lớn hơn cả `insetPadding` đã đặt. Dùng
    // `Dialog` trần + `CrossAxisAlignment.stretch` thì các ô nhập giãn đúng
    // hết chiều rộng còn lại, `insetPadding` mới là margin thật nhìn thấy.
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Đổi mật khẩu',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _current,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'Mật khẩu hiện tại',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _next,
                obscureText: true,
                decoration: const InputDecoration(hintText: 'Mật khẩu mới'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'Nhập lại mật khẩu mới',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.absent,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                    ),
                    child: const Text('Huỷ'),
                  ),
                  TextButton(onPressed: _submit, child: const Text('Đổi')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nhập mật khẩu hiện tại để xác nhận trước khi xoá tài khoản - Firebase bắt
/// buộc "recent login" cho thao tác nhạy cảm này (xem
/// `AuthService.deleteAccount`). Trả về mật khẩu đã nhập, hoặc `null` nếu bấm
/// Huỷ.
///
/// `Dialog` thường, không phải `AlertDialog`: `AlertDialog` tự bọc nội dung
/// trong `IntrinsicWidth` nên co hẹp lại bất kể `insetPadding` đặt bao nhiêu
/// - cùng lý do đã sửa ở `_ChangePasswordDialog`.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Vui lòng nhập mật khẩu hiện tại');
      return;
    }
    Navigator.of(context).pop(_password.text);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Xoá tài khoản',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Không thể hoàn tác - tài khoản sẽ không đăng nhập lại được. '
                'Dữ liệu công và lương vẫn được giữ lại.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                obscureText: true,
                autofocus: true,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  hintText: 'Nhập mật khẩu hiện tại để xác nhận',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.absent,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                    ),
                    child: const Text('Huỷ'),
                  ),
                  TextButton(
                    onPressed: _submit,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.absent,
                    ),
                    child: const Text('Xoá tài khoản'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
