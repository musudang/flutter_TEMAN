import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Step 5 — Verification (Phone or Email based on what is missing)
// ──────────────────────────────────────────────────────────────────────────────
class VerificationStep extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const VerificationStep({required this.onNext, required this.onBack, super.key});

  @override
  State<VerificationStep> createState() => _VerificationStepState();
}

class _VerificationStepState extends State<VerificationStep> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthService>(context, listen: false);
      final user = auth.currentUser;
      final hasEmail = user?.email != null && user!.email!.isNotEmpty;

      // Decoupled phone verification: Only check for email
      if (hasEmail) {
        widget.onNext();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;
    final hasEmail = user?.email != null && user!.email!.isNotEmpty;

    if (!hasEmail) {
      return EmailVerificationStep(onNext: widget.onNext, onBack: widget.onBack);
    } else {
      return const SizedBox.shrink(); // Moving to next step automatically
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// PhoneVerificationStep
// ──────────────────────────────────────────────────────────────────────────────
class PhoneVerificationStep extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const PhoneVerificationStep({required this.onNext, required this.onBack, super.key});

  @override
  State<PhoneVerificationStep> createState() => _PhoneVerificationStepState();
}

class _PhoneVerificationStepState extends State<PhoneVerificationStep> {
  int _step = 1;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _isLoading = false;
  String _verificationId = '';
  String _selectedCountryCode = '+82';

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

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
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
      await authService.sendPhoneVerificationForLink(
        phoneNumber: fullPhone,
        onCodeSent: (verificationId) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _step = 2;
            _isLoading = false;
          });
        },
        onError: (error) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          _showError(error);
        },
        onAutoVerified: () {
          if (!mounted) return;
          setState(() => _isLoading = false);
          widget.onNext();
        },
      );
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
      widget.onNext();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 0, 0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
            onPressed: () {
              if (_step == 2) {
                setState(() {
                  _step = 1;
                  _otpController.clear();
                });
              } else {
                widget.onBack();
              }
            },
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                if (_step == 1) ...[
                  const Text(
                    'Verify your\nphone number',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'To keep TEMAN safe, phone verification is required for all users.',
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 36),

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
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCountryCode,
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
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
                        const Text('|', style: TextStyle(color: Colors.grey, fontSize: 22)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A2E),
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Phone number',
                              hintStyle: TextStyle(color: Colors.grey, fontSize: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
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
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : (_step == 1 ? _sendOtp : _verifyOtp),
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
                  : Text(
                      _step == 1 ? 'Send Code' : 'Verify',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// EmailVerificationStep
// ──────────────────────────────────────────────────────────────────────────────
class EmailVerificationStep extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const EmailVerificationStep({required this.onNext, required this.onBack, super.key});

  @override
  State<EmailVerificationStep> createState() => _EmailVerificationStepState();
}

class _EmailVerificationStepState extends State<EmailVerificationStep> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isWaitingForVerification = false;
  Timer? _pollingTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _linkEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showError('Please enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      _showError('Password must be at least 6 characters long.');
      return;
    }

    setState(() => _isLoading = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    final result = await auth.linkWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A verification email has been sent. Please check your inbox.'),
          backgroundColor: Colors.green,
        ),
      );
      
      setState(() {
        _isWaitingForVerification = true;
      });
      _startPollingVerification();

    } else {
      _showError(result.errorMessage ?? 'Failed to link email. Please try again.');
    }
  }

  void _startPollingVerification() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      if (user != null) {
        // We need the underlying FirebaseAuth user to call reload()
        final fbUser = FirebaseAuth.instance.currentUser;
        if (fbUser != null) {
          await fbUser.reload();
          if (fbUser.emailVerified) {
            timer.cancel();
            if (mounted) {
              widget.onNext();
            }
          }
        }
      }
    });
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
    if (_isWaitingForVerification) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.mark_email_unread_outlined, size: 80, color: Color(0xFF2563EB)),
          const SizedBox(height: 24),
          const Text(
            'Check your email',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              'We sent a verification link to\n${_emailController.text}\n\nPlease click the link to verify your email. If you don\'t see it, please check your spam or junk folder. This screen will automatically update once verified.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600, height: 1.5),
            ),
          ),
          const SizedBox(height: 48),
          const CircularProgressIndicator(color: Color(0xFF2563EB)),
          const SizedBox(height: 48),
          TextButton(
            onPressed: () async {
              final fbUser = FirebaseAuth.instance.currentUser;
              if (fbUser != null) {
                await fbUser.sendEmailVerification();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Verification email resent.')),
                );
              }
            },
            child: Text(
              'Resend Email',
              style: TextStyle(color: Colors.grey.shade600, decoration: TextDecoration.underline),
            ),
          )
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 0, 0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
            onPressed: widget.onBack,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'Link your\nemail address',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Since you registered with a phone number, please link an email and password to secure your account and allow future login options.',
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 36),

                  // Email Input
                  const Text(
                    'Email Address',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'name@example.com',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Password Input
                  const Text(
                    'Set Password',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'At least 6 characters',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _linkEmail,
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
                      'Verify & Continue',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

