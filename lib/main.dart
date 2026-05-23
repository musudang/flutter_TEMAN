import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter/foundation.dart'; // kIsWeb을 사용하기 위해 추가
import 'package:kakao_map_plugin/kakao_map_plugin.dart';

import 'firebase_options.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/eula_screen.dart';
import 'services/firestore_service.dart';
import 'services/auth_service.dart';
import 'models/auth_result.dart';
import 'providers/feed_state_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Initialize Kakao Map Plugin with JavaScript Key
  AuthRepository.initialize(appKey: 'a6e36ae0b5f7259156d9c7dd2b9fc113');
  
  // Pass all uncaught errors to Crashlytics (not supported on Web)
  if (!kIsWeb) {
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // Activate App Check (웹을 제외한 모바일에서만 실행되도록 분기 처리)
  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode ? AndroidDebugProvider() : AndroidPlayIntegrityProvider(),
      // providerApple: AppleAppAttestProvider(), // iOS 세팅 완료 시 주석 해제
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(analytics: analytics);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FirestoreService()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => FeedStateProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'TEMAN Community',
        navigatorObservers: [observer],
        theme: ThemeData(
          textTheme: GoogleFonts.notoSansKrTextTheme(
            Theme.of(context).textTheme,
          ),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E56C8),
            secondary: Colors.orangeAccent,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF8F9FA),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            centerTitle: true,
            titleTextStyle: GoogleFonts.notoSansKr(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            iconTheme: const IconThemeData(color: Colors.black87),
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

  /// Check if the user has accepted the EULA
  static Future<bool> _hasAcceptedEula(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!doc.exists) return false;
      final data = doc.data();
      return data?['eulaAcceptedAt'] != null;
    } catch (_) {
      return false;
    }
  }

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

        // Logged in → check if onboarding is complete, then EULA
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

            // [NEW] Check if EULA has been accepted
            return FutureBuilder<bool>(
              future: _hasAcceptedEula(user.uid),
              builder: (context, eulaSnapshot) {
                if (eulaSnapshot.connectionState == ConnectionState.waiting) {
                  return const _SplashScreen();
                }
                final eulaAccepted = eulaSnapshot.data ?? false;
                if (!eulaAccepted) {
                  return const EulaScreen();
                }
                return const MainScreen();
              },
            );
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
