import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; // Keep import for theme detection

import 'soil_dashboard.dart';
import 'login_screen.dart';
import '../state/themeprovier.dart'; // Keep import for theme detection

class CropSelection extends StatefulWidget {
  const CropSelection({super.key});

  @override
  CropSelectionState createState() => CropSelectionState();
}

class CropSelectionState extends State<CropSelection> {
  String? _selectedCrop;
  String selectedLang = "EN";
  bool isSpeaking = false;
  bool proceedEnabled = false;

  static const Color primaryColor = Color(0xFF21C357);

  late FlutterTts flutterTts;
  bool _isSaving = false;

  // Crop list with English and Urdu names
  final List<Map<String, dynamic>> crops = [
    {
      'name': 'Wheat',
      'urduName': 'گندم',
      'imageUrl': 'assets/images/wheat.png',
      'color': Color(0xFFB5E48C),
      'darkColor': Color(0xFF3A5A40).withOpacity(0.7),
    },
    {
      'name': 'Maize',
      'urduName': 'مکئی',
      'imageUrl': 'assets/images/maize.png',
      'color': Color(0xFFA9DEF9),
      'darkColor': Color(0xFF1E3A5F).withOpacity(0.7),
    },
    {
      'name': 'Cotton',
      'urduName': 'کپاس',
      'imageUrl': 'assets/images/cotton.png',
      'color': Color(0xFFFFE5EC),
      'darkColor': Color(0xFF6D2E46).withOpacity(0.7),
    },
    {
      'name': 'Sugarcane',
      'urduName': 'گنا',
      'imageUrl': 'assets/images/sugarcane.png',
      'color': Color(0xFFFFF3B0),
      'darkColor': Color(0xFF66592C).withOpacity(0.7),
    },
  ];

  // Screen instructions in English and Urdu
  final String englishScreenInstructions = """
Welcome to Crop Selection Screen.
Please select the crop you want to monitor from the available options.
Available crops are: Wheat, Maize, Cotton, and Sugarcane.
Tap on any crop card to select it. The selected crop will be highlighted.
Once you select a crop, the proceed button will turn green.
Tap the green proceed button to save your crop selection and move to soil dashboard.
Your selected crop will be saved with your latest soil sensor readings.
""";

  final String urduScreenInstructions = """
فصل منتخب کریں اسکرین میں خوش آمدید۔
براہ کرم وہ فصل منتخب کریں جس کی آپ نگرانی کرنا چاہتے ہیں۔
دستیاب فصلوں میں شامل ہیں: گندم، مکئی، کپاس اور گنا۔
کسی بھی فصل کے کارڈ پر ٹیپ کریں تاکہ اسے منتخب کیا جائے۔ منتخب کردہ فصل نمایاں ہو جائے گی۔
جب آپ کوئی فصل منتخب کر لیں گے، تو پراسیڈ بٹن سبز ہو جائے گا۔
سبز پراسیڈ بٹن پر ٹیپ کریں تاکہ آپ کی منتخب کردہ فصل محفوظ ہو جائے اور آپ مٹی کے ڈیش بورڈ پر جا سکیں۔
آپ کی منتخب کردہ فصل آپ کی تازہ ترین مٹی کے سینسر ریڈنگز کے ساتھ محفوظ کر دی جائے گی۔
""";

  @override
  void initState() {
    super.initState();
    _initTTS();
  }

  void _initTTS() async {
    flutterTts = FlutterTts();
    await flutterTts.setLanguage(selectedLang == "UR" ? "ur-PK" : "en-US");
    await flutterTts.setSpeechRate(0.5);

    flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          isSpeaking = false;
        });
      }
    });
  }

  void _toggleHeaderSpeaker() async {
    if (isSpeaking) {
      await flutterTts.stop();
      setState(() => isSpeaking = false);
    } else {
      await flutterTts.stop();
      setState(() => isSpeaking = true);

      if (selectedLang == "UR") {
        await flutterTts.setLanguage("ur-PK");
        await flutterTts.speak(urduScreenInstructions);
      } else {
        await flutterTts.setLanguage("en-US");
        await flutterTts.speak(englishScreenInstructions);
      }
    }
  }

  void _onLanguageToggle(String newLang) async {
    await flutterTts.stop();
    setState(() {
      selectedLang = newLang;
      isSpeaking = false;
    });
    await flutterTts.setLanguage(newLang == "UR" ? "ur-PK" : "en-US");
  }

  void _selectCrop(String cropName) async {
    if (_selectedCrop == cropName) return;

    await flutterTts.stop();

    setState(() {
      _selectedCrop = cropName;
      proceedEnabled = true;
    });

    // Speak confirmation
    final isUrdu = selectedLang == "UR";
    final cropText = isUrdu
        ? "آپ نے منتخب کیا ہے: $cropName"
        : "You have selected: $cropName";

    await flutterTts.setLanguage(isUrdu ? "ur-PK" : "en-US");
    await flutterTts.speak(cropText);
  }

  // SIMPLIFIED: Save ONLY crop_name to the latest sensor reading
  Future<void> _saveCropToLatestSensorReading(String cropName) async {
    print("🌱 Saving crop_name: '$cropName' to latest sensor reading...");

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("No user logged in");
      }

      // Get the MOST RECENT sensor reading document
      final querySnapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("sensor_readings")
          .orderBy("timestamp", descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final latestDoc = querySnapshot.docs.first;

        // ✅ ONLY update crop_name field - nothing else
        await latestDoc.reference.update({
          'crop_name': cropName, // ONLY THIS FIELD
        });

        print("✅✅✅ crop_name '$cropName' saved successfully!");
        print("📁 Document ID: ${latestDoc.id}");
      } else {
        print("⚠️ No sensor readings found");
        throw Exception("No sensor readings found for this user");
      }
    } catch (e) {
      print("🔥 Error saving crop_name: $e");
      throw e;
    }
  }

  Future<void> _proceedToDashboard() async {
    if (_selectedCrop == null || !proceedEnabled || _isSaving) return;

    print("🚀 Proceed clicked. Selected crop: $_selectedCrop");

    await flutterTts.stop();

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      setState(() => _isSaving = true);

      // Save ONLY crop_name
      await _saveCropToLatestSensorReading(_selectedCrop!);

      // Close loading and navigate
      if (mounted) {
        Navigator.of(context).pop();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SoilDashboard(
              selectedCrop: _selectedCrop!,
              selectedLang: selectedLang,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        final isUrdu = selectedLang == "UR";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isUrdu ? "غلطی ہوئی ہے" : "Error occurred"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<bool> _onWillPop() async {
    await flutterTts.stop();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    return false;
  }

  void _goBackToLogin() {
    flutterTts.stop();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: true);
    final isDarkMode = themeProvider.isDarkMode;

    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;
    final isUrdu = selectedLang == "UR";

    // Theme-aware colors
    final backgroundColor = isDarkMode ? Colors.grey[900]! : Colors.transparent;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF646464);
    final secondaryTextColor = isDarkMode
        ? Colors.grey[400]!
        : const Color(0xFF8F8F8F);
    final dividerColor = isDarkMode
        ? Colors.grey[700]!
        : const Color(0xFFE9E9E9);
    final iconColor = isDarkMode ? Colors.grey[400]! : Colors.grey;
    final cardBackground = isDarkMode ? Colors.grey[800]! : Colors.white;
    final cardShadow = isDarkMode
        ? Colors.black.withOpacity(0.3)
        : Colors.black.withOpacity(0.1);
    final buttonDisabledColor = isDarkMode
        ? Colors.grey[700]!
        : const Color(0xFFE0E0E0);
    final buttonDisabledTextColor = isDarkMode
        ? Colors.grey[500]!
        : const Color(0xFF8A8A8A);
    final cropBorderColor = isDarkMode
        ? Colors.grey[600]!
        : const Color(0xFFDEE1E6);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: isDarkMode
              ? BoxDecoration(color: backgroundColor)
              : const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage("assets/images/box_decoration.png"),
                    fit: BoxFit.cover,
                  ),
                ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: w * 0.04),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: h * 0.02),

                          // HEADER ROW - WITHOUT DARK MODE ICON
                          Row(
                            children: [
                              GestureDetector(
                                onTap: _goBackToLogin,
                                child: Image.asset(
                                  'assets/images/logo_left.png',
                                  width: w * 0.08,
                                  height: w * 0.08,
                                  color: isDarkMode ? Colors.white : null,
                                ),
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
                              const Spacer(),
                              // REMOVED: Dark Mode Toggle Button from here
                              // Only speaker icon remains
                              GestureDetector(
                                onTap: _toggleHeaderSpeaker,
                                child: ColorFiltered(
                                  colorFilter: ColorFilter.mode(
                                    isSpeaking ? primaryColor : iconColor,
                                    BlendMode.srcIn,
                                  ),
                                  child: Icon(Icons.volume_up, size: w * 0.07),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: h * 0.02),
                          Container(height: 2, color: dividerColor),
                          SizedBox(height: h * 0.03),

                          // LANGUAGE TOGGLE
                          Container(
                            width: w * 0.40,
                            height: h * 0.065,
                            padding: EdgeInsets.symmetric(
                              horizontal: w * 0.015,
                            ),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.grey[700]!
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(w * 0.03),
                              border: Border.all(
                                color: isDarkMode
                                    ? Colors.grey[600]!
                                    : Colors.grey.shade200,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _onLanguageToggle("EN"),
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
                                    onTap: () => _onLanguageToggle("UR"),
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

                          // CROP SELECTION CARD
                          Container(
                            margin: EdgeInsets.symmetric(horizontal: w * 0.01),
                            padding: EdgeInsets.all(w * 0.04),
                            decoration: BoxDecoration(
                              color: cardBackground,
                              borderRadius: BorderRadius.circular(w * 0.03),
                              boxShadow: [
                                BoxShadow(
                                  color: cardShadow,
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: isUrdu
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isUrdu
                                      ? 'فصل منتخب کریں'
                                      : 'Select Your Crop',
                                  textDirection: isUrdu
                                      ? TextDirection.rtl
                                      : TextDirection.ltr,
                                  style: GoogleFonts.inter(
                                    color: textColor,
                                    fontSize: w * 0.045,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                SizedBox(height: h * 0.005),

                                Text(
                                  isUrdu
                                      ? 'مٹی کی نگرانی کے لیے کسی بھی فصل کا انتخاب کریں'
                                      : 'Choose any crop to proceed to soil monitoring:',
                                  textDirection: isUrdu
                                      ? TextDirection.rtl
                                      : TextDirection.ltr,
                                  style: GoogleFonts.inter(
                                    color: secondaryTextColor,
                                    fontSize: w * 0.036,
                                  ),
                                ),

                                SizedBox(height: h * 0.02),

                                // Crops Grid
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: crops.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                        childAspectRatio: 0.82,
                                      ),
                                  itemBuilder: (context, index) {
                                    final crop = crops[index];
                                    final isSelected =
                                        _selectedCrop == crop['name'];

                                    return GestureDetector(
                                      onTap: () => _selectCrop(crop['name']),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isDarkMode
                                              ? crop['darkColor']
                                              : crop['color'],
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? primaryColor
                                                : cropBorderColor,
                                            width: isSelected ? 3 : 2,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 70,
                                              height: 70,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isDarkMode
                                                    ? Colors.grey[700]
                                                    : Colors.white,
                                              ),
                                              child: ClipOval(
                                                child: Image.asset(
                                                  crop['imageUrl'],
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) {
                                                        return Icon(
                                                          Icons.grass,
                                                          size: 40,
                                                          color: primaryColor,
                                                        );
                                                      },
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              crop['name'],
                                              style: GoogleFonts.inter(
                                                color: isDarkMode
                                                    ? Colors.white
                                                    : textColor,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              crop['urduName'],
                                              style: GoogleFonts.inter(
                                                color: isDarkMode
                                                    ? Colors.grey[400]
                                                    : secondaryTextColor,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: h * 0.03),

                          // PROCEED BUTTON
                          Container(
                            margin: EdgeInsets.symmetric(horizontal: w * 0.01),
                            child: SizedBox(
                              width: w,
                              height: h * 0.07,
                              child: ElevatedButton(
                                onPressed: proceedEnabled && !_isSaving
                                    ? _proceedToDashboard
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: proceedEnabled
                                      ? primaryColor
                                      : buttonDisabledColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      w * 0.04,
                                    ),
                                  ),
                                  elevation: 2,
                                ),
                                child: _isSaving
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(
                                            proceedEnabled
                                                ? Colors.white
                                                : buttonDisabledTextColor,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        isUrdu
                                            ? 'مٹی کے ڈیش بورڈ پر جائیں'
                                            : 'Proceed to Soil Dashboard',
                                        style: GoogleFonts.inter(
                                          fontSize: w * 0.045,
                                          color: proceedEnabled
                                              ? Colors.white
                                              : buttonDisabledTextColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
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
        ),
      ),
    );
  }
}
