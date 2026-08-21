// ログイン画面。メールアドレスとパスワードでのログイン / 新規登録を行う。
// 1画面でモードを切り替える（新規登録時はパスワード確認欄を表示）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_errors.dart';
import 'auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  // true: 新規登録モード / false: ログインモード
  bool _isSignUp = false;
  // パスワードを伏せ字にするか（目のアイコンで切替）。
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ログイン/新規登録を切り替える。入力中の確認欄はクリアする。
  void _toggleMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _confirmController.clear();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final controller = ref.read(authControllerProvider.notifier);

    if (_isSignUp) {
      await controller.signUpWithEmail(email, password);
    } else {
      await controller.signInWithEmail(email, password);
    }

    if (!mounted) return;
    // エラーは ref.listen 側でSnackBar表示する。
    if (ref.read(authControllerProvider).hasError) return;

    // メール確認は使わない設定なので、成功すれば即セッションが張られる。
    // スプラッシュで「プロフィール未登録→/profile/setup / 登録済み→/home」を振り分ける。
    context.go('/splash');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    ref.listen(authControllerProvider, (prev, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authErrorMessage(next.error!))),
        );
      }
    });

    final fieldRadius = BorderRadius.circular(14);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F1FB),
      appBar: AppBar(
        title: Text(_isSignUp ? '新規登録' : 'ログイン'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _LoginHeader(),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'メールアドレス',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: fieldRadius,
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'メールアドレスを入力してください'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'パスワード',
                      helperText: '6文字以上',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: fieldRadius,
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        tooltip: _obscurePassword ? '表示' : '非表示',
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'パスワードは6文字以上で入力してください'
                        : null,
                  ),
                  // 新規登録時のみ、入力ミス防止のためパスワード確認欄を表示。
                  if (_isSignUp) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'パスワード（確認）',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: fieldRadius,
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (v) => (v != _passwordController.text)
                          ? 'パスワードが一致しません'
                          : null,
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C5CE7),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: isLoading ? null : _submit,
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isSignUp ? '新規登録' : 'ログイン',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                  TextButton(
                    onPressed: isLoading ? null : _toggleMode,
                    child: Text(
                      _isSignUp ? 'アカウントをお持ちの方はログイン' : 'アカウントが無い方は新規登録',
                      style: const TextStyle(color: Color(0xFF6C5CE7)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ログイン画面上部のブランドヘッダー。アプリ名とひとことを表示する。
class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: const BoxDecoration(
            color: Color(0xFF6C5CE7),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.video_camera_front_rounded,
            size: 44,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Hanalog',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF6C5CE7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'グループで動画を共有しよう',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      ],
    );
  }
}
