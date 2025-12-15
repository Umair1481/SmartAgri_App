import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart'; // ADD THIS FOR THEME DETECTION

// Firebase imports
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'crop_screen.dart';
import 'login_screen.dart';
import '../state/themeprovier.dart'; // ADD THIS FOR THEME PROVIDER

class HardwareInsertionScreen extends StatefulWidget {
  const HardwareInsertionScreen({super.key});

  @override
  State<HardwareInsertionScreen> createState() =>
      _HardwareInsertionScreenState();
}

class _HardwareInsertionScreenState extends State<HardwareInsertionScreen> {
  // ESP32 URL — CHANGE IP ONLY
  final String espUrl = "http://192.168.70.177/readings";

  // Connection states
  ConnectionStatus wifiStatus = ConnectionStatus.pending;
  ConnectionStatus stickStatus = ConnectionStatus.pending;
  ConnectionStatus calibrationStatus = ConnectionStatus.pending;

  String selectedLang = "EN";
  bool isSpeaking = false;
  bool instructionsCompleted = false;
  bool speakerActive = false;

  // TTS for Urdu instructions
  final FlutterTts flutterTts = FlutterTts();
  bool _urduInstructionsPlaying = false;

  // Last valid sensor reading
  Map<String, dynamic>? _sensorData;

  @override
  void initState() {
    super.initState();
    _setupTTS();
    // Start hardware check after a brief delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _simulateConnectionProcess();
    });
  }

  // =============================================================
  // Setup TTS for Urdu
  // =============================================================
  void _setupTTS() async {
    await flutterTts.setSpeechRate(0.4);
    await flutterTts.setVolume(1.0);
    await flutterTts.setLanguage("ur-PK");

    flutterTts.setCompletionHandler(() {
      print(" Urdu audio completed");
      setState(() {
        _urduInstructionsPlaying = false;
        speakerActive = false;
        instructionsCompleted = true;
        isSpeaking = false; // Stop header speaker too
      });
    });

    flutterTts.setCancelHandler(() {
      setState(() {
        _urduInstructionsPlaying = false;
        speakerActive = false;
      });
    });
  }

  // =============================================================
  // Screen Instructions Text in English and Urdu (without numbers)
  // =============================================================
  final String englishScreenInstructions = """
Welcome to the Hardware Insertion Screen.

Please follow these steps carefully.

First, watch the video demonstration or listen to Urdu instructions to learn how to insert the Smart Stick correctly.

Make sure all hardware connections are verified. This includes WiFi connection, Smart Stick detection, and Calibration.

Once all checks are completed and you have watched the instructions, the Proceed button will turn green.

Click the Proceed button to save your sensor data and move to crop selection.

The hardware verification includes three steps. WiFi Connection to connect to your ESP32 device. Smart Stick Detection to insert the stick into soil. And Calibration to wait for automatic calibration to complete.

When all checks are green and instructions are completed, you can proceed to the next step.
""";

  final String urduScreenInstructions = """
ہارڈ ویئر انسرشن اسکرین میں خوش آمدید۔

براہ کرم ان اقدامات پر احتیاط سے عمل کریں۔

پہلے، ویڈیو ڈیمو دیکھیں یا اردو ہدایات سنیں تاکہ سمجھ سکیں کہ اسمارٹ اسٹک کو صحیح طریقے سے کیسے لگانا ہے۔

یقینی بنائیں کہ تمام ہارڈ ویئر کنکشنز کی تصدیق ہو گئی ہے۔ اس میں وائی فائی کنکشن، اسمارٹ اسٹک ڈیٹیکشن، اور کیلیبریشن شامل ہیں۔

جب تمام چیک مکمل ہو جائیں اور آپ نے ہدایات دیکھ/سن لی ہوں، تو پراسیڈ بٹن سبز ہو جائے گا۔

اپنا سینسر ڈیٹا محفوظ کرنے اور فصل کے انتخاب پر جانے کے لیے پراسیڈ بٹن پر کلک کریں۔

ہارڈ ویئر تصدیق میں تین مراحل شامل ہیں۔ وائی فائی کنکشن آپ کے ESP32 ڈیوائس سے کنکٹ کرنے کے لیے۔ اسمارٹ اسٹک ڈیٹیکشن اسٹک کو مٹی میں لگانے کے لیے۔ اور کیلیبریشن خودکار کیلیبریشن مکمل ہونے کا انتظار کرنے کے لیے۔

جب تمام چیک سبز ہو جائیں اور ہدایات مکمل ہو جائیں، تو آپ اگلے مرحلے پر جا سکتے ہیں۔
""";

  // =============================================================
  // Urdu Instructions Text for Insertion Steps (without numbers)
  // =============================================================
  final String urduInsertionInstructions = """
اسمارٹ اسٹک کو مٹی میں لگانے کا طریقہ یہ ہے۔

پہلے اپنے کھیت کا وہ حصہ منتخب کریں جہاں آپ مٹی کا تجزیہ کرنا چاہتے ہیں۔

اسمارٹ اسٹک کو سیدھا پکڑیں اور مٹی میں دبائیں۔

اسٹک کو اس طرح داخل کریں کہ اس کا تقریباً تین چوتھائی حصہ مٹی میں چلا جائے۔

اسٹک کو ہلکے سے گھمائیں تاکہ یہ مٹی میں اچھی طرح فٹ ہو جائے۔

اسٹک کو تیس سیکنڈ تک مٹی میں رہنے دیں تاکہ وہ درست ریڈنگ لے سکے۔

احتیاط سے اسٹک کو باہر نکالیں اور اسے صاف کریں۔

اب آپ اپنے سینسر ریڈنگز دیکھ سکتے ہیں۔

تمام ہدایات مکمل ہو گئی ہیں۔ اب آپ فصل کے انتخاب کے لیے آگے بڑھ سکتے ہیں۔
""";

  // =============================================================
  // Header Speaker Function - Speaks ALL screen instructions
  // =============================================================
  void _toggleHeaderSpeaker() async {
    if (isSpeaking) {
      // Stop speaking if already speaking
      await flutterTts.stop();
      setState(() {
        isSpeaking = false;
      });
    } else {
      // Stop any ongoing speech first
      await flutterTts.stop();

      setState(() {
        isSpeaking = true;
        _urduInstructionsPlaying = false; // Stop Urdu insertion instructions
        speakerActive = false;
      });

      // Set language based on selected language
      if (selectedLang == "UR") {
        await flutterTts.setLanguage("ur-PK");
        await flutterTts.speak(urduScreenInstructions);
      } else {
        await flutterTts.setLanguage("en-US");
        await flutterTts.speak(englishScreenInstructions);
      }

      // When speech completes
      flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            isSpeaking = false;
          });
        }
      });
    }
  }

  // =============================================================
  // Urdu Insertion Instructions Playback
  // =============================================================
  void _playUrduInsertionInstructions() async {
    print(" Starting Urdu insertion instructions");
    setState(() {
      _urduInstructionsPlaying = true;
      speakerActive = true;
      instructionsCompleted = false;
      isSpeaking = false; // Stop header speaker if playing
    });

    await flutterTts.stop(); // Stop any ongoing speech
    await flutterTts.setLanguage("ur-PK");
    await flutterTts.speak(urduInsertionInstructions);
  }

  void _stopUrduInstructions() async {
    await flutterTts.stop();
    setState(() {
      _urduInstructionsPlaying = false;
      speakerActive = false;
    });
  }

  // =============================================================
  // Handle Android back button press
  // =============================================================
  Future<bool> _onWillPop() async {
    // Clean up resources
    await flutterTts.stop();
    setState(() {
      isSpeaking = false;
      _urduInstructionsPlaying = false;
      speakerActive = false;
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    return false;
  }

  // =============================================================
  // HELPER: CHECK IF READING IS VALID (ANY ONE > 0)
  // =============================================================
  bool _hasValidReading(Map<String, dynamic> data) {
    try {
      final num moist = (data["moisture"] ?? 0) is num
          ? data["moisture"]
          : num.tryParse(data["moisture"].toString()) ?? 0;
      final num n = (data["nitrogen"] ?? 0) is num
          ? data["nitrogen"]
          : num.tryParse(data["nitrogen"].toString()) ?? 0;
      final num p = (data["phosphorus"] ?? 0) is num
          ? data["phosphorus"]
          : num.tryParse(data["phosphorus"].toString()) ?? 0;
      final num k = (data["potassium"] ?? 0) is num
          ? data["potassium"]
          : num.tryParse(data["potassium"].toString()) ?? 0;

      // Valid if ANY one is above zero
      return moist > 0 || n > 0 || p > 0 || k > 0;
    } catch (e) {
      return false;
    }
  }

  // =============================================================
  // SAVE SENSOR DATA TO FIREBASE (ONLY CALLED ON PROCEED)
  // =============================================================
  Future<void> _saveSensorDataToFirebase() async {
    print(" Starting to save sensor data to Firebase...");

    if (_sensorData == null) {
      print(" No sensor data to save!");
      throw Exception("No sensor data available to save");
    }

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        print(" No user logged in! Cannot save sensor data.");
        throw Exception("No user logged in");
      }

      print(" Current user ID: ${user.uid}");
      print(" Sensor data to save: $_sensorData");

      // Save sensor data under the logged-in user's ID
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("sensor_readings")
          .add({
            "moisture": _sensorData!["moisture"] ?? 0,
            "temperature": _sensorData!["temperature"] ?? 0,
            "ph": _sensorData!["ph"] ?? 0,
            "nitrogen": _sensorData!["nitrogen"] ?? 0,
            "phosphorus": _sensorData!["phosphorus"] ?? 0,
            "potassium": _sensorData!["potassium"] ?? 0,
            "timestamp": DateTime.now().millisecondsSinceEpoch,
            "createdAt": FieldValue.serverTimestamp(),
            "user_id": user.uid, // Store user ID in the document too
          });

      print("✅🌿 Sensor data saved to Firebase!");
      print("📁 Path: users/${user.uid}/sensor_readings/");
    } catch (e) {
      print("🔥 Firebase Save Error: $e");
      throw e; // Re-throw to handle in calling function
    }
  }

  // =============================================================
  // REAL HARDWARE CHECK LOGIC
  // =============================================================
  void _simulateConnectionProcess() async {
    print("🔄 Starting hardware connection process...");
    // Reset all states
    setState(() {
      wifiStatus = ConnectionStatus.connecting;
      stickStatus = ConnectionStatus.pending;
      calibrationStatus = ConnectionStatus.pending;
      _sensorData = null;
    });

    // STEP 1: Check WiFi Connection (Check ESP32 URL)
    try {
      print("📡 Checking WiFi connection to ESP32...");
      final response = await http
          .get(Uri.parse(espUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        print("✅ WiFi connection successful");
        // WiFi connection successful
        setState(() {
          wifiStatus = ConnectionStatus.connected;
          stickStatus = ConnectionStatus.connecting;
        });

        // STEP 2: Check Smart Stick Detection
        final data = jsonDecode(response.body);
        print("📡 Received sensor data: $data");

        // Expecting keys: moisture, temperature, ph, nitrogen, phosphorus, potassium
        if (data is Map<String, dynamic> && data.containsKey("moisture")) {
          // Check if we have valid reading (at least one sensor > 0)
          if (_hasValidReading(data)) {
            print("✅ Smart Stick detected with valid readings");
            // Store sensor data IN MEMORY ONLY - will save to Firebase later
            _sensorData = data;

            // Smart stick detected
            setState(() {
              stickStatus = ConnectionStatus.connected;
              calibrationStatus = ConnectionStatus.connecting;
            });

            // STEP 3: Auto-calibration (simulated)
            print("⚙️ Starting calibration...");
            await Future.delayed(const Duration(seconds: 2));

            setState(() {
              calibrationStatus = ConnectionStatus.connected;
            });

            print("✅ All hardware checks completed!");
            return;
          } else {
            print("⚠️ Smart Stick detected but readings are all zero");
          }
        } else {
          print("❌ Smart Stick not detected or invalid data format");
        }
      } else {
        print("❌ WiFi connection failed with status: ${response.statusCode}");
      }

      // If we reach here, something failed
      _failConnection();
    } catch (e) {
      print("⚠ Error connecting to ESP32: $e");
      _failConnection();
    }
  }

  void _failConnection() {
    print("❌ Connection failed");
    setState(() {
      stickStatus = ConnectionStatus.pending;
      calibrationStatus = ConnectionStatus.pending;
      _sensorData = null;
    });
  }

  // Retry connection
  void _retryConnection() {
    print("🔄 Retrying connection...");
    _stopUrduInstructions();
    if (isSpeaking) {
      flutterTts.stop();
      setState(() {
        isSpeaking = false;
      });
    }
    _simulateConnectionProcess();
  }

  // Check if all hardware checks are completed
  bool _allChecksCompleted() {
    return wifiStatus == ConnectionStatus.connected &&
        stickStatus == ConnectionStatus.connected &&
        calibrationStatus == ConnectionStatus.connected;
  }

  // Check if proceed button should be enabled
  bool _isProceedEnabled() {
    return _allChecksCompleted() && instructionsCompleted;
  }

  // =============================================================
  // PROCEED TO CROP SELECTION - MAIN FUNCTION
  // =============================================================
  Future<void> _onProceedPressed() async {
    print("\n🚀🚀🚀 PROCEED BUTTON CLICKED 🚀🚀🚀");

    // Check if button should be enabled
    if (!_isProceedEnabled()) {
      print("❌ Button not enabled! Checks:");
      print("   - All hardware checks: ${_allChecksCompleted()}");
      print("   - Instructions completed: $instructionsCompleted");
      print(
        "   - Sensor data: ${_sensorData != null ? "Available" : "Not available"}",
      );
      return;
    }

    print("✅ Button is enabled, proceeding...");

    // Stop any ongoing speech
    await flutterTts.stop();
    setState(() {
      isSpeaking = false;
      _urduInstructionsPlaying = false;
      speakerActive = false;
    });

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      print("💾 Step 1: Saving sensor data to Firebase...");

      // SAVE TO FIREBASE FIRST
      await _saveSensorDataToFirebase();

      print("✅ Step 2: Sensor data saved successfully!");
      print("➡️ Step 3: Navigating to CropSelection screen...");

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // NAVIGATE TO NEXT SCREEN
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CropSelection()),
      );
    } catch (e) {
      print("🔥 ERROR in proceed process: $e");

      // Close loading dialog on error
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selectedLang == "UR" ? "غلطی ہوئی ہے: $e" : "Error: $e",
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Navigate back to login when logo is tapped
  void _goBackToLogin() {
    // Clean up resources
    flutterTts.stop();
    setState(() {
      isSpeaking = false;
      _urduInstructionsPlaying = false;
      speakerActive = false;
    });

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
    // ADD DARK MODE DETECTION
    final themeProvider = Provider.of<ThemeProvider>(context, listen: true);
    final isDarkMode = themeProvider.isDarkMode;

    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    final bool isUrdu = selectedLang == "UR";
    final bool proceedEnabled = _isProceedEnabled();

    // DARK MODE COLOR SETUP - FROM FIRST CODE
    final backgroundColor = isDarkMode ? Colors.grey[900]! : Colors.transparent;
    final primaryColor = const Color(0xFF21C357); // Changed from 0xFF22C358
    final textColor = isDarkMode ? Colors.white : const Color(0xFF595959);
    final secondaryTextColor = isDarkMode
        ? Colors.grey[400]!
        : const Color(0xFFB4B4B4);
    final dividerColor = isDarkMode
        ? Colors.grey[700]!
        : const Color(0xFFE9E9E9);
    final iconColor = isDarkMode ? Colors.grey[400]! : Colors.grey;
    final cardBackground = isDarkMode ? Colors.grey[800]! : Colors.white;
    final cardShadow = isDarkMode
        ? Colors.black.withOpacity(0.3)
        : Colors.black.withOpacity(0.1);
    final subtitleColor = isDarkMode
        ? Colors.grey[400]!
        : const Color(0xFFB4B4B4);
    final buttonTextColor = isDarkMode
        ? Colors.grey[300]!
        : const Color(0xFF8A8A8A);
    final buttonBorderColor = isDarkMode
        ? Colors.grey[700]!
        : const Color(0xFFE7E7E7);
    final videoBgColor = isDarkMode ? Colors.grey[700]! : Colors.grey.shade200;
    final statusBgColor = isDarkMode ? Colors.grey[700]! : Colors.grey.shade200;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          // CONDITIONAL BACKGROUND - FROM FIRST CODE
          decoration: isDarkMode
              ? BoxDecoration(color: backgroundColor)
              : const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/box_decoration.png'),
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
                      // WIDER PADDING - less horizontal padding for wider cards
                      padding: EdgeInsets.symmetric(horizontal: w * 0.04),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: h * 0.02),

                          // HEADER ROW - Same as login screen
                          Row(
                            children: [
                              // Logo is clickable to go back to login
                              GestureDetector(
                                onTap: _goBackToLogin,
                                child: Image.asset(
                                  'assets/images/logo_left.png',
                                  width: w * 0.08,
                                  height: w * 0.08,
                                  color: isDarkMode
                                      ? Colors.white
                                      : null, // ADD COLOR FILTER FOR DARK MODE
                                ),
                              ),
                              SizedBox(width: w * 0.02),
                              Text(
                                "SmartAgri",
                                style: GoogleFonts.inter(
                                  fontSize: w * 0.055,
                                  fontWeight: FontWeight.bold,
                                  color: textColor, // USE DARK MODE COLOR
                                ),
                              ),
                              const Spacer(),
                              // Header speaker - speaks ALL screen instructions
                              // Turns grey when instructions are completed
                              GestureDetector(
                                onTap: instructionsCompleted
                                    ? null
                                    : _toggleHeaderSpeaker,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  child: ColorFiltered(
                                    colorFilter: ColorFilter.mode(
                                      // UPDATED FOR DARK MODE
                                      instructionsCompleted
                                          ? iconColor // USE DARK MODE ICON COLOR
                                          : (isSpeaking
                                                ? primaryColor
                                                : iconColor), // USE DARK MODE ICON COLOR
                                      BlendMode.srcIn,
                                    ),
                                    child: Icon(
                                      Icons.volume_up,
                                      size: w * 0.07,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: h * 0.02),
                          Container(
                            height: 2,
                            color: dividerColor,
                          ), // USE DARK MODE COLOR
                          SizedBox(height: h * 0.03),

                          // LANGUAGE TOGGLE - Below header, same as login screen
                          Container(
                            width: w * 0.40,
                            height: h * 0.065,
                            padding: EdgeInsets.symmetric(
                              horizontal: w * 0.015,
                            ),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.grey[700]! // DARK MODE BACKGROUND
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(w * 0.03),
                              border: Border.all(
                                color: isDarkMode
                                    ? Colors.grey[600]! // DARK MODE BORDER
                                    : Colors.grey.shade200,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedLang = "EN";
                                      });
                                    },
                                    child: Container(
                                      height: h * 0.045,
                                      decoration: BoxDecoration(
                                        color: selectedLang == "EN"
                                            ? primaryColor
                                            : Colors
                                                  .transparent, // CHANGED FROM grey.shade200
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
                                                ? Colors
                                                      .grey[400]! // DARK MODE COLOR
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
                                      setState(() {
                                        selectedLang = "UR";
                                      });
                                    },
                                    child: Container(
                                      height: h * 0.045,
                                      decoration: BoxDecoration(
                                        color: selectedLang == "UR"
                                            ? primaryColor
                                            : Colors
                                                  .transparent, // CHANGED FROM grey.shade200
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
                                                ? Colors
                                                      .grey[400]! // DARK MODE COLOR
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

                          // Main content - Instruction Card (WIDER) with integrated video
                          _InstructionCard(
                            isUrdu: isUrdu,
                            onPlayUrduAudio: _urduInstructionsPlaying
                                ? _stopUrduInstructions
                                : _playUrduInsertionInstructions,
                            onVideoCompleted: () {
                              print(
                                "✅ Video completed callback received in parent",
                              );
                              setState(() {
                                instructionsCompleted = true;
                                isSpeaking = false; // Stop header speaker
                              });
                              // Stop any ongoing speech when video completes
                              flutterTts.stop();
                            },
                            isDarkMode: isDarkMode,
                            primaryColor: primaryColor,
                            textColor: textColor,
                            subtitleColor: subtitleColor,
                            cardBackground: cardBackground,
                            cardShadow: cardShadow,
                            videoBgColor: videoBgColor,
                            buttonTextColor: buttonTextColor,
                            buttonBorderColor: buttonBorderColor,
                          ),

                          SizedBox(height: h * 0.03),

                          // Verification Status Card (WIDER)
                          _VerificationStatusCard(
                            wifiStatus: wifiStatus,
                            stickStatus: stickStatus,
                            calibrationStatus: calibrationStatus,
                            onRetry: _retryConnection,
                            allChecksCompleted: _allChecksCompleted(),
                            isUrdu: isUrdu,
                            isDarkMode: isDarkMode,
                            primaryColor: primaryColor,
                            textColor: textColor,
                            cardBackground: cardBackground,
                            cardShadow: cardShadow,
                            iconColor: isDarkMode
                                ? Colors.grey[400]!
                                : Colors.grey.shade700,
                            statusBgColor: statusBgColor,
                          ),

                          SizedBox(height: h * 0.03),

                          // PROCEED BUTTON - Turns green only when ALL checks are done
                          Container(
                            margin: EdgeInsets.symmetric(horizontal: w * 0.01),
                            child: SizedBox(
                              width: w,
                              height: h * 0.07,
                              child: ElevatedButton(
                                onPressed: proceedEnabled
                                    ? _onProceedPressed
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: proceedEnabled
                                      ? primaryColor // Green when enabled - USE DARK MODE PRIMARY
                                      : isDarkMode
                                      ? Colors.grey[700]! // DARK MODE DISABLED
                                      : Colors
                                            .grey
                                            .shade300, // LIGHT MODE DISABLED
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      w * 0.04,
                                    ),
                                  ),
                                  elevation:
                                      2, // ADDED ELEVATION FROM FIRST CODE
                                ),
                                child: Text(
                                  isUrdu
                                      ? "فصل کے انتخاب کی طرف بڑھیں"
                                      : "Proceed to Crop Selection",
                                  style: GoogleFonts.inter(
                                    fontSize: w * 0.045,
                                    color: proceedEnabled
                                        ? Colors
                                              .white // White text when green button
                                        : isDarkMode
                                        ? Colors
                                              .grey[400]! // DARK MODE DISABLED TEXT
                                        : Colors
                                              .grey
                                              .shade700, // LIGHT MODE DISABLED TEXT
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

// ========================================================
// INSTRUCTION CARD WITH VIDEO (INTEGRATED VERSION)
// ========================================================
class _InstructionCard extends StatefulWidget {
  final bool isUrdu;
  final VoidCallback onPlayUrduAudio;
  final VoidCallback onVideoCompleted;
  final bool isDarkMode; // ADDED
  final Color primaryColor; // ADDED
  final Color textColor; // ADDED
  final Color subtitleColor; // ADDED
  final Color cardBackground; // ADDED
  final Color cardShadow; // ADDED
  final Color videoBgColor; // ADDED
  final Color buttonTextColor; // ADDED
  final Color buttonBorderColor; // ADDED

  const _InstructionCard({
    required this.isUrdu,
    required this.onPlayUrduAudio,
    required this.onVideoCompleted,
    required this.isDarkMode, // ADDED
    required this.primaryColor, // ADDED
    required this.textColor, // ADDED
    required this.subtitleColor, // ADDED
    required this.cardBackground, // ADDED
    required this.cardShadow, // ADDED
    required this.videoBgColor, // ADDED
    required this.buttonTextColor, // ADDED
    required this.buttonBorderColor, // ADDED
  });

  @override
  State<_InstructionCard> createState() => __InstructionCardState();
}

class __InstructionCardState extends State<_InstructionCard> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;
  bool _videoReady = false;
  bool _videoError = false;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();

    // Initialize the video controller
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      print("🎬 Initializing video...");
      // Try multiple possible paths - adjust based on  actual file location
      List<String> possiblePaths = [
        "assets/videos/insertion_demo.mp4", //  original path
        "assets/videos/insertion.mp4", // From new code
        "assets/insertion.mp4", // Alternative
        "assets/video/insertion.mp4", // Another alternative
      ];

      VideoPlayerController? tempController;

      for (var path in possiblePaths) {
        try {
          print("📁 Trying video path: $path");
          tempController = VideoPlayerController.asset(path);
          await tempController.initialize();

          // If successful, use this controller
          _controller = tempController;
          print("✅ Video initialized successfully from: $path");
          break;
        } catch (e) {
          print("❌ Failed to load video from $path: $e");
          if (tempController != null) {
            tempController.dispose();
          }
        }
      }

      if (!_controller.value.isInitialized) {
        throw Exception("Could not initialize video from any path");
      }

      // Listen for video completion
      _controller.addListener(() {
        if (_controller.value.position >= _controller.value.duration &&
            !_controller.value.isLooping &&
            _controller.value.isPlaying) {
          print("✅ Video playback completed");
          setState(() => _isPlaying = false);
          _controller.pause();
          _controller.seekTo(Duration.zero);
          // Call the parent callback
          widget.onVideoCompleted();
        }
      });

      setState(() {
        _videoReady = true;
        _videoError = false;
      });
    } catch (e) {
      print("🔥 Video initialization error: $e");
      setState(() {
        _videoReady = false;
        _videoError = true;
        _errorMessage = widget.isUrdu
            ? "ویڈیو دستیاب نہیں"
            : "Video not available";
      });
    }
  }

  void _playVideo() {
    if (!_videoReady || _videoError) {
      print("❌ Cannot play video: Not ready or error");
      // If video failed to load, show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    print("▶️ Playing video");
    setState(() => _isPlaying = true);
    _controller.seekTo(Duration.zero);
    _controller.play();
  }

  void _pauseVideo() {
    if (_videoReady && _isPlaying) {
      print("⏸️ Pausing video");
      setState(() => _isPlaying = false);
      _controller.pause();
    }
  }

  @override
  void dispose() {
    if (_videoReady) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    return Container(
      // WIDER CARD - less horizontal padding for wider appearance
      margin: EdgeInsets.symmetric(horizontal: w * 0.01),
      padding: EdgeInsets.all(w * 0.04),
      decoration: BoxDecoration(
        color: widget.cardBackground, // USE DARK MODE COLOR
        borderRadius: BorderRadius.circular(w * 0.03),
        boxShadow: [
          BoxShadow(
            color: widget.cardShadow, // USE DARK MODE COLOR
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isUrdu
                ? "اسمارٹ اسٹک لگانے کا طریقہ"
                : "How to Insert the Smart Stick",
            style: GoogleFonts.inter(
              fontSize: w * 0.045,
              fontWeight: FontWeight.bold,
              color: widget.textColor, // USE DARK MODE COLOR
            ),
          ),
          SizedBox(height: h * 0.01),
          Text(
            widget.isUrdu
                ? "مٹی میں اسمارٹ اسٹک درست طریقے سے لگانے کے لیے ان ہدایات پر عمل کریں۔"
                : "Follow these steps to correctly insert your SmartAgri stick.",
            style: GoogleFonts.inter(
              fontSize: w * 0.038,
              color: widget.subtitleColor, // USE DARK MODE COLOR
            ),
          ),

          SizedBox(height: h * 0.03),

          // Video Player Container with Thumbnail/Playback
          Container(
            height: h * 0.25,
            decoration: BoxDecoration(
              color: widget.videoBgColor, // USE DARK MODE COLOR
              borderRadius: BorderRadius.circular(w * 0.02),
              boxShadow: [
                BoxShadow(color: widget.cardShadow, blurRadius: 5),
              ], // USE DARK MODE COLOR
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(w * 0.02),
              child: _isPlaying && _videoReady && !_videoError
                  ? Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: _controller.value.aspectRatio,
                          child: VideoPlayer(_controller),
                        ),
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: FloatingActionButton(
                            mini: true,
                            backgroundColor: Colors.black54,
                            onPressed: _pauseVideo,
                            child: const Icon(Icons.pause, color: Colors.white),
                          ),
                        ),
                      ],
                    )
                  : GestureDetector(
                      onTap: _playVideo,
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: widget.videoBgColor, // USE DARK MODE COLOR
                          image: _videoError
                              ? null
                              : const DecorationImage(
                                  image: AssetImage(
                                    "assets/images/thumbnail.png",
                                  ),
                                  fit: BoxFit.cover,
                                ),
                        ),
                        child: Center(
                          child: _videoError
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                      size: 40,
                                    ),
                                    SizedBox(height: h * 0.01),
                                    Text(
                                      _errorMessage,
                                      style: GoogleFonts.inter(
                                        color: widget
                                            .subtitleColor, // USE DARK MODE COLOR
                                        fontSize: w * 0.035,
                                      ),
                                    ),
                                  ],
                                )
                              : _videoReady
                              ? Container(
                                  width: w * 0.15,
                                  height: w * 0.15,
                                  decoration: BoxDecoration(
                                    color: widget.primaryColor.withOpacity(
                                      0.9,
                                    ), // USE DARK MODE COLOR
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.play_arrow,
                                    size: w * 0.08,
                                    color: Colors.white,
                                  ),
                                )
                              : CircularProgressIndicator(
                                  color: widget
                                      .primaryColor, // USE DARK MODE COLOR
                                ),
                        ),
                      ),
                    ),
            ),
          ),

          SizedBox(height: h * 0.03),

          // Buttons Row
          Row(
            children: [
              Expanded(
                child: _CustomButton(
                  onPressed: _playVideo,
                  text: _isPlaying
                      ? (widget.isUrdu ? "ویڈیو روکیں" : "Pause Video")
                      : (widget.isUrdu
                            ? "ویڈیو ڈیمو دیکھیں"
                            : "Watch Video Demo"),
                  backgroundColor: _isPlaying
                      ? Colors.orange.shade400
                      : widget.primaryColor, // USE DARK MODE COLOR
                  textColor: Colors.white,
                  icon: _isPlaying ? Icons.pause : Icons.play_arrow_rounded,
                ),
              ),
              SizedBox(width: w * 0.03),
              Expanded(
                child: _CustomButton(
                  onPressed: widget.onPlayUrduAudio,
                  text: widget.isUrdu ? "اردو میں سنیں" : "Listen in Urdu",
                  backgroundColor: widget.cardBackground, // USE DARK MODE COLOR
                  textColor: widget.buttonTextColor, // USE DARK MODE COLOR
                  borderColor: widget.buttonBorderColor, // USE DARK MODE COLOR
                  icon: Icons.volume_up_rounded,
                ),
              ),
            ],
          ),

          // Status indicator (when video is not playing and ready)
          if (!_isPlaying && _videoReady && !_videoError)
            Padding(
              padding: EdgeInsets.only(top: h * 0.02),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: w * 0.04),
                  SizedBox(width: w * 0.02),
                  Text(
                    widget.isUrdu
                        ? "ہدایات مکمل ہو گئی ہیں"
                        : "Instructions completed",
                    style: GoogleFonts.inter(
                      fontSize: w * 0.035,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ========================================================
// VERIFICATION STATUS CARD - WIDER VERSION
// ========================================================
class _VerificationStatusCard extends StatelessWidget {
  final ConnectionStatus wifiStatus;
  final ConnectionStatus stickStatus;
  final ConnectionStatus calibrationStatus;
  final VoidCallback onRetry;
  final bool allChecksCompleted;
  final bool isUrdu;
  final bool isDarkMode; // ADDED
  final Color primaryColor; // ADDED
  final Color textColor; // ADDED
  final Color cardBackground; // ADDED
  final Color cardShadow; // ADDED
  final Color iconColor; // ADDED
  final Color statusBgColor; // ADDED

  const _VerificationStatusCard({
    required this.wifiStatus,
    required this.stickStatus,
    required this.calibrationStatus,
    required this.onRetry,
    required this.allChecksCompleted,
    required this.isUrdu,
    required this.isDarkMode, // ADDED
    required this.primaryColor, // ADDED
    required this.textColor, // ADDED
    required this.cardBackground, // ADDED
    required this.cardShadow, // ADDED
    required this.iconColor, // ADDED
    required this.statusBgColor, // ADDED
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    return Container(
      // WIDER CARD - less horizontal margin
      margin: EdgeInsets.symmetric(horizontal: w * 0.01),
      padding: EdgeInsets.all(w * 0.04),
      decoration: BoxDecoration(
        color: cardBackground, // USE DARK MODE COLOR
        borderRadius: BorderRadius.circular(w * 0.03),
        boxShadow: [
          BoxShadow(color: cardShadow, blurRadius: 8),
        ], // USE DARK MODE COLOR
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isUrdu ? "ہارڈویئر کی تصدیق" : "Hardware Verification",
                  style: GoogleFonts.inter(
                    fontSize: w * 0.045,
                    fontWeight: FontWeight.bold,
                    color: textColor, // USE DARK MODE COLOR
                  ),
                ),
              ),
              if (!allChecksCompleted)
                TextButton.icon(
                  onPressed: onRetry,
                  icon: Icon(
                    Icons.refresh,
                    size: 16,
                    color: primaryColor,
                  ), // USE DARK MODE COLOR
                  label: Text(
                    isUrdu ? "دوبارہ کوشش کریں" : "Retry",
                    style: TextStyle(
                      color: primaryColor,
                    ), // USE DARK MODE COLOR
                  ),
                ),
            ],
          ),

          SizedBox(height: h * 0.02),

          _statusItem(
            icon: Icons.wifi_rounded,
            text: isUrdu ? "وائی فائی کنکشن" : "WiFi Connection",
            status: wifiStatus,
            w: w,
            iconColor: iconColor, // USE DARK MODE COLOR
            statusBgColor: statusBgColor, // USE DARK MODE COLOR
            textColor: textColor, // USE DARK MODE COLOR
          ),

          SizedBox(height: h * 0.03),

          _statusItem(
            icon: Icons.usb_rounded,
            text: isUrdu ? "اسمارٹ اسٹک" : "Smart Stick Detection",
            status: stickStatus,
            w: w,
            iconColor: iconColor, // USE DARK MODE COLOR
            statusBgColor: statusBgColor, // USE DARK MODE COLOR
            textColor: textColor, // USE DARK MODE COLOR
          ),

          SizedBox(height: h * 0.03),

          _statusItem(
            icon: Icons.tune_rounded,
            text: isUrdu ? "کیلی بریشن" : "Calibration",
            status: calibrationStatus,
            w: w,
            iconColor: iconColor, // USE DARK MODE COLOR
            statusBgColor: statusBgColor, // USE DARK MODE COLOR
            textColor: textColor, // USE DARK MODE COLOR
          ),

          if (allChecksCompleted) ...[
            SizedBox(height: h * 0.03),
            Container(
              padding: EdgeInsets.all(w * 0.03),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.green[900]!.withOpacity(0.3) // DARK MODE
                    : const Color(0xFFE8F5E8), // LIGHT MODE
                borderRadius: BorderRadius.circular(w * 0.02),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: primaryColor,
                  ), // USE DARK MODE COLOR
                  SizedBox(width: w * 0.03),
                  Expanded(
                    child: Text(
                      isUrdu
                          ? "تمام سسٹمز تیار ہیں!"
                          : "All systems are ready!",
                      style: GoogleFonts.inter(
                        color: primaryColor, // USE DARK MODE COLOR
                        fontSize: w * 0.038,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusItem({
    required IconData icon,
    required String text,
    required ConnectionStatus status,
    required double w,
    required Color iconColor, // ADDED
    required Color statusBgColor, // ADDED
    required Color textColor, // ADDED
  }) {
    return Row(
      children: [
        Container(
          width: w * 0.09,
          height: w * 0.09,
          decoration: BoxDecoration(
            color: statusBgColor, // USE DARK MODE COLOR
            borderRadius: BorderRadius.circular(w * 0.02),
          ),
          child: Icon(icon, color: iconColor), // USE DARK MODE COLOR
        ),
        SizedBox(width: w * 0.04),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: w * 0.04,
              fontWeight: FontWeight.w600,
              color: textColor, // USE DARK MODE COLOR
            ),
          ),
        ),
        Text(
          status == ConnectionStatus.connected
              ? "Connected"
              : status == ConnectionStatus.connecting
              ? "Connecting"
              : "Pending",
          style: GoogleFonts.inter(
            color: status.color,
            fontSize: w * 0.035,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(width: w * 0.02),
        Icon(status.icon, color: status.color, size: w * 0.05),
      ],
    );
  }
}

// ========================================================
// CUSTOM BUTTON
// ========================================================
class _CustomButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final IconData? icon;

  const _CustomButton({
    required this.onPressed,
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        padding: EdgeInsets.symmetric(vertical: h * 0.02),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(w * 0.02),
          side: borderColor != null
              ? BorderSide(color: borderColor!)
              : BorderSide.none,
        ),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: w * 0.05, color: textColor),
            SizedBox(width: w * 0.02),
          ],
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: w * 0.038,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ========================================================
// ENUM FOR STATUS
// ========================================================
enum ConnectionStatus {
  connected,
  connecting,
  pending;

  Color get color {
    switch (this) {
      case ConnectionStatus.connected:
        return const Color(0xFF21C357); // UPDATED TO MATCH PRIMARY COLOR
      case ConnectionStatus.connecting:
        return const Color(0xFFB1B1B1);
      case ConnectionStatus.pending:
        return const Color(0xFFB4B4B4);
    }
  }

  IconData get icon {
    switch (this) {
      case ConnectionStatus.connected:
        return Icons.check_circle;
      case ConnectionStatus.connecting:
        return Icons.sync;
      case ConnectionStatus.pending:
        return Icons.schedule;
    }
  }
}
