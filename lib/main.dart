import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import './screens/splashscreen.dart';
import './state/themeprovier.dart'; // FIXED: Import from correct location
import './state/language_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp();

    // Debug Test 1: Firebase Core
    print(" Firebase Core initialized successfully.");

    // Debug Test 2: Check Auth by signing in anonymously
    try {
      await FirebaseAuth.instance.signInAnonymously();
      print(" Firebase Auth test successful. Auth is working.");
    } catch (authError) {
      print(" Firebase Auth test FAILED.");
      print(" Auth Error: $authError");
    }
  } catch (e) {
    print(" Firebase initialization FAILED.");
    print(" Error: $e");
  }

  // Load saved language
  final prefs = await SharedPreferences.getInstance();
  final savedLang = prefs.getString("app_lang") ?? "EN";

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider(savedLang)),
        ChangeNotifierProvider(
          create: (_) =>
              ThemeProvider(), // Now this uses the correct ThemeProvider
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(
      context,
    ); // Get ThemeProvider

    return MaterialApp(
      title: 'Smart Agriculture System',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
        brightness: Brightness.light, // Light theme
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
        brightness: Brightness.dark, // Dark theme
      ),
      themeMode: themeProvider.isDarkMode
          ? ThemeMode.dark
          : ThemeMode.light, // Set theme mode

      locale: Locale(lang.currentLang.toLowerCase()),

      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
