import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'chatboard.dart';
import 'login_screen.dart';
import 'weather.dart';
import '../services/service.dart';
import '../widgets/bottombar.dart';

//  Screens
import 'diseasedetectionscreen.dart';
import 'aiadvice.dart';
import 'userscreen.dart';
import '../state/themeprovier.dart';

class SoilDashboard extends StatefulWidget {
  final String selectedCrop;
  final String selectedLang;

  const SoilDashboard({
    super.key,
    required this.selectedCrop,
    required this.selectedLang,
  });

  @override
  State<SoilDashboard> createState() => _SoilDashboardState();
}

class _SoilDashboardState extends State<SoilDashboard> {
  int _selectedIndex = 0;
  late String selectedLang;
  late TTSService ttsService;
  bool _isSpeaking = false;
  bool _isFinishedSpeaking = false;

  // Sensor values
  String nitrogen = "--";
  String phosphorus = "--";
  String potassium = "--";
  String ph = "--";
  String temperature = "--";
  String moisture = "--";

  @override
  void initState() {
    super.initState();
    selectedLang = widget.selectedLang;
    ttsService = TTSService();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ttsService.setLanguage(selectedLang == "UR" ? "ur-PK" : "en-US");
    });

    _fetchLatestSensorData();
  }

  // SPEAK CONTENT
  Future<void> _speakScreenContent() async {
    if (_isSpeaking) {
      await ttsService.stop();
      setState(() {
        _isSpeaking = false;
        _isFinishedSpeaking = false;
      });
      return;
    }

    setState(() {
      _isSpeaking = true;
      _isFinishedSpeaking = false;
    });

    final englishNarration =
        """
Current soil health overview.
Nitrogen is $nitrogen.
Phosphorus is $phosphorus.
Potassium is $potassium.
pH level is $ph.
Temperature is $temperature.
Soil moisture is $moisture.
Use the bottom navigation to access other features.
""";

    final urduNarration =
        """
موجودہ مٹی کی صحت کا جائزہ۔
نائٹروجن $nitrogen ہے۔
فاسفورس $phosphorus ہے۔
پوٹاشیم $potassium ہے۔
پی ایچ $ph ہے۔
درجہ حرارت $temperature ہے۔
مٹی کی نمی $moisture ہے۔
دیگر خصوصیات تک رسائی کے لیے نیچے دیے گئے نیویگیشن کا استعمال کریں۔
""";

    if (selectedLang == "EN") {
      await ttsService.speak(englishNarration);
    } else {
      await ttsService.speak(urduNarration);
    }

    setState(() {
      _isSpeaking = false;
      _isFinishedSpeaking = true;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isFinishedSpeaking = false;
        });
      }
    });
  }

  // HEADER
  Widget _buildHeader(double width, bool isDarkMode) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: width * 0.07,
            vertical: width * 0.02,
          ),
          child: Row(
            children: [
              Image.asset(
                'assets/images/logo_left.png',
                width: width * 0.08,
                height: width * 0.08,
                color: isDarkMode ? Colors.white : null,
              ),
              SizedBox(width: width * 0.02),
              Text(
                "SmartAgri",
                style: GoogleFonts.inter(
                  fontSize: width * 0.055,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : const Color(0xFF595959),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),

        SizedBox(height: width * 0.02),
        Container(
          height: 2,
          color: isDarkMode ? Colors.grey[700]! : const Color(0xFFE9E9E9),
        ),
        SizedBox(height: width * 0.03),
      ],
    );
  }

  void _onLanguageToggle(String newLang) async {
    await ttsService.stop();
    setState(() {
      selectedLang = newLang;
      _isSpeaking = false;
      _isFinishedSpeaking = false;
    });
    await ttsService.setLanguage(newLang == "UR" ? "ur-PK" : "en-US");
  }

  // HANDLE BOTTOM NAVIGATION
  void _onNavItemTapped(int index) async {
    if (_isSpeaking) {
      await ttsService.stop();
      setState(() {
        _isSpeaking = false;
        _isFinishedSpeaking = false;
      });
    }

    setState(() => _selectedIndex = index);
  }

  // RETURN CURRENT SCREEN
  Widget _getCurrentScreen(bool isDarkMode) {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardScreen(isDarkMode);

      case 1:
        return DiseaseContent(selectedLang: selectedLang);

      case 2:
        return AIAdviceScreen(selectedLang: selectedLang);

      case 3:
        return WeatherContent(); // You need to import/create this

      case 4:
        return ChatBoard();

      case 5: // User is now at index 5
        return UserScreen();

      default:
        return _buildDashboardScreen(isDarkMode);
    }
  }

  // MAIN BUILD
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: true);
    final isDarkMode = themeProvider.isDarkMode;

    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return WillPopScope(
      onWillPop: () async {
        await ttsService.stop();

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );

        return false;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: isDarkMode ? Colors.grey[900]! : Colors.transparent,
        body: Container(
          width: width,
          height: height,
          decoration: isDarkMode
              ? BoxDecoration(color: Colors.grey[900]!)
              : const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage("assets/images/box_decoration.png"),
                    fit: BoxFit.cover,
                  ),
                ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(width, isDarkMode),

                // FIXED: NO SCROLLVIEW HERE
                Expanded(child: _getCurrentScreen(isDarkMode)),

                BottomNavBarWidget(
                  selectedIndex: _selectedIndex,
                  onTap: _onNavItemTapped,
                  selectedLang: selectedLang,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // DASHBOARD SCREEN
  Widget _buildDashboardScreen(bool isDarkMode) {
    final isUrdu = selectedLang == "UR";
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    // Theme-aware colors
    final backgroundColor = isDarkMode
        ? Colors.transparent
        : Colors.transparent;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF3F3F3F);
    final secondaryTextColor = isDarkMode
        ? Colors.grey[400]!
        : const Color(0xFF555555);
    final cardColor = isDarkMode ? Colors.grey[800]! : Colors.white;
    final cardBorderColor = isDarkMode
        ? Colors.grey[700]!
        : const Color(0xFFE0E0E0);
    final cardShadow = isDarkMode
        ? Colors.black.withOpacity(0.3)
        : Color.fromRGBO(0, 0, 0, 0.08);
    final languageBgColor = isDarkMode
        ? Colors.grey[700]!
        : Colors.grey.shade50;
    final languageBorderColor = isDarkMode
        ? Colors.grey[600]!
        : Colors.grey.shade200;
    final languageTextColor = isDarkMode
        ? Colors.grey[400]!
        : Colors.grey.shade700;
    final speakerBorderColor = isDarkMode
        ? Colors.grey[600]!
        : Colors.grey.shade200;
    final speakerActiveBg = isDarkMode
        ? const Color(0xFF21C357).withOpacity(0.1)
        : const Color.fromRGBO(34, 195, 88, 0.1);
    final primaryColor = const Color(0xFF21C357);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Container(
        color: backgroundColor,
        padding: EdgeInsets.symmetric(horizontal: width * 0.07),
        child: Column(
          crossAxisAlignment: isUrdu
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // LANGUAGE + SPEAKER
            Container(
              margin: EdgeInsets.only(bottom: height * 0.03),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Language Toggle
                  Container(
                    width: width * 0.40,
                    height: width * 0.12,
                    padding: EdgeInsets.symmetric(horizontal: width * 0.015),
                    decoration: BoxDecoration(
                      color: languageBgColor,
                      borderRadius: BorderRadius.circular(width * 0.03),
                      border: Border.all(color: languageBorderColor, width: 2),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _onLanguageToggle("EN"),
                            child: Container(
                              height: width * 0.07,
                              decoration: BoxDecoration(
                                color: selectedLang == "EN"
                                    ? primaryColor
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                  width * 0.03,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  "EN",
                                  style: GoogleFonts.inter(
                                    fontSize: width * 0.035,
                                    fontWeight: FontWeight.bold,
                                    color: selectedLang == "EN"
                                        ? Colors.white
                                        : languageTextColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: width * 0.02),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _onLanguageToggle("UR"),
                            child: Container(
                              height: width * 0.07,
                              decoration: BoxDecoration(
                                color: selectedLang == "UR"
                                    ? primaryColor
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                  width * 0.03,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  "اردو",
                                  textDirection: TextDirection.rtl,
                                  style: GoogleFonts.inter(
                                    fontSize: width * 0.037,
                                    fontWeight: FontWeight.bold,
                                    color: selectedLang == "UR"
                                        ? Colors.white
                                        : languageTextColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // SPEAKER BUTTON
                  GestureDetector(
                    onTap: _speakScreenContent,
                    child: Container(
                      width: width * 0.12,
                      height: width * 0.12,
                      decoration: BoxDecoration(
                        color: _isSpeaking ? speakerActiveBg : languageBgColor,
                        borderRadius: BorderRadius.circular(width * 0.03),
                        border: Border.all(
                          color: _isSpeaking
                              ? primaryColor
                              : speakerBorderColor,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/images/speaker.png',
                          width: width * 0.07,
                          color: _isSpeaking
                              ? primaryColor
                              : (isDarkMode ? Colors.grey[400] : null),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Text(
              isUrdu ? "مٹی کی صحت کا جائزہ" : "Soil Health Overview",
              style: GoogleFonts.inter(
                fontSize: width * 0.055,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),

            SizedBox(height: height * 0.03),

            _buildSoilMetricsGrid(
              isUrdu,
              width,
              isDarkMode,
              cardColor,
              cardBorderColor,
              cardShadow,
              textColor,
              secondaryTextColor,
            ),

            SizedBox(height: height * 0.04),
          ],
        ),
      ),
    );
  }

  Widget _buildSoilMetricsGrid(
    bool isUrdu,
    double width,
    bool isDarkMode,
    Color cardColor,
    Color cardBorderColor,
    Color cardShadow,
    Color textColor,
    Color secondaryTextColor,
  ) {
    final primaryColor = const Color(0xFF21C357);

    final metrics = [
      SoilMetric(
        isUrdu ? "نائٹروجن" : "Nitrogen",
        nitrogen,
        'assets/images/nitrogen.png',
      ),
      SoilMetric(
        isUrdu ? "فاسفورس" : "Phosphorus",
        phosphorus,
        'assets/images/phosphorus.png',
      ),
      SoilMetric(
        isUrdu ? "پوٹاشیم" : "Potassium",
        potassium,
        'assets/images/potassium.png',
      ),
      SoilMetric(isUrdu ? "پی ایچ" : "pH Level", ph, 'assets/images/ph.png'),
      SoilMetric(
        isUrdu ? "درجہ حرارت" : "Temperature",
        temperature,
        'assets/images/temprature.png',
      ),
      SoilMetric(
        isUrdu ? "نمی" : "Moisture",
        moisture,
        'assets/images/moisture.png',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: width * 0.04,
        mainAxisSpacing: width * 0.04,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) {
        return _buildMetricCard(
          metrics[index],
          isUrdu,
          width,
          isDarkMode,
          cardColor,
          cardBorderColor,
          cardShadow,
          textColor,
          secondaryTextColor,
          primaryColor,
        );
      },
    );
  }

  Widget _buildMetricCard(
    SoilMetric metric,
    bool isUrdu,
    double width,
    bool isDarkMode,
    Color cardColor,
    Color cardBorderColor,
    Color cardShadow,
    Color textColor,
    Color secondaryTextColor,
    Color primaryColor,
  ) {
    return GestureDetector(
      onTap: () async {
        if (_isSpeaking) {
          await ttsService.stop();
        }

        final message = isUrdu
            ? "${metric.title} ${metric.value} ہے"
            : "${metric.title} is ${metric.value}";

        await ttsService.speak(message);
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(width * 0.04),
          border: Border.all(color: cardBorderColor),
          boxShadow: [
            BoxShadow(
              color: cardShadow,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(width * 0.04),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // FIXED: No color filter on images - display original colors
              Container(
                width: width * 0.1,
                height: width * 0.1,
                child: Image.asset(
                  metric.icon,
                  // REMOVED: No color tint in dark mode
                  // color: isDarkMode ? Colors.white : null,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback icon if image fails to load
                    return Icon(
                      _getIconForMetric(metric.title),
                      size: width * 0.08,
                      color: primaryColor, // Keep fallback icons green
                    );
                  },
                ),
              ),
              SizedBox(height: width * 0.03),
              Text(
                metric.title,
                textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
                style: GoogleFonts.inter(
                  fontSize: width * 0.035,
                  fontWeight: FontWeight.w600,
                  color: secondaryTextColor,
                ),
              ),
              SizedBox(height: width * 0.01),
              Text(
                metric.value,
                textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
                style: GoogleFonts.inter(
                  fontSize: width * 0.045,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to get fallback icons
  IconData _getIconForMetric(String title) {
    switch (title.toLowerCase()) {
      case 'nitrogen':
      case 'نائٹروجن':
        return Icons.water_drop;
      case 'phosphorus':
      case 'فاسفورس':
        return Icons.waves;
      case 'potassium':
      case 'پوٹاشیم':
        return Icons.eco;
      case 'ph level':
      case 'پی ایچ':
        return Icons.bar_chart;
      case 'temperature':
      case 'درجہ حرارت':
        return Icons.thermostat;
      case 'moisture':
      case 'نمی':
        return Icons.opacity;
      default:
        return Icons.help_outline;
    }
  }

  Future<void> _fetchLatestSensorData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .collection("sensor_readings")
          .orderBy("timestamp", descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return;

      final data = snapshot.docs.first.data();

      setState(() {
        nitrogen = "${data['nitrogen'] ?? '--'} mg/kg";
        phosphorus = "${data['phosphorus'] ?? '--'} mg/kg";
        potassium = "${data['potassium'] ?? '--'} mg/kg";
        ph = "${data['ph'] ?? '--'}";
        temperature = "${data['temperature'] ?? '--'}°C";
        moisture = "${data['moisture'] ?? '--'}%";
      });
    } catch (e) {
      debugPrint("Error fetching sensor data: $e");
    }
  }

  @override
  void dispose() {
    ttsService.dispose();
    super.dispose();
  }
}

class SoilMetric {
  final String title;
  final String value;
  final String icon;

  // REMOVED: iconColor parameter since we don't need it anymore
  SoilMetric(this.title, this.value, this.icon);
}
