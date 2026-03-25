import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';
import 'screens/reset_password_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/google_sign_in_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensureGoogleSignInInitialized();
  final authService = AuthService();
  await authService.init();
  final apiService = ApiService(authService);
  runApp(MyApp(authService: authService, apiService: apiService));
}

class MyApp extends StatelessWidget {
  final AuthService authService;
  final ApiService apiService;

  const MyApp({super.key, required this.authService, required this.apiService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: apiService),
        ChangeNotifierProvider.value(value: authService),
      ],
      child: MaterialApp(
        title: 'Teman Community',
        theme: ThemeData(
          // Use a more vibrant color scheme as requested
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
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
        // home을 사용하면 deep link에서 initial route가 무시되는 경우가 있어 onGenerateRoute로 처리
        onGenerateRoute: (settings) {
          final uri = Uri.parse(settings.name ?? '/');
          if (uri.path == '/reset-password') {
            final token = uri.queryParameters['token'];
            return MaterialPageRoute(
              builder: (_) => ResetPasswordScreen(token: token),
              settings: settings,
            );
          }
          return MaterialPageRoute(
            builder: (_) => const AuthWrapper(),
            settings: settings,
          );
        },
        onUnknownRoute: (settings) {
          return MaterialPageRoute(builder: (_) => const AuthWrapper());
        }
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        return auth.isLoggedIn ? const MainScreen() : const LoginScreen();
      },
    );
  }
}
