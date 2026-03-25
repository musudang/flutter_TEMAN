import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart' as app_models;

class AuthService extends ChangeNotifier {
  static const String _baseUrl = 'http://localhost:8080/users'; // Change to your backend URL
  static const String _tokenKey = 'jwt_token';

  String? _token;
  app_models.User? _currentUser;

  // Current User
  app_models.User? get currentUser => _currentUser;
  bool get isLoggedIn => _token != null;

  app_models.User _userFromMap(Map? userMap,
      {String fallbackName = '', String? fallbackEmail, String? fallbackAvatar}) {
    final map = (userMap is Map) ? userMap : <String, dynamic>{};
    return app_models.User(
      id: map['id']?.toString() ?? '',
      name: map['fullName'] ?? map['name'] ?? fallbackName,
      avatarUrl: map['avatarUrl'] ??
          fallbackAvatar ??
          'https://ui-avatars.com/api/?name=${Uri.encodeComponent(fallbackName)}&background=random',
      nickname: map['loginId'] ?? map['nickname'] ?? fallbackName,
      email: map['email'] ?? fallbackEmail ?? '',
      nationality: map['countryEnum'] ?? map['nationality'] ?? '',
    );
  }

  dynamic _safeDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  String _mapCountry(String nationality) {
    final n = nationality.toUpperCase();
    if (n.contains('USA')) return 'USA';
    if (n.contains('KOREA') || n.contains('KR')) return 'KOREA';
    if (n.contains('CHINA') || n.contains('CN')) return 'CHINA';
    if (n.contains('JAPAN') || n.contains('JP')) return 'JAPAN';
    if (n.contains('VIETNAM') || n.contains('VN')) return 'VIETNAM';
    return 'OTHER';
  }

  // Initialize token from storage
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    if (_token != null) {
      // Optionally fetch user info if needed
    }
    notifyListeners();
  }

  // Sign Up (Local)
  Future<String?> signUp({
    required String email,
    required String password,
    required String name,
    required String nickname,
    required String nationality,
    int? age,
    String phoneNumber = '',
    String personalInfo = '',
    List<String> interests = const [],
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'fullName': name,
          'loginId': nickname,
          'countryEnum': _mapCountry(nationality),
          'age': age,
          'phone': phoneNumber,
          'interests': interests,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.body.isNotEmpty ? _safeDecode(response.body) : null;
        _token = body is Map ? body['token'] : (body is String ? body : null);
        await _saveToken();
        final parsed = _userFromMap(body is Map ? body['user'] : null, fallbackName: name);
        _currentUser = app_models.User(
          id: parsed.id,
          name: parsed.name,
          avatarUrl: parsed.avatarUrl,
          nickname: parsed.nickname,
          email: parsed.email.isNotEmpty ? parsed.email : email,
          nationality: nationality.isNotEmpty ? nationality : parsed.nationality,
          bio: parsed.bio,
          role: parsed.role,
          createdAt: parsed.createdAt,
          age: age,
          personalInfo: personalInfo,
          phoneNumber: phoneNumber,
          interests: interests,
          instagramId: parsed.instagramId,
          followers: parsed.followers,
          following: parsed.following,
        );
        notifyListeners();
        return null;
      } else {
        final msg = _safeDecode(response.body);
        return msg is Map && msg['message'] != null ? msg['message'].toString() : 'Sign up failed (${response.statusCode})';
      }
    } catch (e) {
      return e.toString();
    }
  }

  // Sign In (Local)
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final body = response.body.isNotEmpty ? _safeDecode(response.body) : null;
        _token = body is Map ? body['token'] : (body is String ? body : null);
        await _saveToken();
        final parsed = _userFromMap(body is Map ? body['user'] : null, fallbackName: email.split('@').first);
        _currentUser = app_models.User(
          id: parsed.id.isNotEmpty ? parsed.id : 'me',
          name: parsed.name,
          avatarUrl: parsed.avatarUrl,
          nickname: parsed.nickname.isNotEmpty ? parsed.nickname : email.split('@').first,
          email: email,
          nationality: parsed.nationality,
        );
        notifyListeners();
        return null;
      } else {
        final msg = _safeDecode(response.body);
        return msg is Map && msg['message'] != null ? msg['message'].toString() : 'Sign in failed (${response.statusCode})';
      }
    } catch (e) {
      return e.toString();
    }
  }

  // Sign In with Google
  Future<SocialLoginResult> signInWithGoogle(
    String idToken, {
    String? displayName,
    String? email,
    String? photoUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login/social'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'provider': 'GOOGLE',
          'token': idToken,
        }),
      );

      final body = response.body.isNotEmpty ? _safeDecode(response.body) : null;

      if (response.statusCode == 200) {
        if (body is Map) {
          _token = body['accessToken'] ?? body['token'];
        } else if (body is String) {
          _token = body;
        }
        await _saveToken();
        final parsed = _userFromMap(
          body is Map ? body['user'] : null,
          fallbackName: displayName ?? 'Google User',
          fallbackEmail: email,
          fallbackAvatar: photoUrl,
        );
        _currentUser = parsed;
        notifyListeners();
        return SocialLoginResult(isNewUser: false);
      }

      if (response.statusCode == 202) {
        // 신규 사용자: 추가 정보 입력 필요
        return SocialLoginResult(
          isNewUser: true,
          email: body is Map ? body['email'] : null,
          socialId: body is Map ? body['socialId']?.toString() : null,
        );
      }

      final msg = body is Map && body['message'] != null ? body['message'].toString() : 'Google sign in failed';
      return SocialLoginResult(isNewUser: false, error: msg);
    } catch (e) {
      return SocialLoginResult(isNewUser: false, error: e.toString());
    }
  }

  Future<String?> socialSignup({
    required String email,
    required String socialId,
    required String provider,
    required String loginId,
    required String fullName,
    int? age,
    required String countryEnum,
    String phone = '',
    List<String> interests = const [],
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/signup/social'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'socialId': socialId,
          'provider': provider,
          'loginId': loginId,
          'fullName': fullName,
          'age': age,
          'countryEnum': _mapCountry(countryEnum),
          'phone': phone,
          'interests': interests,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return null;
      }
      final msg = _safeDecode(response.body);
      return msg is Map && msg['message'] != null ? msg['message'].toString() : 'Social sign up failed (${response.statusCode})';
    } catch (e) {
      return e.toString();
    }
  }

  // Sign In with Apple
  Future<String?> signInWithApple(String identityToken) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login/social'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'provider': 'APPLE',
          'token': identityToken,
        }),
      );

      if (response.statusCode == 200) {
        final body = _safeDecode(response.body);
        _token = body is Map ? body['token'] : (body is String ? body : null);
        await _saveToken();
        final parsed = _userFromMap(body is Map ? body['user'] : null, fallbackName: 'Apple User');
        _currentUser = parsed;
        notifyListeners();
        return null;
      } else {
        final msg = _safeDecode(response.body);
        return msg is Map && msg['message'] != null ? msg['message'].toString() : 'Apple sign in failed';
      }
    } catch (e) {
      return e.toString();
    }
  }

  // Sign Out
  Future<void> signOut() async {
    _token = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    notifyListeners();
  }

  // Send Password Reset Email
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/password/reset-link'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        return null;
      } else {
        return jsonDecode(response.body)['message'] ?? 'Failed to send reset email';
      }
    } catch (e) {
      return e.toString();
    }
  }

  // Reset Password with token from link
  Future<String?> resetPassword(String token, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/password/reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token, 'newPassword': newPassword}),
      );

      if (response.statusCode == 200) {
        return null;
      } else {
        return jsonDecode(response.body)['message'] ?? 'Failed to reset password';
      }
    } catch (e) {
      return e.toString();
    }
  }

  // Helper to save token
  Future<void> _saveToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) {
      await prefs.setString(_tokenKey, _token!);
    }
  }

  // Get auth headers
  Map<String, String> get authHeaders => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };
}

class SocialLoginResult {
  final bool isNewUser;
  final String? email;
  final String? socialId;
  final String? error;

  SocialLoginResult({required this.isNewUser, this.email, this.socialId, this.error});

  bool get hasError => error != null;
}
