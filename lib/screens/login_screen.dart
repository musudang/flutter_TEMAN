import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/google_sign_in_client.dart';
import '../widgets/google_web_button.dart';
import 'dart:async';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  late final GoogleSignIn _googleSignIn = googleSignIn;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSub;

  @override
  void initState() {
    super.initState();
    ensureGoogleSignInInitialized();
    if (kIsWeb) {
      _authSub = _googleSignIn.authenticationEvents.listen(
        _onAuthEvent,
        onError: (err) => debugPrint('[GoogleLogin] web auth event error: $err'),
      );
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleLogin() async {
    debugPrint('[GoogleLogin] _handleGoogleLogin 시작');
    setState(() => _isLoading = true);
    try {
      debugPrint('[GoogleLogin] initialize 호출');
      await ensureGoogleSignInInitialized();

      if (kIsWeb) {
        debugPrint('[GoogleLogin] 웹에서는 renderButton을 사용하십시오. 플러그인 버튼을 눌러주세요.');
        // 웹에서 authenticate는 지원되지 않으므로, UI는 renderButton을 통해 처리됩니다.
        setState(() => _isLoading = false);
        return;
      }

      debugPrint('[GoogleLogin] authenticate 호출');
      final account = await _googleSignIn.authenticate();
      debugPrint('[GoogleLogin] authenticate 완료, account=$account');

      final idToken = account.authentication.idToken;
      final idTokenShort = idToken == null
          ? 'null'
          : (idToken.length <= 20 ? idToken : '${idToken.substring(0, 20)}...');
      debugPrint('[GoogleLogin] 얻은 idToken=$idTokenShort');

      if (idToken == null || idToken.isEmpty) {
        setState(() => _isLoading = false);
        _showError('Google ID 토큰을 가져오지 못했습니다.');
        return;
      }
      final authService = Provider.of<AuthService>(context, listen: false);
      debugPrint('[GoogleLogin] backend signInWithGoogle 호출 - email=${account.email}');
      final result = await authService.signInWithGoogle(
        idToken,
        displayName: account.displayName,
        email: account.email,
        photoUrl: account.photoUrl,
      );
      debugPrint('[GoogleLogin] 서버 응답 isNewUser=${result.isNewUser}, hasError=${result.hasError}, error=${result.error}');
      setState(() => _isLoading = false);
      if (result.hasError) {
        _showError(result.error!);
        return;
      }
      if (result.isNewUser) {
        _gotoSocialSignup(result);
        return;
      }
      _gotoHome();
    } catch (e) {
      debugPrint('[GoogleLogin] 예외 발생: $e');
      setState(() => _isLoading = false);
      _showError('Google 로그인 오류: $e');
    }
  }

  void _gotoSocialSignup(SocialLoginResult result) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SignupScreen(
          prefilledEmail: result.email ?? '',
          socialId: result.socialId ?? '',
          provider: 'GOOGLE',
        ),
      ),
    );
  }

  Future<void> _onAuthEvent(GoogleSignInAuthenticationEvent event) async {
    if (!mounted) return;
    if (event is! GoogleSignInAuthenticationEventSignIn) return;

    debugPrint('[GoogleLogin] authenticationEvents -> sign-in event 수신');
    setState(() => _isLoading = true);

    final idToken = event.user.authentication.idToken;
    debugPrint('[GoogleLogin] event idToken=${idToken?.substring(0, idToken.length > 20 ? 20 : idToken.length) ?? 'null'}');

    if (idToken == null || idToken.isEmpty) {
      setState(() => _isLoading = false);
      _showError('Google ID 토큰을 가져오지 못했습니다.');
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final result = await authService.signInWithGoogle(
      idToken,
      displayName: event.user.displayName,
      email: event.user.email,
      photoUrl: event.user.photoUrl,
    );

    debugPrint('[GoogleLogin] 이벤트 기반 서버 응답 isNewUser=${result.isNewUser}, hasError=${result.hasError}, error=${result.error}');
    setState(() => _isLoading = false);

    if (result.hasError) {
      _showError(result.error!);
      return;
    }

    if (result.isNewUser) {
      _gotoSocialSignup(result);
      return;
    }

    _gotoHome();
  }

  void _gotoHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
      (_) => false,
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final authService = Provider.of<AuthService>(context, listen: false);
      final error = await authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      setState(() => _isLoading = false);

      if (error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
      // Navigation is handled by authStateChanges stream in main.dart
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.people_alt, size: 80, color: Colors.teal),
                const SizedBox(height: 16),
                const Text(
                  'Welcome Back',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => value == null || !value.contains('@')
                      ? 'Enter a valid email'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: (value) => value == null || value.length < 6
                      ? 'Password must be at least 6 chars'
                      : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Login', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Don\'t have an account? '),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignupScreen(),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Sign Up'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    '비밀번호를 잊으셨나요?',
                    style: TextStyle(color: Colors.grey, decoration: TextDecoration.underline),
                  ),
                ),
                const SizedBox(height: 32),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OR', style: TextStyle(color: Colors.grey)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 32),
                if (kIsWeb) ...[
                  buildGoogleWebButton(height: 56),
                  const SizedBox(height: 16),
                ] else ...[
                  SocialButton(
                    label: '구글 계정으로 로그인',
                    icon: Icons.g_mobiledata,
                    onPressed: _isLoading ? null : _handleGoogleLogin,
                  ),
                  const SizedBox(height: 16),
                ],
                // SocialButton(
                //   label: 'Apple로 로그인',
                //   icon: Icons.apple,
                //   onPressed: _isLoading
                //       ? null
                //       : () async {
                //           setState(() => _isLoading = true);
                //           final authService = Provider.of<AuthService>(context, listen: false);
                //           final error = await authService.signInWithApple('dummy-token');
                //           setState(() => _isLoading = false);
                //           if (error != null && mounted) {
                //             _showError(error);
                //           } else if (mounted) {
                //             _gotoHome();
                //           }
                //         },
                // ),
                const SizedBox(height: 32),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    children: [
                      const TextSpan(text: '로그인 시 '),
                      TextSpan(
                        text: '이용약관',
                        style: const TextStyle(
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.bold,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () async {
                            final url = Uri.parse(
                                'https://iris-tank-0cf.notion.site/321d16a0171980d397d0dd8ef1132ffb?source=copy_link');
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url);
                            }
                          },
                      ),
                      const TextSpan(text: ' 및 '),
                      TextSpan(
                        text: '개인정보 처리방침',
                        style: const TextStyle(
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.bold,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () async {
                            final url = Uri.parse(
                                'https://iris-tank-0cf.notion.site/323d16a01719803d9b36e3c058c95057?source=copy_link');
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url);
                            }
                          },
                      ),
                      const TextSpan(text: '에 동의합니다'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const SocialButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.black87, size: 22),
      label: Text(label, style: const TextStyle(color: Colors.black87, fontSize: 16)),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(color: Colors.grey.shade300),
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),
    );
  }
}
