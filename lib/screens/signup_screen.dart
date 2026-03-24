import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../widgets/interest_selection_sheet.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

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

  @override
  void dispose() {
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
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.red),
        );
        return;
      }

      setState(() => _isLoading = true);

      final authService = Provider.of<AuthService>(context, listen: false);
      final error = await authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        nickname: _nicknameController.text.trim(),
        nationality: _nationality!,
        age: int.tryParse(_ageController.text.trim()),
        phoneNumber: _phoneController.text.trim(),
        interests: _selectedInterests,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      } else {
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
                  items: const [
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
                        ? const Text('', style: TextStyle(fontSize: 16))
                        : Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children: _selectedInterests.map((interest) => Chip(
                              label: Text(interest, style: const TextStyle(fontSize: 12, color: Colors.white)),
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
                      : const Text('Sign Up', style: TextStyle(fontSize: 18)),
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
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : () async {
                    setState(() => _isLoading = true);
                    final authService = Provider.of<AuthService>(context, listen: false);
                    final error = await authService.signInWithGoogle();
                    if (!mounted) return;
                    setState(() => _isLoading = false);
                    if (error != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error), backgroundColor: Colors.red),
                      );
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  icon: Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1024px-Google_%22G%22_logo.svg.png',
                    height: 24,
                  ),
                  label: const Text(
                    'Google로 가입하기',
                    style: TextStyle(color: Colors.black87, fontSize: 16),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.grey.shade300),
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : () async {
                    setState(() => _isLoading = true);
                    final authService = Provider.of<AuthService>(context, listen: false);
                    final error = await authService.signInWithApple();
                    if (!mounted) return;
                    setState(() => _isLoading = false);
                    if (error != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error), backgroundColor: Colors.red),
                      );
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.apple, color: Colors.black, size: 28),
                  label: const Text(
                    'Apple로 가입하기',
                    style: TextStyle(color: Colors.black87, fontSize: 16),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.grey.shade300),
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
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
