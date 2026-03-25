import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? token;

  const ResetPasswordScreen({super.key, this.token});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _token;
  String? _message;

  @override
  void initState() {
    super.initState();
    _token = widget.token;
    // URL 쿼리파라미터가 제공된 경우에 token을 우선.
    final queryToken = Uri.base.queryParameters['token'];
    if (queryToken != null && queryToken.isNotEmpty) {
      _token = queryToken;
    }

    if (_token == null || _token!.isEmpty) {
      _message = '토큰이 필요합니다. URL에 token 파라미터를 확인해주세요.';
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_token == null || _token!.isEmpty) {
      setState(() => _message = 'token 값이 없습니다. 링크를 다시 확인하세요.');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    final auth = Provider.of<AuthService>(context, listen: false);
    final error = await auth.resetPassword(_token!, _passwordController.text.trim());

    setState(() => _isLoading = false);

    if (error != null) {
      setState(() => _message = error);
    } else {
      setState(() => _message = '비밀번호가 재설정되었습니다. 로그인 페이지로 이동합니다.');
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_message != null) ...[
                Text(_message!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
              ],
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'New Password'),
                      obscureText: true,
                      validator: (value) => value == null || value.length < 6
                          ? '비밀번호는 6자 이상이어야 합니다.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: const InputDecoration(labelText: 'Confirm Password'),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '비밀번호 확인을 입력하세요.';
                        }
                        if (value != _passwordController.text) {
                          return '비밀번호가 일치하지 않습니다.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Reset Password'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
