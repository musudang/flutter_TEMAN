import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/main_screen.dart';
import 'services/mock_data_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => MockDataService())],
      child: MaterialApp(
        title: 'Teman Community',
        theme: ThemeData(
          // Use a more vibrant color scheme as requested
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            secondary: Colors.orangeAccent,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.grey[50],
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
        home: const MainScreen(),
      ),
    );
  }
}
