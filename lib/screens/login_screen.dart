import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/language_provider.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import 'hardwereinsertionscreen.dart';
import '../state/themeprovier.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  String? identifierErrorType;
  String? passwordErrorType;

  bool isSpeaking = false;
  final FlutterTts flutterTts = FlutterTts();

  static const String _rememberMeKey = 'remember_me';
  static const String _identifierKey = 'saved_identifier';
  static const String _passwordKey = 'saved_password';

  @override
  void initState() {
    super.initState();
    _setupTTS();
    _loadSavedCredentials();
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

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool(_rememberMeKey) ?? false;

      if (rememberMe) {
        final savedIdentifier = prefs.getString(_identifierKey);
        final savedPassword = prefs.getString(_passwordKey);

        if (savedIdentifier != null && savedPassword != null) {
          setState(() {
            _rememberMe = true;
            _identifierController.text = savedIdentifier;
            _passwordController.text = savedPassword;
          });
        }
      }
    } catch (e) {
      print('Error loading saved credentials: $e');
    }
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setBool(_rememberMeKey, true);
      await prefs.setString(_identifierKey, _identifierController.text.trim());
      await prefs.setString(_passwordKey, _passwordController.text.trim());
    } else {
      await prefs.setBool(_rememberMeKey, false);
      await prefs.remove(_identifierKey);
      await prefs.remove(_passwordKey);
    }
  }

  Future<void> _clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, false);
    await prefs.remove(_identifierKey);
    await prefs.remove(_passwordKey);
  }

  Future<void> _speak(String text, String langCode) async {
    setState(() => isSpeaking = true);
    await flutterTts.setLanguage(langCode);
    await flutterTts.speak(text);
  }

  Future<void> _stopSpeaking() async {
    await flutterTts.stop();
    setState(() => isSpeaking = false);
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    flutterTts.stop();
    super.dispose();
  }

  void _openSignUp() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const SignUpScreen(),
    );
  }

  void _openForgot() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const ForgotPasswordScreen(),
    );
  }

  bool _validate() {
    setState(() {
      identifierErrorType = null;
      passwordErrorType = null;
    });

    bool isValid = true;

    final identifier = _identifierController.text.trim();

    if (identifier.isEmpty) {
      identifierErrorType = "required";
      isValid = false;
    } else if (!_isValidIdentifier(identifier)) {
      identifierErrorType = "invalid";
      isValid = false;
    }

    final pass = _passwordController.text.trim();
    if (pass.isEmpty) {
      passwordErrorType = "required";
      isValid = false;
    } else if (pass.length < 8) {
      passwordErrorType = "length";
      isValid = false;
    }

    return isValid;
  }

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

    return false;
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
            ? "Enter a valid email or phone number"
            : "درست ای میل یا فون نمبر درج کریں";
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

  String getSuccessMessage(BuildContext context) {
    final langProvider = context.read<LanguageProvider>();
    final selectedLang = langProvider.currentLang;

    return selectedLang == "EN" ? "Login successful!" : "لاگ ان کامیاب!";
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
            ? "Account does not exist. Please sign up."
            : "اکاؤنٹ موجود نہیں ہے۔ سائن اپ کریں۔";
      case "wrong-password":
        return selectedLang == "EN" ? "Incorrect password." : "غلط پاس ورڈ۔";
      case "user-disabled":
        return selectedLang == "EN"
            ? "This account has been disabled."
            : "یہ اکاؤنٹ غیر فعال ہے۔";
      case "too-many-requests":
        return selectedLang == "EN"
            ? "Too many attempts. Try again later."
            : "زیادہ کوششیں۔ بعد میں کوشش کریں۔";
      default:
        return selectedLang == "EN"
            ? "Login failed: ${e.code}"
            : "لاگ ان ناکام: ${e.code}";
    }
  }

  String getDefaultErrorMessage(BuildContext context) {
    final langProvider = context.read<LanguageProvider>();
    final selectedLang = langProvider.currentLang;

    return selectedLang == "EN" ? "Login unsuccessful" : "لاگ ان ناکام";
  }

  String getCredentialsClearedMessage(BuildContext context) {
    final langProvider = context.read<LanguageProvider>();
    final selectedLang = langProvider.currentLang;

    return selectedLang == "EN" ? "Credentials cleared" : "سنیچے ہٹا دیے گئے";
  }

  // Handle both email and phone
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

  Future<void> _onLoginPressed() async {
    if (!_validate() || _isLoading) return;

    setState(() => _isLoading = true);

    final identifier = _identifierController.text.trim();
    final password = _passwordController.text.trim();

    final firebaseEmail = _convertToFirebaseEmail(identifier);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: firebaseEmail,
        password: password,
      );

      await _saveCredentials();

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
        MaterialPageRoute(builder: (_) => const HardwareInsertionScreen()),
      );
    } catch (e) {
      String message = getDefaultErrorMessage(context);

      if (e is FirebaseAuthException) {
        message = getFirebaseErrorMessage(context, e);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.red[800]!
              : Colors.red,
          content: Text(message),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  final String _englishNarration = """
Welcome to SmartAgri.
Select your preferred language.
Enter your email or phone number and password.
You may choose 'Remember me'.
If needed, tap Forgot Password.
Press Login to continue.
If you do not have an account, you can Sign Up.
""";

  final String _urduNarration = """
اسمارٹ ایگری میں خوش آمدید۔
اپنی زبان منتخب کریں۔
اپنا ای میل یا فون نمبر اور پاس ورڈ درج کریں۔
اگر ضرورت ہو تو 'پاس ورڈ بھول گئے' دبائیں۔
آگے بڑھنے کے لیے لاگ ان دبائیں۔
اگر اکاؤنٹ نہیں ہے تو سائن اپ کریں۔
""";

  void _toggleSpeaker(BuildContext context) async {
    if (isSpeaking) {
      await _stopSpeaking();
      return;
    }

    final langProvider = context.read<LanguageProvider>();
    final selectedLang = langProvider.currentLang;

    if (selectedLang == "EN") {
      await _speak(_englishNarration, "en-US");
    } else {
      await _speak(_urduNarration, "ur-PK");
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

    // Define colors based on theme - using non-nullable colors
    final backgroundColor = isDarkMode ? Colors.grey[900]! : Colors.white;
    final primaryColor = const Color(0xFF21C357);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF3F3F3F);
    final secondaryTextColor = isDarkMode
        ? Colors.grey[400]!
        : Colors.grey[600]!;
    final inputBackground = isDarkMode ? Colors.grey[800]! : Colors.grey[100]!;
    final borderColor = isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;
    final dividerColor = isDarkMode
        ? Colors.grey[700]!
        : const Color(0xFFE9E9E9);
    final iconColor = isDarkMode ? Colors.grey[400]! : Colors.grey;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: w * 0.07),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: h * 0.02),

                      // HEADER ROW - Logo + SmartAgri on left, Icons on right
                      Row(
                        children: [
                          // Logo and SmartAgri on left
                          Row(
                            children: [
                              Image.asset(
                                'assets/images/logo_left.png',
                                width: w * 0.08,
                                height: w * 0.08,
                                color: isDarkMode ? Colors.white : null,
                              ),
                              SizedBox(width: w * 0.02),
                              Text(
                                "SmartAgri",
                                style: GoogleFonts.inter(
                                  fontSize: w * 0.055,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),

                          // Icons on right corner - Dark mode toggle + Speaker
                          Row(
                            children: [
                              // Dark Mode Toggle Button
                              IconButton(
                                onPressed: () {
                                  themeProvider.toggleTheme();
                                },
                                icon: Icon(
                                  isDarkMode
                                      ? Icons.light_mode
                                      : Icons.dark_mode,
                                  color: primaryColor,
                                  size: 28,
                                ),
                                tooltip: isDarkMode
                                    ? 'Switch to Light Mode'
                                    : 'Switch to Dark Mode',
                              ),

                              SizedBox(width: w * 0.02),

                              // Speaker Icon
                              GestureDetector(
                                onTap: () => _toggleSpeaker(context),
                                child: Icon(
                                  isSpeaking
                                      ? Icons.volume_up
                                      : Icons.volume_mute,
                                  color: isSpeaking ? primaryColor : iconColor,
                                  size: w * 0.07,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      SizedBox(height: h * 0.02),
                      Container(height: 2, color: dividerColor),
                      SizedBox(height: h * 0.03),

                      // LANGUAGE TOGGLE - Below header, at top left corner
                      Container(
                        width: w * 0.40,
                        height: h * 0.065,
                        padding: EdgeInsets.symmetric(horizontal: w * 0.015),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.grey[800]!
                              : Colors.grey.shade50,
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
                                    borderRadius: BorderRadius.circular(
                                      w * 0.03,
                                    ),
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
                                    borderRadius: BorderRadius.circular(
                                      w * 0.03,
                                    ),
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

                      // Welcome Heading
                      Text(
                        selectedLang == "EN"
                            ? "Welcome to SmartAgri!"
                            : "اسمارٹ ایگری میں خوش آمدید!",
                        style: GoogleFonts.inter(
                          fontSize: w * 0.075,
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: h * 0.04),

                      // Image
                      SizedBox(
                        height: h * 0.20,
                        child: Image.asset(
                          'assets/images/new.jpg',
                          fit: BoxFit.contain,
                        ),
                      ),

                      SizedBox(height: h * 0.03),

                      // Email or Phone Input Field
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
                            Icon(
                              Icons.email_outlined,
                              color: primaryColor,
                              size: w * 0.06,
                            ),
                            SizedBox(width: w * 0.04),
                            Expanded(
                              child: TextField(
                                controller: _identifierController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: w * 0.04,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: selectedLang == "EN"
                                      ? "Email or phone number"
                                      : "ای میل یا فون نمبر",
                                  hintStyle: GoogleFonts.inter(
                                    fontSize: w * 0.04,
                                    color: secondaryTextColor,
                                  ),
                                ),
                                onSubmitted: (_) {
                                  FocusScope.of(context).nextFocus();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (identifierErrorType != null)
                        Padding(
                          padding: EdgeInsets.only(
                            left: w * 0.02,
                            top: h * 0.008,
                          ),
                          child: Text(
                            getIdentifierErrorMessage(context)!,
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: w * 0.032,
                            ),
                          ),
                        ),

                      SizedBox(height: h * 0.025),

                      // Password Input Field
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
                            Icon(
                              Icons.lock_outline,
                              color: primaryColor,
                              size: w * 0.06,
                            ),
                            SizedBox(width: w * 0.04),
                            Expanded(
                              child: TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: w * 0.04,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: selectedLang == "EN"
                                      ? "Password"
                                      : "پاس ورڈ",
                                  hintStyle: GoogleFonts.inter(
                                    fontSize: w * 0.04,
                                    color: secondaryTextColor,
                                  ),
                                ),
                                onSubmitted: (_) => _onLoginPressed(),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              child: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                size: w * 0.06,
                                color: iconColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (passwordErrorType != null)
                        Padding(
                          padding: EdgeInsets.only(
                            left: w * 0.02,
                            top: h * 0.008,
                          ),
                          child: Text(
                            getPasswordErrorMessage(context)!,
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: w * 0.032,
                            ),
                          ),
                        ),

                      SizedBox(height: h * 0.02),

                      // Remember me & Forgot Password
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            activeColor: primaryColor,
                            checkColor: Colors.white,
                            fillColor: MaterialStateProperty.resolveWith<Color>(
                              (Set<MaterialState> states) {
                                if (states.contains(MaterialState.selected)) {
                                  return primaryColor;
                                }
                                return isDarkMode
                                    ? Colors.grey[700]!
                                    : Colors.grey[300]!;
                              },
                            ),
                            onChanged: (v) async {
                              setState(() {
                                _rememberMe = v ?? false;
                              });

                              if (!_rememberMe) {
                                await _clearCredentials();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: isDarkMode
                                          ? Colors.blue[800]!
                                          : Colors.blue,
                                      duration: const Duration(seconds: 2),
                                      content: Text(
                                        getCredentialsClearedMessage(context),
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                          Text(
                            selectedLang == "EN"
                                ? "Remember me"
                                : "مجھے یاد رکھیں",
                            style: GoogleFonts.inter(
                              fontSize: w * 0.035,
                              color: secondaryTextColor,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _openForgot,
                            child: Text(
                              selectedLang == "EN"
                                  ? "Forgot Password?"
                                  : "پاس ورڈ بھول گئے؟",
                              style: GoogleFonts.inter(
                                fontSize: w * 0.035,
                                color: primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: h * 0.03),

                      // Login Button with loading state
                      SizedBox(
                        width: w,
                        height: h * 0.07,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _onLoginPressed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(w * 0.03),
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
                                  selectedLang == "EN" ? "Login" : "لاگ ان",
                                  style: GoogleFonts.inter(
                                    fontSize: w * 0.050,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      SizedBox(height: h * 0.02),

                      // Sign Up Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            selectedLang == "EN"
                                ? "Don't have an account?"
                                : "اکاؤنٹ نہیں ہے؟",
                            style: GoogleFonts.inter(
                              fontSize: w * 0.035,
                              color: secondaryTextColor,
                            ),
                          ),
                          SizedBox(width: w * 0.015),
                          GestureDetector(
                            onTap: _openSignUp,
                            child: Text(
                              selectedLang == "EN" ? "Sign up" : "سائن اپ",
                              style: GoogleFonts.inter(
                                fontSize: w * 0.038,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: h * 0.08),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
