import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added import

import '../state/language_provider.dart';
import '../state/themeprovier.dart';
import 'hardwereinsertionscreen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  SignUpScreenState createState() => SignUpScreenState();
}

class SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _fullName = TextEditingController();
  final TextEditingController _identifier = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _seePass = false;
  bool _seeConfirm = false;
  bool _isLoading = false;

  String? fullNameErrorType;
  String? identifierErrorType;
  String? passwordErrorType;
  String? confirmErrorType;

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
    _fullName.dispose();
    _identifier.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String englishNarration = """
Create your SmartAgri account.
Select your preferred language.
Enter your full name.
Enter your email or phone number.
Create a password and confirm it.
Press Sign Up to continue.
""";

  String urduNarration = """
اپنا اسمارٹ ایگری اکاؤنٹ بنائیں۔
اپنی زبان منتخب کریں۔
اپنا پورا نام درج کریں۔
اپنا ای میل یا فون نمبر درج کریں۔
پاس ورڈ بنائیں اور اس کی تصدیق کریں۔
آگے بڑھنے کے لئے سائن اپ دبائیں۔
""";

  bool _validate() {
    setState(() {
      fullNameErrorType = null;
      identifierErrorType = null;
      passwordErrorType = null;
      confirmErrorType = null;
    });

    bool isValid = true;

    if (_fullName.text.trim().isEmpty) {
      fullNameErrorType = "required";
      isValid = false;
    }

    String identifier = _identifier.text.trim();
    if (identifier.isEmpty) {
      identifierErrorType = "required";
      isValid = false;
    } else if (!_isValidIdentifier(identifier)) {
      identifierErrorType = "invalid";
      isValid = false;
    }

    if (_password.text.isEmpty) {
      passwordErrorType = "required";
      isValid = false;
    } else if (_password.text.length < 8) {
      passwordErrorType = "length";
      isValid = false;
    }

    if (_confirm.text.isEmpty) {
      confirmErrorType = "required";
      isValid = false;
    } else if (_password.text != _confirm.text) {
      confirmErrorType = "mismatch";
      isValid = false;
    }

    return isValid;
  }

  // ONLY accept email or phone (no arbitrary usernames)
  bool _isValidIdentifier(String identifier) {
    // Check if it's a valid email
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (emailRegex.hasMatch(identifier)) {
      return true;
    }

    // Check if it's a valid phone number (digits only, length 10-15)
    final phoneRegex = RegExp(r'^[0-9]{10,15}$');
    if (phoneRegex.hasMatch(identifier)) {
      return true;
    }

    return false; // Reject anything that's not email or phone
  }

  // Helper methods for localized error messages
  String? getFullNameErrorMessage(BuildContext context) {
    if (fullNameErrorType == null) return null;

    final langProvider = context.read<LanguageProvider>();
    final selectedLang = langProvider.currentLang;

    if (fullNameErrorType == "required") {
      return selectedLang == "EN"
          ? "Full name is required"
          : "پورا نام درج کریں";
    }

    return null;
  }

  String? getIdentifierErrorMessage(BuildContext context) {
    if (identifierErrorType == null) return null;

    final langProvider = context.read<LanguageProvider>();
    final selectedLang = langProvider.currentLang;

    switch (identifierErrorType) {
      case "required":
        return selectedLang == "EN"
            ? "Email or phone number is required"
            : "ای میل یا فون نمبر درج کریں";
      case "invalid":
        return selectedLang == "EN"
            ? "Enter a valid email (user@example.com) or phone number"
            : "درست ای میل (user@example.com) یا فون نمبر درج کریں";
      default:
        return null;
    }
  }

  String? getPasswordErrorMessage(BuildContext context) {
    if (passwordErrorType == null) return null;

    final langProvider = context.read<LanguageProvider>();
    final selectedLang = langProvider.currentLang;

    switch (passwordErrorType) {
      case "required":
        return selectedLang == "EN"
            ? "Password is required"
            : "پاس ورڈ درج کریں";
      case "length":
        return selectedLang == "EN"
            ? "Password must be at least 8 characters"
            : "پاس ورڈ کم از کم 8 حروف کا ہونا چاہیے";
      default:
        return null;
    }
  }

  String? getConfirmErrorMessage(BuildContext context) {
    if (confirmErrorType == null) return null;

    final langProvider = context.read<LanguageProvider>();
    final selectedLang = langProvider.currentLang;

    switch (confirmErrorType) {
      case "required":
        return selectedLang == "EN"
            ? "Confirm password is required"
            : "پاس ورڈ کی تصدیق درج کریں";
      case "mismatch":
        return selectedLang == "EN"
            ? "Passwords do not match"
            : "پاس ورڈ مماثل نہیں ہیں";
      default:
        return null;
    }
  }

  String getSuccessMessage(BuildContext context) {
    final langProvider = context.read<LanguageProvider>();
    final selectedLang = langProvider.currentLang;

    return selectedLang == "EN" ? "Sign up successful!" : "سائن اپ کامیاب!";
  }

  String getFirebaseErrorMessage(
    BuildContext context,
    FirebaseAuthException e,
  ) {
    final langProvider = context.read<LanguageProvider>();
    final selectedLang = langProvider.currentLang;

    if (e.code == "email-already-in-use") {
      return selectedLang == "EN"
          ? "This email or phone number is already registered"
          : "یہ ای میل یا فون نمبر پہلے سے رجسٹرڈ ہے";
    } else if (e.code == "invalid-email") {
      return selectedLang == "EN"
          ? "Invalid email format"
          : "ای میل کی شکل غلط ہے";
    } else if (e.code == "weak-password") {
      return selectedLang == "EN"
          ? "Weak password. Use at least 8 characters"
          : "کمزور پاس ورڈ۔ کم از کم 8 حروف استعمال کریں";
    } else {
      return selectedLang == "EN"
          ? "Sign up failed: ${e.code}"
          : "سائن اپ ناکام: ${e.code}";
    }
  }

  String getDefaultErrorMessage(BuildContext context) {
    final langProvider = context.read<LanguageProvider>();
    final selectedLang = langProvider.currentLang;

    return selectedLang == "EN" ? "Something went wrong" : "کچھ غلط ہوا";
  }

  // SIMPLIFIED: Only handle email or phone
  String _convertToFirebaseEmail(String identifier) {
    identifier = identifier.trim();

    // If it's already an email (contains @), use it as-is
    if (identifier.contains('@')) {
      return identifier;
    }

    // If it's a phone number (digits only), append @gmail.com
    // No else case - username not allowed
    return '$identifier@gmail.com';
  }

  // CREATE USER DOCUMENT IN FIRESTORE
  Future<void> _createUserDocument(
    User user,
    String fullName,
    String identifier,
  ) async {
    try {
      // Get current timestamp
      final timestamp = Timestamp.now();

      // Create user data for Firestore
      final userData = {
        'uid': user.uid,
        'name': fullName.trim(),
        'email': identifier.contains('@') ? identifier : null,
        'phone': identifier.contains('@') ? null : identifier,
        'identifier': identifier, // Store the original identifier
        'createdAt': timestamp,
        'updatedAt': timestamp,
        'farmSize': 'Not set', // Default value
        'location': null, // Will be set later
        'profileImageUrl': null, // Will be set later
        'userType': 'farmer', // Default user type
      };

      // Create user document in 'users' collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userData);

      // Create empty subcollections for sensor readings and disease history
      // Note: We don't need to create documents in subcollections yet
      // They will be created when data is added

      debugPrint('User document created successfully for UID: ${user.uid}');
    } catch (e) {
      debugPrint('Error creating user document: $e');
      // Re-throw to handle in the main signup flow
      throw Exception('Failed to create user profile: $e');
    }
  }

  // FIREBASE INTEGRATION - UPDATED
  Future<void> _onSignUp() async {
    if (!_validate() || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      // Convert identifier to Firebase email format
      final identifier = _identifier.text.trim();
      final firebaseEmail = _convertToFirebaseEmail(identifier);
      final password = _password.text.trim();
      final fullName = _fullName.text.trim();

      // 1. Create user in Firebase Authentication
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: firebaseEmail,
            password: password,
          );

      final User user = userCredential.user!;

      // 2. Create user document in Firestore
      await _createUserDocument(user, fullName, identifier);

      // Success → go to next screen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.green[800]!
              : Colors.green,
          content: Text(getSuccessMessage(context)),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HardwareInsertionScreen(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      // Firebase Auth errors
      String msg = getFirebaseErrorMessage(context, e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.red[800]!
              : Colors.red,
        ),
      );
    } catch (e) {
      // Other errors (including Firestore errors)
      String msg = getDefaultErrorMessage(context);
      if (e.toString().contains('Failed to create user profile')) {
        msg =
            "Account created but profile setup failed. Please update your profile later.";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.orange[800]!
              : Colors.orange,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleSpeaker(BuildContext context) {
    if (isSpeaking) {
      _stopSpeaking();
    } else {
      final langProvider = context.read<LanguageProvider>();
      final selectedLang = langProvider.currentLang;

      if (selectedLang == "EN") {
        _speak(englishNarration, "en-US");
      } else {
        _speak(urduNarration, "ur-PK");
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
        : Colors.grey[600]!;
    final inputBackground = isDarkMode
        ? Colors.grey[800]!
        : Colors.grey.shade300;
    final borderColor = isDarkMode ? Colors.grey[700]! : Colors.grey.shade300;
    final iconColor = isDarkMode ? Colors.grey[400]! : Colors.grey;
    final dividerColor = isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        height: h,
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
                SizedBox(height: h * 0.03),

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

                SizedBox(height: h * 0.04),

                // HEADER ROW
                Row(
                  children: [
                    Image.asset(
                      "assets/images/logo_left.png",
                      width: w * 0.09,
                      height: w * 0.09,
                      color: isDarkMode ? Colors.white : null,
                    ),

                    SizedBox(width: w * 0.04),

                    Expanded(
                      child: Text(
                        selectedLang == "EN"
                            ? "Sign Up for SmartAgri"
                            : "اسمارٹ ایگری میں رجسٹر کریں",
                        style: GoogleFonts.inter(
                          fontSize: w * 0.055,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),

                    GestureDetector(
                      onTap: () => _toggleSpeaker(context),
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          isSpeaking ? primaryColor : iconColor,
                          BlendMode.srcIn,
                        ),
                        child: Image.asset(
                          "assets/images/speaker.png",
                          width: w * 0.075,
                          height: w * 0.075,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: h * 0.03),

                // LANGUAGE TOGGLE - Below header
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
                          onTap: () {
                            langProvider.changeLang("EN");
                            setState(() {});
                          },
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
                          onTap: () {
                            langProvider.changeLang("UR");
                            setState(() {});
                          },
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

                SizedBox(height: h * 0.05),

                // Full Name Field
                Padding(
                  padding: EdgeInsets.only(left: w * 0.01, bottom: w * 0.01),
                  child: Text(
                    selectedLang == "EN" ? "Full Name" : "پورا نام",
                    style: GoogleFonts.inter(
                      fontSize: w * 0.044,
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  height: h * 0.07,
                  padding: EdgeInsets.symmetric(horizontal: w * 0.04),
                  decoration: BoxDecoration(
                    color: inputBackground,
                    borderRadius: BorderRadius.circular(w * 0.03),
                    border: Border.all(
                      color: fullNameErrorType != null
                          ? Colors.red
                          : borderColor,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: w * 0.05,
                        color: primaryColor,
                      ),
                      SizedBox(width: w * 0.04),
                      Expanded(
                        child: TextField(
                          controller: _fullName,
                          textInputAction: TextInputAction.next,
                          style: TextStyle(
                            color: textColor,
                            fontSize: w * 0.04,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: selectedLang == "EN"
                                ? "Enter your full name"
                                : "اپنا پورا نام درج کریں",
                            hintStyle: GoogleFonts.inter(
                              fontSize: w * 0.04,
                              color: secondaryTextColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (fullNameErrorType != null)
                  Padding(
                    padding: EdgeInsets.only(left: w * 0.02, top: h * 0.008),
                    child: Text(
                      getFullNameErrorMessage(context)!,
                      style: TextStyle(color: Colors.red, fontSize: w * 0.032),
                    ),
                  ),

                SizedBox(height: h * 0.03),

                // Email or Phone Field
                Padding(
                  padding: EdgeInsets.only(left: w * 0.01, bottom: w * 0.01),
                  child: Text(
                    selectedLang == "EN" ? "Email or Phone" : "ای میل یا فون",
                    style: GoogleFonts.inter(
                      fontSize: w * 0.044,
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  height: h * 0.07,
                  padding: EdgeInsets.symmetric(horizontal: w * 0.04),
                  decoration: BoxDecoration(
                    color: inputBackground,
                    borderRadius: BorderRadius.circular(w * 0.03),
                    border: Border.all(
                      color: identifierErrorType != null
                          ? Colors.red
                          : borderColor,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          primaryColor,
                          BlendMode.srcIn,
                        ),
                        child: Image.asset(
                          "assets/images/email.png",
                          width: w * 0.05,
                        ),
                      ),
                      SizedBox(width: w * 0.04),
                      Expanded(
                        child: TextField(
                          controller: _identifier,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          style: TextStyle(
                            color: textColor,
                            fontSize: w * 0.04,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: selectedLang == "EN"
                                ? "Email (user@example.com) or phone"
                                : "ای میل (user@example.com) یا فون",
                            hintStyle: GoogleFonts.inter(
                              fontSize: w * 0.04,
                              color: secondaryTextColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (identifierErrorType != null)
                  Padding(
                    padding: EdgeInsets.only(left: w * 0.02, top: h * 0.008),
                    child: Text(
                      getIdentifierErrorMessage(context)!,
                      style: TextStyle(color: Colors.red, fontSize: w * 0.032),
                    ),
                  ),

                SizedBox(height: h * 0.03),

                // Password Field
                Padding(
                  padding: EdgeInsets.only(left: w * 0.01, bottom: w * 0.01),
                  child: Text(
                    selectedLang == "EN" ? "Password" : "پاس ورڈ",
                    style: GoogleFonts.inter(
                      fontSize: w * 0.044,
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  height: h * 0.07,
                  padding: EdgeInsets.symmetric(horizontal: w * 0.04),
                  decoration: BoxDecoration(
                    color: inputBackground,
                    borderRadius: BorderRadius.circular(w * 0.03),
                    border: Border.all(
                      color: passwordErrorType != null
                          ? Colors.red
                          : borderColor,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          primaryColor,
                          BlendMode.srcIn,
                        ),
                        child: Image.asset(
                          "assets/images/password.png",
                          width: w * 0.05,
                        ),
                      ),
                      SizedBox(width: w * 0.04),
                      Expanded(
                        child: TextField(
                          controller: _password,
                          obscureText: !_seePass,
                          textInputAction: TextInputAction.next,
                          style: TextStyle(
                            color: textColor,
                            fontSize: w * 0.04,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: selectedLang == "EN"
                                ? "Enter password"
                                : "پاس ورڈ درج کریں",
                            hintStyle: GoogleFonts.inter(
                              fontSize: w * 0.04,
                              color: secondaryTextColor,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() => _seePass = !_seePass);
                        },
                        child: Icon(
                          _seePass ? Icons.visibility : Icons.visibility_off,
                          size: w * 0.06,
                          color: iconColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (passwordErrorType != null)
                  Padding(
                    padding: EdgeInsets.only(left: w * 0.02, top: h * 0.008),
                    child: Text(
                      getPasswordErrorMessage(context)!,
                      style: TextStyle(color: Colors.red, fontSize: w * 0.032),
                    ),
                  ),

                SizedBox(height: h * 0.03),

                // Confirm Password Field
                Padding(
                  padding: EdgeInsets.only(left: w * 0.01, bottom: w * 0.01),
                  child: Text(
                    selectedLang == "EN"
                        ? "Confirm Password"
                        : "پاس ورڈ کی تصدیق کریں",
                    style: GoogleFonts.inter(
                      fontSize: w * 0.044,
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  height: h * 0.07,
                  padding: EdgeInsets.symmetric(horizontal: w * 0.04),
                  decoration: BoxDecoration(
                    color: inputBackground,
                    borderRadius: BorderRadius.circular(w * 0.03),
                    border: Border.all(
                      color: confirmErrorType != null
                          ? Colors.red
                          : borderColor,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          primaryColor,
                          BlendMode.srcIn,
                        ),
                        child: Image.asset(
                          "assets/images/password.png",
                          width: w * 0.05,
                        ),
                      ),
                      SizedBox(width: w * 0.04),
                      Expanded(
                        child: TextField(
                          controller: _confirm,
                          obscureText: !_seeConfirm,
                          textInputAction: TextInputAction.done,
                          style: TextStyle(
                            color: textColor,
                            fontSize: w * 0.04,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: selectedLang == "EN"
                                ? "Re-enter password"
                                : "پاس ورڈ دوبارہ درج کریں",
                            hintStyle: GoogleFonts.inter(
                              fontSize: w * 0.04,
                              color: secondaryTextColor,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() => _seeConfirm = !_seeConfirm);
                        },
                        child: Icon(
                          _seeConfirm ? Icons.visibility : Icons.visibility_off,
                          size: w * 0.06,
                          color: iconColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (confirmErrorType != null)
                  Padding(
                    padding: EdgeInsets.only(left: w * 0.02, top: h * 0.008),
                    child: Text(
                      getConfirmErrorMessage(context)!,
                      style: TextStyle(color: Colors.red, fontSize: w * 0.032),
                    ),
                  ),

                SizedBox(height: h * 0.05),

                // Sign Up Button with loading state
                SizedBox(
                  height: h * 0.07,
                  width: w,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _onSignUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(w * 0.04),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: w * 0.07,
                            height: w * 0.07,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            selectedLang == "EN" ? "Sign Up" : "سائن اپ",
                            style: GoogleFonts.inter(
                              fontSize: w * 0.050,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                SizedBox(height: h * 0.03),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
