import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../services/auth_service.dart';

class PhoneAuthScreen extends StatefulWidget {
  /// When `true`, the screen links the phone credential to the
  /// currently signed-in account instead of performing a standalone
  /// sign-in. Used by the JIT (Just-in-Time) verification flow.
  final bool linkMode;

  const PhoneAuthScreen({super.key, this.linkMode = false});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen>
    with SingleTickerProviderStateMixin {
  // Step 1: Phone number entry
  // Step 2: OTP verification
  // Step 3: Google account linking (standalone mode only)
  int _step = 1;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _isLoading = false;
  String _verificationId = '';
  String _verifiedSmsCode = '';
  String _selectedCountryCode = '+82'; // Korea default

  // Common country codes
  final List<Map<String, String>> _countryCodes = [
    {'code': '+1', 'name': 'US/CA'},
    {'code': '+44', 'name': 'UK'},
    {'code': '+62', 'name': 'ID'},
    {'code': '+60', 'name': 'MY'},
    {'code': '+63', 'name': 'PH'},
    {'code': '+65', 'name': 'SG'},
    {'code': '+66', 'name': 'TH'},
    {'code': '+82', 'name': 'KR'},
    {'code': '+81', 'name': 'JP'},
    {'code': '+86', 'name': 'CN'},
    {'code': '+91', 'name': 'IN'},
    {'code': '+61', 'name': 'AU'},
  ];

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty) {
      _showError('Please enter your phone number.');
      return;
    }

    final fullPhone = '$_selectedCountryCode$rawPhone';

    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      final onCodeSent = (String verificationId) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _step = 2;
          _isLoading = false;
        });
        _animController.reset();
        _animController.forward();
      };
      final onError = (String error) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showError(error);
      };
      final onAutoVerified = () {
        if (!mounted) return;
        setState(() => _isLoading = false);
        if (widget.linkMode) {
          _popWithSuccess();
        } else {
          // Auto-verified on mobile: go straight to Google linking.
          // The OTP was auto-read so we don't have it, but the phone
          // provider was already attached by verifyPhoneNumber's
          // verificationCompleted callback. _linkGoogle will handle it.
          setState(() => _step = 3);
          _animController.reset();
          _animController.forward();
        }
      };

      if (widget.linkMode) {
        await authService.sendPhoneVerificationForLink(
          phoneNumber: fullPhone,
          onCodeSent: onCodeSent,
          onError: onError,
          onAutoVerified: onAutoVerified,
        );
      } else {
        await authService.verifyPhoneNumber(
          phoneNumber: fullPhone,
          onCodeSent: onCodeSent,
          onError: onError,
          onAutoVerified: onAutoVerified,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e.toString());
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      _showError('Please enter the 6-digit verification code.');
      return;
    }

    if (widget.linkMode) {
      // JIT link mode: verify and link to current account
      setState(() => _isLoading = true);
      final authService = Provider.of<AuthService>(context, listen: false);
      final result = await authService.linkWithPhoneOtp(
        verificationId: _verificationId,
        smsCode: otp,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (!result.isSuccess) {
        _showError(result.errorMessage ?? 'Verification failed. Please try again.');
      } else {
        _popWithSuccess();
      }
    } else {
      // Standalone mode: try signing in with the phone credential.
      // If the resulting account already has Google linked (returning user),
      // skip step 3 and go straight to the main screen.
      setState(() => _isLoading = true);
      final authService = Provider.of<AuthService>(context, listen: false);
      final result = await authService.signInWithPhoneOtp(
        verificationId: _verificationId,
        smsCode: otp,
      );
      if (!mounted) return;

      if (result.isSuccess) {
        final user = firebase_auth.FirebaseAuth.instance.currentUser;
        final hasGoogle = user?.providerData
            .any((info) => info.providerId == 'google.com') ?? false;
        final hasEmail = (user?.email ?? '').isNotEmpty;

        if (hasGoogle || hasEmail) {
          // Existing account — go straight to main screen
          setState(() => _isLoading = false);
          Navigator.of(context, rootNavigator: true)
              .pushNamedAndRemoveUntil('/', (route) => false);
          return;
        }
      } else {
        // Phone sign-in failed (e.g. invalid code) — show error but
        // don't block; let user retry or proceed to Google linking
        if (result.errorCode == 'invalid-verification-code') {
          setState(() => _isLoading = false);
          _showError('Invalid verification code. Please try again.');
          return;
        }
      }

      // New user or sign-in issue — proceed to Google linking (step 3)
      setState(() => _isLoading = false);
      _verifiedSmsCode = otp;
      setState(() => _step = 3);
      _animController.reset();
      _animController.forward();
    }
  }

  Future<void> _linkGoogle() async {
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);

    final result = await authService.signInWithGoogleAndLinkPhone(
      verificationId: _verificationId,
      smsCode: _verifiedSmsCode,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.isSuccess) {
      _showError(result.errorMessage ?? 'Google linking failed.');
      return;
    }

    // Navigate to root — AuthWrapper picks up the auth state
    // and routes to onboarding or main screen.
    Navigator.of(context, rootNavigator: true)
        .pushNamedAndRemoveUntil('/', (route) => false);
  }

  /// Pops the screen, returning `true` to indicate success.
  /// Shows a success snackbar in linkMode.
  void _popWithSuccess() {
    if (widget.linkMode && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Phone verified successfully! ✅'),
          backgroundColor: Colors.green.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
    if (Navigator.canPop(context)) {
      Navigator.pop(context, widget.linkMode ? true : null);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _step == 3
            ? null
            : IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: Colors.black87,
                  size: 20,
                ),
                onPressed: () {
                  if (_step == 2) {
                    setState(() {
                      _step = 1;
                      _otpController.clear();
                    });
                    _animController.reset();
                    _animController.forward();
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // Step indicator
                Row(
                  children: [
                    _buildStepDot(1),
                    const SizedBox(width: 8),
                    _buildStepDot(2),
                    if (!widget.linkMode) ...[
                      const SizedBox(width: 8),
                      _buildStepDot(3),
                    ],
                  ],
                ),
                const SizedBox(height: 28),

                if (_step == 1) ...[
                  const Text(
                    'My phone\nnumber is',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We\'ll send you a verification code.',
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 36),

                  // Country code + phone number
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Country code dropdown
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCountryCode,
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.grey,
                            ),
                            style: const TextStyle(
                              fontSize: 18,
                              color: Color(0xFF1A1A2E),
                              fontWeight: FontWeight.w600,
                            ),
                            items: _countryCodes.map((c) {
                              return DropdownMenuItem(
                                value: c['code'],
                                child: Text(
                                  '${c['code']} ${c['name']}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedCountryCode = value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '|',
                          style: TextStyle(color: Colors.grey, fontSize: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.number,
                            enableSuggestions: false,
                            autocorrect: false,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A2E),
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: '10-digit number',
                              hintStyle: TextStyle(
                                color: Colors.grey,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Send OTP button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _sendOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ] else if (_step == 2) ...[
                  const Text(
                    'Enter the code\nwe sent you',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Code sent to $_selectedCountryCode ${_phoneController.text}',
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 36),

                  // OTP field
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                    ),
                    child: TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      enableSuggestions: false,
                      autocorrect: false,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: Color(0xFF1A1A2E),
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '000000',
                        hintStyle: TextStyle(
                          color: Colors.grey,
                          letterSpacing: 2,
                          fontSize: 32,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isLoading ? null : _sendOtp,
                    child: Text(
                      'Resend code',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        decoration: TextDecoration.underline,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const Spacer(),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'Verify',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ] else if (_step == 3) ...[
                  const Text(
                    'Link your\nGoogle account',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connect your Google account to complete sign-up.\nIf you already have a TEMAN account, it will be linked automatically.',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.5),
                  ),
                  const SizedBox(height: 48),

                  // Google sign-in button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _linkGoogle,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : Image.network(
                              'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                              width: 24,
                              height: 24,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, size: 28),
                            ),
                      label: const Text(
                        'Continue with Google',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),
                  const SizedBox(height: 32),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepDot(int step) {
    final isActive = _step >= step;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF2563EB) : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
