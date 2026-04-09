import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'package:flutter/foundation.dart'; // kIsWeb을 사용하기 위해 추가

import 'firebase_options.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/firestore_service.dart';
import 'services/auth_service.dart';
import 'models/auth_result.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Activate App Check (웹을 제외한 모바일에서만 실행되도록 분기 처리)
  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      // appleProvider: AppleProvider.appAttest, // iOS 세팅 완료 시 주석 해제
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FirestoreService()),
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'TEMAN Community',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E56C8),
            secondary: Colors.orangeAccent,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF8F9FA),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            centerTitle: true,
            titleTextStyle: TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            iconTheme: IconThemeData(color: Colors.black87),
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// AuthWrapper: routes to Login, Onboarding, or MainScreen
// ──────────────────────────────────────────────────────────────────────────────
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return StreamBuilder<AuthUser?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // While waiting for auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        final AuthUser? user = snapshot.data;

        // Not logged in → Login screen
        if (user == null) {
          return const LoginScreen();
        }

        // Logged in → check if onboarding is complete
        return FutureBuilder<bool>(
          future: authService.isNewUser(),
          builder: (context, onboardingSnapshot) {
            if (onboardingSnapshot.connectionState == ConnectionState.waiting) {
              return const _SplashScreen();
            }
            final needsOnboarding = onboardingSnapshot.data ?? false;
            if (needsOnboarding) {
              return const OnboardingScreen();
            }
            return const MainScreen();
          },
        );
      },
    );
  }
}

// Simple splash while checking auth state
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Color(0xFF1E56C8)),
          strokeWidth: 3,
        ),
      ),
    );
  }
}
