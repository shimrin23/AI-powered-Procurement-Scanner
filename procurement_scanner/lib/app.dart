import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

class ProcurementScannerApp extends StatelessWidget {
  const ProcurementScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Procurement Scanner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
