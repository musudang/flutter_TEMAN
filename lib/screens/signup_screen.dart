import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../widgets/interest_selection_sheet.dart';
import '../widgets/google_web_button.dart';
import '../services/google_sign_in_client.dart';
import 'dart:async';
import 'main_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({
    super.key,
    this.prefilledEmail,
    this.socialId,
    this.provider,
  });

  final String? prefilledEmail;
  final String? socialId;
  final String? provider;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  List<String> _selectedInterests = [];
  String? _nationality;
  bool _isLoading = false;
  late final GoogleSignIn _googleSignIn = googleSignIn;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSub;
  // navigation helpers
  void _gotoHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
      (_) => false,
    );
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

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<void> _onAuthEvent(GoogleSignInAuthenticationEvent event) async {
    if (!mounted) return;
    if (event is! GoogleSignInAuthenticationEventSignIn) return;

    debugPrint('[GoogleSignup] authenticationEvents -> sign-in event 수신');
    setState(() => _isLoading = true);

    final idToken = event.user.authentication.idToken;
    debugPrint('[GoogleSignup] event idToken=${idToken?.substring(0, idToken.length > 20 ? 20 : idToken.length) ?? 'null'}');

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

    debugPrint('[GoogleSignup] 이벤트 기반 서버 응답 isNewUser=${result.isNewUser}, hasError=${result.hasError}, error=${result.error}');
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

  bool get _isSocialSignup => widget.socialId != null && widget.provider != null;

  @override
  void initState() {
    super.initState();
    ensureGoogleSignInInitialized();
    if (kIsWeb) {
      _authSub = _googleSignIn.authenticationEvents.listen(
        _onAuthEvent,
        onError: (err) => debugPrint('[GoogleSignup] web auth event error: $err'),
      );
    }
    if (widget.prefilledEmail != null) {
      _emailController.text = widget.prefilledEmail!;
    }
  }

  Future<void> _handleGoogleSignup() async {
    debugPrint('[GoogleSignup] _handleGoogleSignup 시작');
    setState(() => _isLoading = true);
    try {
      debugPrint('[GoogleSignup] initialize 호출');
      await ensureGoogleSignInInitialized();

      if (kIsWeb) {
        debugPrint('[GoogleSignup] 웹에서는 renderButton을 사용하십시오. 플러그인 버튼을 눌러주세요.');
        setState(() => _isLoading = false);
        return;
      }

      debugPrint('[GoogleSignup] authenticate 호출');
      final account = await _googleSignIn.authenticate();
      debugPrint('[GoogleSignup] authenticate 완료, account=$account');

      final idToken = account.authentication.idToken;
      final idTokenShort = idToken == null
          ? 'null'
          : (idToken.length <= 20 ? idToken : '${idToken.substring(0, 20)}...');
      debugPrint('[GoogleSignup] 얻은 idToken=$idTokenShort');

      if (idToken == null || idToken.isEmpty) {
        setState(() => _isLoading = false);
        _showError('Google ID 토큰을 가져오지 못했습니다.');
        return;
      }
      final authService = Provider.of<AuthService>(context, listen: false);
      debugPrint('[GoogleSignup] backend signInWithGoogle 호출 - email=${account.email}');
      final result = await authService.signInWithGoogle(
        idToken,
        displayName: account.displayName,
        email: account.email,
        photoUrl: account.photoUrl,
      );
      debugPrint('[GoogleSignup] 서버 응답 isNewUser=${result.isNewUser}, hasError=${result.hasError}, error=${result.error}');
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
      debugPrint('[GoogleSignup] 예외 발생: $e');
      setState(() => _isLoading = false);
      _showError('Google 로그인 오류: $e');
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _nameController.dispose();
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      if (!_isSocialSignup) {
        if (_passwordController.text != _confirmPasswordController.text) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.red),
          );
          return;
        }
      }

      if (_nationality == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your country'), backgroundColor: Colors.red),
        );
        return;
      }

      setState(() => _isLoading = true);

      final authService = Provider.of<AuthService>(context, listen: false);
      String? error;

      if (_isSocialSignup) {
        error = await authService.socialSignup(
          email: _emailController.text.trim(),
          socialId: widget.socialId!,
          provider: (widget.provider ?? 'GOOGLE').toUpperCase(),
          loginId: _nicknameController.text.trim(),
          fullName: _nameController.text.trim(),
          age: int.tryParse(_ageController.text.trim()),
          countryEnum: _nationality!,
          phone: _phoneController.text.trim(),
          interests: _selectedInterests,
        );
      } else {
        error = await authService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          name: _nameController.text.trim(),
          nickname: _nicknameController.text.trim(),
          nationality: _nationality!,
          age: int.tryParse(_ageController.text.trim()),
          phoneNumber: _phoneController.text.trim(),
          interests: _selectedInterests,
        );
      }

      setState(() => _isLoading = false);

      if (error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      } else if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.person_add, size: 80, color: Colors.teal),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter your name'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nicknameController,
                  decoration: const InputDecoration(
                    labelText: 'Nickname / ID',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter a nickname/ID'
                      : null,
                ),
                const SizedBox(height: 16),
                if (!_isSocialSignup) ...[
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
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: (value) => value == null || value.isEmpty
                        ? 'Please confirm your password'
                        : null,
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _ageController,
                  decoration: const InputDecoration(
                    labelText: 'Age',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final age = int.tryParse(value);
                      if (age == null || age < 1 || age > 150) {
                        return 'Enter a valid age';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Nationality',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.flag),
                  ),
                  items: [
                    DropdownMenuItem(value: 'USA 🇺🇸', child: Text('USA 🇺🇸')),
                    DropdownMenuItem(value: 'Korea 🇰🇷', child: Text('Korea 🇰🇷')),
                    DropdownMenuItem(value: 'China 🇨🇳', child: Text('China 🇨🇳')),
                    DropdownMenuItem(value: 'Japan 🇯🇵', child: Text('Japan 🇯🇵')),
                    DropdownMenuItem(value: 'Vietnam 🇻🇳', child: Text('Vietnam 🇻🇳')),
                    DropdownMenuItem(value: 'Other 🌏', child: Text('Other 🌏')),
                  ],
                  onChanged: (val) => _nationality = val,
                  validator: (val) => val == null ? 'Select nationality' : null,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    FocusScope.of(context).unfocus(); // Dismiss keyboard if open
                    final List<String>? result = await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => InterestSelectionSheet(
                        initialInterests: _selectedInterests,
                        maxSelections: 5,
                      ),
                    );
                    if (result != null) {
                      setState(() {
                        _selectedInterests = result;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: _selectedInterests.isEmpty ? 'Interests' : 'Interests (${_selectedInterests.length}/5)',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.favorite_border),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    isEmpty: _selectedInterests.isEmpty,
                    child: _selectedInterests.isEmpty
                        ? Text('', style: TextStyle(fontSize: 16))
                        : Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children: _selectedInterests.map((interest) => Chip(
                              label: Text(interest, style: TextStyle(fontSize: 12, color: Colors.white)),
                              backgroundColor: Colors.red.shade400,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: Colors.transparent)
                              ),
                            )).toList(),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  readOnly: _isSocialSignup,
                  validator: (value) => value == null || !value.contains('@')
                      ? 'Enter a valid email'
                      : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('Sign Up', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 32),
                if (!_isSocialSignup) ...[
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
                      label: '구글 계정으로 가입',
                      icon: Icons.g_mobiledata,
                      onPressed: _isLoading ? null : _handleGoogleSignup,
                    ),
                    const SizedBox(height: 16),
                  ],
                  // SocialButton(
                  //   label: 'Apple로 가입하기',
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
                ],
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    children: [
                      const TextSpan(text: '회원가입 시 '),
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

  const SocialButton({super.key, required this.label, required this.icon, required this.onPressed});

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
