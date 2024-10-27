import 'dart:io';
import 'package:Lists/firebase_options.dart';
import 'package:Lists/theme/theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:Lists/pages/home_page.dart';

// Main entry point for the shopping list application
void main() async {
  // Initialize Flutter bindings for platform channels
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set up Hive database for local storage
  await Hive.initFlutter();
  await Hive.openBox('ListsBox');

  // Configure platform-specific UI settings
  if (Platform.isAndroid) {
    // Set Android system UI appearance
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,          // Transparent status bar
        systemNavigationBarColor: Colors.black,      // Black navigation bar
        systemNavigationBarDividerColor: Colors.transparent,  // No navigation bar divider
      ),
    );
  }

  // Launch the application
  runApp(const MyApp());
}

// Root widget defining application-wide configuration
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,  // Hide debug banner
      home: const HomePage(),             // Set initial route
      title: "Lists",                     // App title
      
      // Theme configuration
      theme: lightMode,                   // Light theme from theme.dart
      darkTheme: darkMode,                // Dark theme from theme.dart
      
      // Theme transition settings
      themeAnimationDuration: const Duration(milliseconds: 300),  // Smooth theme changes
      themeAnimationCurve: Curves.easeInOut,                     // Theme transition curve
    );
  }
}