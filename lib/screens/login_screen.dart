import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../widgets/teman_logo.dart';
import 'phone_auth_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;

  late AnimationController _animController;
  late Animation<double> _logoFade;
  late Animation<Offset> _buttonSlide;

  // TEMAN brand color (blue)
  static const Color _temanBlue = Color(0xFF1E56C8);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoFade = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _buttonSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
          ),
        );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final result = await authService.signInWithGoogle();
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.isSuccess) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.errorMessage ?? 'Google sign-in failed. Please try again.',
          ),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _navigateToPhoneAuth() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Column(
              children: [
                // ── Top logo area ──
                Expanded(
                  child: FadeTransition(
                    opacity: _logoFade,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo icon
                          TemanLogoWidget(size: screenHeight * 0.13),
                          const SizedBox(height: 20),
                          // TEMAN text
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFF1E56C8), Color(0xFF38BDF8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: const Text(
                              'TEMAN',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                color: Colors.white, // masked by shader
                                letterSpacing: 6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Connect · Discover · Explore',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Bottom area: buttons + terms ──
                SlideTransition(
                  position: _buttonSlide,
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _animController,
                      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Terms text
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12.5,
                                height: 1.6,
                              ),
                              children: [
                                const TextSpan(
                                  text:
                                      'By tapping "Continue", you agree to our ',
                                ),
                                TextSpan(
                                  text: 'Terms of Service',
                                  style: const TextStyle(
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E56C8),
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () async {
                                      final url = Uri.parse(
                                        'https://iris-tank-0cf.notion.site/321d16a0171980d397d0dd8ef1132ffb?source=copy_link',
                                      );
                                      if (await canLaunchUrl(url)) {
                                        await launchUrl(url);
                                      }
                                    },
                                ),
                                const TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: const TextStyle(
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E56C8),
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () async {
                                      final url = Uri.parse(
                                        'https://iris-tank-0cf.notion.site/323d16a01719803d9b36e3c058c95057?source=copy_link',
                                      );
                                      if (await canLaunchUrl(url)) {
                                        await launchUrl(url);
                                      }
                                    },
                                ),
                                const TextSpan(text: '.'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── Google button ──
                          _AuthButton(
                            onPressed: _isLoading ? null : _loginWithGoogle,
                            isLoading: _isLoading,
                            icon: _GoogleIcon(),
                            label: 'Continue with Google',
                            backgroundColor: Colors.white,
                            textColor: const Color(0xFF1A1A2E),
                            borderColor: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),

                          // ── Phone button ──
                          _AuthButton(
                            onPressed: _isLoading ? null : _navigateToPhoneAuth,
                            icon: const Icon(
                              Icons.phone,
                              color: Colors.white,
                              size: 22,
                            ),
                            label: 'Continue with Phone',
                            backgroundColor: _temanBlue,
                            textColor: Colors.white,
                            borderColor: Colors.transparent,
                          ),

                          const SizedBox(height: 20),

                          // ── Having trouble? ──
                          Center(
                            child: TextButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title: const Text(
                                      'Having trouble logging in?',
                                    ),
                                    content: const Text(
                                      'If you\'re experiencing issues, please try:\n\n'
                                      '• Check your internet connection\n'
                                      '• Make sure you\'re using the correct account\n'
                                      '• Contact support at support@teman.app',
                                    ),
                                    actions: [
                                      TextButton(
                                        child: const Text('OK'),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Text(
                                'Having trouble logging in?',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Loading overlay
            if (_isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.08),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Color(0xFF1E56C8)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Auth Button Widget ──
class _AuthButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
  final bool isLoading;

  const _AuthButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
    this.isLoading = false,
  });

  @override
  State<_AuthButton> createState() => _AuthButtonState();
}

class _AuthButtonState extends State<_AuthButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 56,
          decoration: BoxDecoration(
            color: _pressed
                ? widget.backgroundColor.withValues(alpha: 0.85)
                : widget.backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: widget.borderColor, width: 1.5),
            boxShadow: widget.backgroundColor == Colors.white
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: const Color(0xFF1E56C8).withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              widget.icon,
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Google "G" Icon ──
class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Blue segment
    canvas.drawArc(
      rect,
      -0.52,
      1.57,
      true,
      Paint()..color = const Color(0xFF4285F4),
    );
    // Red segment
    canvas.drawArc(
      rect,
      1.05,
      1.57,
      true,
      Paint()..color = const Color(0xFFEA4335),
    );
    // Yellow segment
    canvas.drawArc(
      rect,
      2.62,
      0.79,
      true,
      Paint()..color = const Color(0xFFFBBC05),
    );
    // Green segment
    canvas.drawArc(
      rect,
      3.41,
      0.79,
      true,
      Paint()..color = const Color(0xFF34A853),
    );
    // White center
    canvas.drawCircle(center, radius * 0.58, Paint()..color = Colors.white);

    // "G" letter simplified - horizontal bar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = size.height * 0.15
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(center.dx + radius * 0.55, center.dy),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
