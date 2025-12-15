import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../state/language_provider.dart';
import '../state/themeprovier.dart'; // Added import

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ForgotPasswordScreenState createState() => ForgotPasswordScreenState();
}

class ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  bool isSpeaking = false;
  final FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _setupTTS();
  }

  void _setupTTS() async {
    await flutterTts.setSpeechRate(0.45);
    await flutterTts.setVolume(1.0);

    flutterTts.setCompletionHandler(() {
      setState(() => isSpeaking = false);
    });

    flutterTts.setCancelHandler(() {
      setState(() => isSpeaking = false);
    });
  }

  Future<void> _speak(String text, String lang) async {
    setState(() => isSpeaking = true);
    await flutterTts.setLanguage(lang);
    await flutterTts.speak(text);
  }

  Future<void> _stopSpeaking() async {
    await flutterTts.stop();
    setState(() => isSpeaking = false);
  }

  @override
  void dispose() {
    flutterTts.stop();
    _emailController.dispose();
    super.dispose();
  }

  String englishNarration = """
Reset your SmartAgri password.
Select your preferred language.
Enter your registered email address.
Press the Send Reset Link button to continue.
Tap Back to Login if you want to return.
""";

  String urduNarration = """
اپنا اسمارٹ ایگری پاس ورڈ ری سیٹ کریں۔
اپنی زبان منتخب کریں۔
اپنا رجسٹرڈ ای میل درج کریں۔
آگے بڑھنے کے لیے ری سیٹ لنک بھیجیں دبائیں۔
اگر واپس جانا چاہتے ہیں تو لاگ ان پر واپس جائیں دبائیں۔
""";

  void _toggleSpeaker(String lang) async {
    if (isSpeaking) {
      await _stopSpeaking();
      return;
    }

    if (lang == "EN") {
      await _speak(englishNarration, "en-US");
    } else {
      await _speak(urduNarration, "ur-PK");
    }
  }

  // Convert identifier to Firebase email format (same as login/signup)
  String _convertToFirebaseEmail(String identifier) {
    identifier = identifier.trim();

    // If it's already an email (contains @), use it as-is
    if (identifier.contains('@')) {
      return identifier;
    }

    // If it's a phone number (digits only), append @gmail.com
    final phoneRegex = RegExp(r'^[0-9]+$');
    if (phoneRegex.hasMatch(identifier)) {
      return '$identifier@gmail.com';
    }

    // If it's neither (username), also append @gmail.com
    return '$identifier@gmail.com';
  }

  String getSuccessMessage(BuildContext context) {
    final langProvider = context.read<LanguageProvider>();
    final selectedLang = langProvider.currentLang;

    return selectedLang == "EN"
        ? "Password reset email sent! Check your inbox."
        : "پاس ورڈ ری سیٹ ای میل بھیج دی گئی! اپنا ان باکس چیک کریں۔";
  }

  String getFirebaseErrorMessage(
    BuildContext context,
    FirebaseAuthException e,
  ) {
    final langProvider = context.read<LanguageProvider>();
    final selectedLang = langProvider.currentLang;

    switch (e.code) {
      case "invalid-email":
        return selectedLang == "EN"
            ? "Invalid email format"
            : "ای میل کی شکل غلط ہے";
      case "user-not-found":
        return selectedLang == "EN"
            ? "No account found with this email"
            : "اس ای میل سے کوئی اکاؤنٹ نہیں ملا";
      default:
        return selectedLang == "EN" ? "Error: ${e.code}" : "خرابی: ${e.code}";
    }
  }

  String getDefaultErrorMessage(BuildContext context) {
    final langProvider = context.read<LanguageProvider>();
    final selectedLang = langProvider.currentLang;

    return selectedLang == "EN"
        ? "Failed to send reset email"
        : "ری سیٹ ای میل بھیجنے میں ناکامی";
  }

  Future<void> _handleResetPassword() async {
    if (_isLoading) return;

    final identifier = _emailController.text.trim();

    if (identifier.isEmpty) {
      setState(() {
        _errorMessage = "Email is required";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Convert to Firebase email format
      final firebaseEmail = _convertToFirebaseEmail(identifier);

      // Send password reset email via Firebase
      await FirebaseAuth.instance.sendPasswordResetEmail(email: firebaseEmail);

      // Show success snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.green[800]!
              : Colors.green,
          content: Text(getSuccessMessage(context)),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      String message = getDefaultErrorMessage(context);

      if (e is FirebaseAuthException) {
        message = getFirebaseErrorMessage(context, e);
      }

      setState(() {
        _errorMessage = message;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.red[800]!
              : Colors.red,
          content: Text(message),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: true);
    final langProvider = Provider.of<LanguageProvider>(context);
    final selectedLang = langProvider.currentLang;
    final isDarkMode = themeProvider.isDarkMode;

    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    // Theme-aware colors
    final backgroundColor = isDarkMode ? Colors.grey[900]! : Colors.white;
    final primaryColor = const Color(0xFF21C357);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF5A5C5F);
    final secondaryTextColor = isDarkMode
        ? Colors.grey[400]!
        : const Color(0xFFB9BCC3);
    final inputBackground = isDarkMode
        ? Colors.grey[800]!
        : const Color(0xFFFAFAFA);
    final borderColor = isDarkMode
        ? Colors.grey[700]!
        : const Color(0xFFEEEFF2);
    final iconColor = isDarkMode ? Colors.grey[400]! : Colors.grey.shade600;
    final dividerColor = isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;
    final subtitleColor = isDarkMode
        ? Colors.grey[400]!
        : const Color(0xFFAAADB5);
    final labelColor = isDarkMode ? Colors.grey[300]! : const Color(0xFF898A8D);

    return Container(
      height: h * 0.70,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(w * 0.07),
          topRight: Radius.circular(w * 0.07),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: w * 0.07),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: h * 0.02),

              Center(
                child: Container(
                  width: w * 0.18,
                  height: h * 0.008,
                  decoration: BoxDecoration(
                    color: dividerColor,
                    borderRadius: BorderRadius.circular(w * 0.02),
                  ),
                ),
              ),

              SizedBox(height: h * 0.03),

              Row(
                children: [
                  Image.asset(
                    "assets/images/logo_left.png",
                    width: w * 0.09,
                    height: w * 0.09,
                    color: isDarkMode ? Colors.white : null,
                  ),

                  SizedBox(width: w * 0.04),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedLang == "EN"
                            ? "Reset Password"
                            : "پاس ورڈ ری سیٹ کریں",
                        style: GoogleFonts.inter(
                          fontSize: w * 0.055,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      SizedBox(height: h * 0.005),
                      Text(
                        selectedLang == "EN"
                            ? "We'll send you a reset link"
                            : "ہم آپ کو ری سیٹ لنک بھیجیں گے",
                        style: GoogleFonts.inter(
                          fontSize: w * 0.036,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  GestureDetector(
                    onTap: () => _toggleSpeaker(selectedLang),
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        isSpeaking ? primaryColor : iconColor,
                        BlendMode.srcIn,
                      ),
                      child: Image.asset(
                        "assets/images/speaker.png",
                        width: w * 0.07,
                        height: w * 0.07,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: h * 0.03),

              // Language Selector
              Container(
                width: w * 0.40,
                height: h * 0.065,
                padding: EdgeInsets.symmetric(horizontal: w * 0.015),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800]! : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(w * 0.03),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.grey[700]!
                        : Colors.grey.shade200,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => langProvider.changeLang("EN"),
                        child: Container(
                          height: h * 0.045,
                          decoration: BoxDecoration(
                            color: selectedLang == "EN"
                                ? primaryColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(w * 0.03),
                          ),
                          child: Center(
                            child: Text(
                              "EN",
                              style: GoogleFonts.inter(
                                fontSize: w * 0.035,
                                fontWeight: FontWeight.bold,
                                color: selectedLang == "EN"
                                    ? Colors.white
                                    : isDarkMode
                                    ? Colors.grey[400]!
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: w * 0.02),

                    Expanded(
                      child: GestureDetector(
                        onTap: () => langProvider.changeLang("UR"),
                        child: Container(
                          height: h * 0.045,
                          decoration: BoxDecoration(
                            color: selectedLang == "UR"
                                ? primaryColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(w * 0.03),
                          ),
                          child: Center(
                            child: Text(
                              "اردو",
                              textDirection: TextDirection.rtl,
                              style: GoogleFonts.inter(
                                fontSize: w * 0.037,
                                fontWeight: FontWeight.bold,
                                color: selectedLang == "UR"
                                    ? Colors.white
                                    : isDarkMode
                                    ? Colors.grey[400]!
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: h * 0.03),

              Text(
                selectedLang == "EN"
                    ? "Enter your registered email to receive a password reset link."
                    : "پاس ورڈ ری سیٹ لنک حاصل کرنے کے لیے اپنا رجسٹرڈ ای میل درج کریں۔",
                style: GoogleFonts.inter(
                  fontSize: w * 0.038,
                  color: subtitleColor,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: h * 0.04),

              Row(
                children: [
                  Text(
                    selectedLang == "EN" ? "Email Address" : "ای میل ایڈریس",
                    style: GoogleFonts.inter(
                      fontSize: w * 0.040,
                      fontWeight: FontWeight.bold,
                      color: labelColor,
                    ),
                  ),
                ],
              ),

              SizedBox(height: h * 0.015),

              Container(
                height: h * 0.065,
                padding: EdgeInsets.symmetric(horizontal: w * 0.04),
                decoration: BoxDecoration(
                  color: inputBackground,
                  borderRadius: BorderRadius.circular(w * 0.03),
                  border: Border.all(
                    width: 2,
                    color: _errorMessage != null
                        ? Colors.red.shade300
                        : borderColor,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.email_outlined,
                      size: w * 0.055,
                      color: primaryColor,
                    ),
                    SizedBox(width: w * 0.04),
                    Expanded(
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: textColor, fontSize: w * 0.038),
                        decoration: InputDecoration(
                          hintText: selectedLang == "EN"
                              ? "email@example.com"
                              : "ای میل درج کریں",
                          hintStyle: GoogleFonts.inter(
                            fontSize: w * 0.038,
                            color: secondaryTextColor,
                          ),
                          border: InputBorder.none,
                        ),
                        onChanged: (_) {
                          if (_errorMessage != null) {
                            setState(() => _errorMessage = null);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null)
                Padding(
                  padding: EdgeInsets.only(left: w * 0.02, top: h * 0.01),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red, fontSize: w * 0.035),
                  ),
                ),

              SizedBox(height: h * 0.04),

              SizedBox(
                height: h * 0.065,
                width: w,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleResetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(w * 0.04),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: w * 0.06,
                          height: w * 0.06,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          selectedLang == "EN"
                              ? "Send Reset Link"
                              : "ری سیٹ لنک بھیجیں",
                          style: GoogleFonts.inter(
                            fontSize: w * 0.045,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              SizedBox(height: h * 0.02),

              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text(
                    selectedLang == "EN"
                        ? "Back to Login"
                        : "لاگ ان پر واپس جائیں",
                    style: GoogleFonts.inter(
                      fontSize: w * 0.043,
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              SizedBox(height: h * 0.04),
            ],
          ),
        ),
      ),
    );
  }
}
