import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'splash_screen.dart';

void main() => runApp(const WiwyApp());

class WiwyApp extends StatelessWidget {
  const WiwyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wiwy Downloader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.orange,
          surface: AppColors.card,
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
