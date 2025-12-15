import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:smartagriapp/services/service.dart';
import '../state/themeprovier.dart';

class AIAdviceScreen extends StatefulWidget {
  final String? selectedCrop;
  final String? selectedLang;

  const AIAdviceScreen({super.key, this.selectedCrop, this.selectedLang});

  @override
  State<AIAdviceScreen> createState() => _AIAdviceScreenState();
}

class _AIAdviceScreenState extends State<AIAdviceScreen> {
  late String selectedLang;
  late TTSService ttsService;
  bool _isSpeaking = false;
  bool _isFinishedSpeaking = false;

  bool _isLoading = false;

  // Store sensor values
  Map<String, dynamic> _sensorData = {
    'crop_name': '',
    'temperature': 0.0,
    'moisture': 0.0,
    'ph': 0.0,
    'nitrogen': 0,
    'phosphorus': 0,
    'potassium': 0,
    'timestamp': null,
  };

  Map<String, dynamic>? _apiResponse;
  String _errorMessage = '';

  // Store API response NPK values
  Map<String, dynamic> _apiFinalNPK = {'N': 0.0, 'P': 0.0, 'K': 0.0};

  // Fertilizer recommendations
  List<Map<String, dynamic>> _fertilizerRecommendations = [];

  static const String _apiUrl = 'https://npkmodel.ngrok.io/predict/';

  @override
  void initState() {
    super.initState();
    selectedLang = widget.selectedLang ?? 'EN';
    ttsService = TTSService();
    _isSpeaking = false;
    _isFinishedSpeaking = false;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ttsService.setLanguage(selectedLang == "UR" ? "ur-PK" : "en-US");
    });

    _getLatestSensorData();
  }

  Future<void> _speakScreenContent() async {
    if (_isSpeaking) {
      await ttsService.stop();
      setState(() {
        _isSpeaking = false;
        _isFinishedSpeaking = false;
      });
      return;
    }

    if (_isFinishedSpeaking) {
      _isFinishedSpeaking = false;
    }

    setState(() {
      _isSpeaking = true;
      _isFinishedSpeaking = false;
    });

    String narration = "";
    if (selectedLang == "EN") {
      narration =
          """
AI Agriculture Advice Screen.
Current crop: ${_sensorData['crop_name']}.
${_fertilizerRecommendations.isNotEmpty ? "Fertilizer recommendations available." : "Getting analysis from server..."}
Original values: Nitrogen ${_sensorData['nitrogen']}, Phosphorus ${_sensorData['phosphorus']}, Potassium ${_sensorData['potassium']}.
Required values: Nitrogen ${_apiFinalNPK['N']?.toStringAsFixed(1) ?? '0'}, Phosphorus ${_apiFinalNPK['P']?.toStringAsFixed(1) ?? '0'}, Potassium ${_apiFinalNPK['K']?.toStringAsFixed(1) ?? '0'}.
""";
    } else {
      narration =
          """
مصنوعی ذہانت کی زرعی رائے کا اسکرین۔
موجودہ فصل: ${_sensorData['crop_name']}۔
${_fertilizerRecommendations.isNotEmpty ? "کھاد کی سفارشات دستیاب ہیں۔" : "سرور سے تجزیہ حاصل کیا جا رہا ہے..."}
اصل قدریں: نائٹروجن ${_sensorData['nitrogen']}، فاسفورس ${_sensorData['phosphorus']}، پوٹاشیم ${_sensorData['potassium']}۔
مطلوبہ قدریں: نائٹروجن ${_apiFinalNPK['N']?.toStringAsFixed(1) ?? '0'}، فاسفورس ${_apiFinalNPK['P']?.toStringAsFixed(1) ?? '0'}، پوٹاشیم ${_apiFinalNPK['K']?.toStringAsFixed(1) ?? '0'}۔
""";
    }

    await ttsService.speak(
      narration,
      langCode: selectedLang == "UR" ? "ur-PK" : "en-US",
    );

    final wordCount = narration.split(' ').length;
    final estimatedDuration = Duration(
      milliseconds: (wordCount / 150 * 60 * 1000).round(),
    );
    final totalDuration = estimatedDuration + const Duration(milliseconds: 500);

    Future.delayed(totalDuration, () {
      if (mounted && _isSpeaking) {
        setState(() {
          _isSpeaking = false;
          _isFinishedSpeaking = true;
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() {
                _isFinishedSpeaking = false;
              });
            }
          });
        });
      }
    });
  }

  void _updateLanguage(String newLang) async {
    await ttsService.stop();
    setState(() {
      selectedLang = newLang;
      _isSpeaking = false;
      _isFinishedSpeaking = false;
    });
    await ttsService.setLanguage(newLang == "UR" ? "ur-PK" : "en-US");
  }

  // -----------------------------------------------------------
  // FETCH LATEST SENSOR DATA
  // -----------------------------------------------------------
  Future<void> _getLatestSensorData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _apiResponse = null;
      _apiFinalNPK = {'N': 0.0, 'P': 0.0, 'K': 0.0};
      _fertilizerRecommendations.clear();
    });

    ttsService.stop();

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw Exception('User not logged in');
      }

      debugPrint(' Current User ID: $uid');

      // Try multiple paths
      QuerySnapshot? snapshot;

      // PATH 1: users/{uid}/sensor_readings
      try {
        snapshot = await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .collection("sensor_readings")
            .orderBy("timestamp", descending: true)
            .limit(1)
            .get();
      } catch (e) {
        debugPrint(' Path 1 failed: $e');
      }

      // PATH 2: sensor_readings with user filter
      if (snapshot == null || snapshot.docs.isEmpty) {
        try {
          snapshot = await FirebaseFirestore.instance
              .collection("sensor_readings")
              .where("user_id", isEqualTo: uid)
              .orderBy("timestamp", descending: true)
              .limit(1)
              .get();
        } catch (e) {
          debugPrint(' Path 2 failed: $e');
        }
      }

      if (snapshot == null || snapshot.docs.isEmpty) {
        throw Exception('No sensor data available for this user');
      }

      final doc = snapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>;

      // Store values
      setState(() {
        _sensorData = {
          'crop_name': data['crop_name']?.toString() ?? 'Unknown',
          'temperature': _parseDouble(data['temperature']),
          'moisture': _parseDouble(data['moisture']),
          'ph': _parseDouble(data['ph']),
          'nitrogen': _parseInt(data['nitrogen']),
          'phosphorus': _parseInt(data['phosphorus']),
          'potassium': _parseInt(data['potassium']),
          'timestamp': data['timestamp'],
        };
      });

      debugPrint('\n SENSOR DATA COLLECTED:');
      debugPrint('Crop: ${_sensorData['crop_name']}');
      debugPrint(
        'NPK: N=${_sensorData['nitrogen']}, P=${_sensorData['phosphorus']}, K=${_sensorData['potassium']}',
      );

      // Prepare and send to API
      await _prepareAndSendToAPI();
    } catch (e) {
      debugPrint(" Error getting sensor data: $e");
      setState(() {
        _errorMessage = selectedLang == "UR"
            ? 'سینسر ڈیٹا حاصل کرنے میں ناکام: $e'
            : 'Failed to get sensor data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // -----------------------------------------------------------
  // PREPARE AND SEND TO API
  // -----------------------------------------------------------
  Future<void> _prepareAndSendToAPI() async {
    try {
      final cropName = _sensorData['crop_name']?.toString();
      final cropTypeToSend = (cropName?.trim() ?? 'wheat').toLowerCase();

      debugPrint(' Crop name for API: $cropTypeToSend');

      final jsonData = {
        "temperature": _sensorData['temperature'],
        "humidity": 75.0,
        "moisture": _sensorData['moisture'],
        "ph": _sensorData['ph'],
        "crop_type": cropTypeToSend,
        "N": _sensorData['nitrogen'],
        "P": _sensorData['phosphorus'],
        "K": _sensorData['potassium'],
      };

      debugPrint(' Sending to API:');
      debugPrint(jsonEncode(jsonData));

      await _sendToAPI(jsonData);
    } catch (e) {
      debugPrint(' Error preparing API request: $e');
      setState(() {
        _apiResponse = {
          'status': 'error',
          'display_text': selectedLang == "UR"
              ? 'API درخواست تیار کرنے میں ناکام: $e'
              : 'Failed to prepare API request: $e',
        };
      });
    }
  }

  Future<void> _sendToAPI(Map<String, dynamic> jsonData) async {
    try {
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(jsonData),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint(' API Response Status: ${response.statusCode}');
      debugPrint('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Extract N_final, P_final, K_final from response
        final apiN = _parseDouble(responseData['N_final']);
        final apiP = _parseDouble(responseData['P_final']);
        final apiK = _parseDouble(responseData['K_final']);

        setState(() {
          _apiFinalNPK = {'N': apiN, 'P': apiP, 'K': apiK};

          // Generate fertilizer recommendations
          _fertilizerRecommendations = _generateRecommendations(
            _sensorData['nitrogen'],
            _sensorData['phosphorus'],
            _sensorData['potassium'],
            apiN,
            apiP,
            apiK,
          );

          _apiResponse = {
            'status': 'success',
            'raw_result': response.body,
            'status_code': response.statusCode,
            'display_text': selectedLang == "UR"
                ? 'AI تجزیہ مکمل: مقامی معیار کے مطابق تبدیلی کی گئی ہے۔'
                : 'AI analysis complete: Converted to local soil standards.',
            'api_final_npk': _apiFinalNPK,
            'recommendations': _fertilizerRecommendations,
            'conversion': responseData['conversion_applied'],
          };
        });
      } else {
        setState(() {
          _apiResponse = {
            'status': 'error',
            'raw_result': response.body,
            'status_code': response.statusCode,
            'display_text': selectedLang == "UR"
                ? 'سرور سے خرابی: ${response.statusCode}\n\n${response.body}'
                : 'Server Error: ${response.statusCode}\n\n${response.body}',
          };
        });
      }
    } catch (e) {
      debugPrint(' API Connection Error: $e');
      setState(() {
        _apiResponse = {
          'status': 'error',
          'display_text': selectedLang == "UR"
              ? 'API سے رابطہ ناکام: $e'
              : 'API Connection Failed: $e',
        };
      });
    }
  }

  // -----------------------------------------------------------
  // GENERATE FERTILIZER RECOMMENDATIONS BASED ON ACTUAL VALUES
  // -----------------------------------------------------------
  List<Map<String, dynamic>> _generateRecommendations(
    int originalN,
    int originalP,
    int originalK,
    double apiN,
    double apiP,
    double apiK,
  ) {
    final List<Map<String, dynamic>> recommendations = [];
    final isUrdu = selectedLang == "UR";

    // Calculate difference and percentage
    final nDiff = apiN - originalN;
    final pDiff = apiP - originalP;
    final kDiff = apiK - originalK;

    // Nitrogen recommendations
    if (nDiff > 20) {
      recommendations.add({
        'nutrient': isUrdu ? 'نائٹروجن' : 'Nitrogen',
        'status': isUrdu ? 'شدید کمی' : 'Severe Deficiency',
        'recommendation': isUrdu
            ? 'یوریا کھاد: 2 بوری فی ایکڑ (پانی میں ملا کر)'
            : 'Urea Fertilizer: 2 bags per acre (mixed in water)',
        'color': Colors.red,
        'icon': Icons.warning,
        'difference': nDiff,
      });
    } else if (nDiff > 10) {
      recommendations.add({
        'nutrient': isUrdu ? 'نائٹروجن' : 'Nitrogen',
        'status': isUrdu ? 'کمی' : 'Deficiency',
        'recommendation': isUrdu
            ? 'یوریا کھاد: 1 بوری فی ایکڑ'
            : 'Urea Fertilizer: 1 bag per acre',
        'color': Colors.orange,
        'icon': Icons.info,
        'difference': nDiff,
      });
    } else if (nDiff > 0) {
      recommendations.add({
        'nutrient': isUrdu ? 'نائٹروجن' : 'Nitrogen',
        'status': isUrdu ? 'ہلکی کمی' : 'Mild Deficiency',
        'recommendation': isUrdu
            ? 'یوریا کھاد: 0.5 بوری فی ایکڑ'
            : 'Urea Fertilizer: 0.5 bag per acre',
        'color': Colors.yellow.shade700,
        'icon': Icons.info_outline,
        'difference': nDiff,
      });
    } else if (nDiff < -10) {
      recommendations.add({
        'nutrient': isUrdu ? 'نائٹروجن' : 'Nitrogen',
        'status': isUrdu ? 'زیادتی' : 'Excess',
        'recommendation': isUrdu
            ? 'پانی کا زیادہ استعمال کریں، نئی کھاد نہ ڈالیں'
            : 'Increase water usage, avoid new fertilizer',
        'color': Colors.purple,
        'icon': Icons.water_drop,
        'difference': nDiff,
      });
    } else {
      recommendations.add({
        'nutrient': isUrdu ? 'نائٹروجن' : 'Nitrogen',
        'status': isUrdu ? 'متوازن' : 'Balanced',
        'recommendation': isUrdu
            ? 'موجودہ سطح برقرار رکھیں'
            : 'Maintain current level',
        'color': Colors.green,
        'icon': Icons.check_circle,
        'difference': nDiff,
      });
    }

    // Phosphorus recommendations
    if (pDiff > 25) {
      recommendations.add({
        'nutrient': isUrdu ? 'فاسفورس' : 'Phosphorus',
        'status': isUrdu ? 'شدید کمی' : 'Severe Deficiency',
        'recommendation': isUrdu
            ? 'DAP کھاد: 2.5 بوری فی ایکڑ'
            : 'DAP Fertilizer: 2.5 bags per acre',
        'color': Colors.red,
        'icon': Icons.warning,
        'difference': pDiff,
      });
    } else if (pDiff > 12) {
      recommendations.add({
        'nutrient': isUrdu ? 'فاسفورس' : 'Phosphorus',
        'status': isUrdu ? 'کمی' : 'Deficiency',
        'recommendation': isUrdu
            ? 'DAP کھاد: 1.5 بوری فی ایکڑ'
            : 'DAP Fertilizer: 1.5 bags per acre',
        'color': Colors.orange,
        'icon': Icons.info,
        'difference': pDiff,
      });
    } else if (pDiff > 0) {
      recommendations.add({
        'nutrient': isUrdu ? 'فاسفورس' : 'Phosphorus',
        'status': isUrdu ? 'ہلکی کمی' : 'Mild Deficiency',
        'recommendation': isUrdu
            ? 'DAP کھاد: 1 بوری فی ایکڑ'
            : 'DAP Fertilizer: 1 bag per acre',
        'color': Colors.yellow.shade700,
        'icon': Icons.info_outline,
        'difference': pDiff,
      });
    } else if (pDiff < -15) {
      recommendations.add({
        'nutrient': isUrdu ? 'فاسفورس' : 'Phosphorus',
        'status': isUrdu ? 'زیادتی' : 'Excess',
        'recommendation': isUrdu
            ? 'پوٹاشیم کھاد کا استعمال کریں توازن کے لیے'
            : 'Use Potassium fertilizer for balance',
        'color': Colors.purple,
        'icon': Icons.water_drop,
        'difference': pDiff,
      });
    } else {
      recommendations.add({
        'nutrient': isUrdu ? 'فاسفورس' : 'Phosphorus',
        'status': isUrdu ? 'متوازن' : 'Balanced',
        'recommendation': isUrdu
            ? 'موجودہ سطح برقرار رکھیں'
            : 'Maintain current level',
        'color': Colors.green,
        'icon': Icons.check_circle,
        'difference': pDiff,
      });
    }

    // Potassium recommendations
    if (kDiff > 70) {
      recommendations.add({
        'nutrient': isUrdu ? 'پوٹاشیم' : 'Potassium',
        'status': isUrdu ? 'شدید کمی' : 'Severe Deficiency',
        'recommendation': isUrdu
            ? 'MOP کھاد: 3 بوری فی ایکڑ'
            : 'MOP Fertilizer: 3 bags per acre',
        'color': Colors.red,
        'icon': Icons.warning,
        'difference': kDiff,
      });
    } else if (kDiff > 35) {
      recommendations.add({
        'nutrient': isUrdu ? 'پوٹاشیم' : 'Potassium',
        'status': isUrdu ? 'کمی' : 'Deficiency',
        'recommendation': isUrdu
            ? 'MOP کھاد: 2 بوری فی ایکڑ'
            : 'MOP Fertilizer: 2 bags per acre',
        'color': Colors.orange,
        'icon': Icons.info,
        'difference': kDiff,
      });
    } else if (kDiff > 0) {
      recommendations.add({
        'nutrient': isUrdu ? 'پوٹاشیم' : 'Potassium',
        'status': isUrdu ? 'ہلکی کمی' : 'Mild Deficiency',
        'recommendation': isUrdu
            ? 'MOP کھاد: 1 بوری فی ایکڑ'
            : 'MOP Fertilizer: 1 bag per acre',
        'color': Colors.yellow.shade700,
        'icon': Icons.info_outline,
        'difference': kDiff,
      });
    } else if (kDiff < -30) {
      recommendations.add({
        'nutrient': isUrdu ? 'پوٹاشیم' : 'Potassium',
        'status': isUrdu ? 'زیادتی' : 'Excess',
        'recommendation': isUrdu
            ? 'کیلشیم کھاد کا استعمال کریں'
            : 'Use Calcium fertilizer',
        'color': Colors.purple,
        'icon': Icons.water_drop,
        'difference': kDiff,
      });
    } else {
      recommendations.add({
        'nutrient': isUrdu ? 'پوٹاشیم' : 'Potassium',
        'status': isUrdu ? 'متوازن' : 'Balanced',
        'recommendation': isUrdu
            ? 'موجودہ سطح برقرار رکھیں'
            : 'Maintain current level',
        'color': Colors.green,
        'icon': Icons.check_circle,
        'difference': kDiff,
      });
    }

    return recommendations;
  }

  // -----------------------------------------------------------
  // UI BUILD METHODS
  // -----------------------------------------------------------
  Widget _buildLoadingBlock(double width, bool isDarkMode) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: width * 0.2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF22C358)),
          ),
          SizedBox(height: width * 0.05),
          Text(
            selectedLang == "UR"
                ? 'AI تجزیہ حاصل کیا جا رہا ہے...'
                : 'Getting AI analysis...',
            style: GoogleFonts.inter(
              fontSize: width * 0.04,
              color: isDarkMode ? Colors.grey[400] : const Color(0xFF555555),
            ),
          ),
          SizedBox(height: width * 0.02),
          Text(
            selectedLang == "UR"
                ? 'پاکستان کے مٹی معیار کے مطابق تبدیلی'
                : 'Converting to Pakistan soil standards',
            style: GoogleFonts.inter(
              fontSize: width * 0.035,
              color: isDarkMode ? Colors.blue[300] : Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  // ADDING THE MISSING ERROR BLOCK METHOD
  Widget _buildErrorBlock(double width, bool isDarkMode) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            vertical: width * 0.1,
            horizontal: width * 0.04,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: width * 0.15,
                color: Colors.orange,
              ),
              SizedBox(height: width * 0.04),
              Text(
                selectedLang == "UR" ? 'خرابی' : 'Error',
                style: GoogleFonts.inter(
                  fontSize: width * 0.045,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode
                      ? Colors.grey[300]
                      : const Color(0xFF555555),
                ),
              ),
              SizedBox(height: width * 0.02),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: width * 0.04),
                child: Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: width * 0.035,
                    color: Colors.red.shade400,
                  ),
                ),
              ),
              SizedBox(height: width * 0.04),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: width * 0.04),
                child: ElevatedButton(
                  onPressed: _getLatestSensorData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C358),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(width * 0.03),
                    ),
                    minimumSize: Size(double.infinity, width * 0.12),
                  ),
                  child: Text(
                    selectedLang == "UR" ? 'دوبارہ کوشش کریں' : 'Try Again',
                    style: GoogleFonts.inter(
                      fontSize: width * 0.04,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSensorDataCard(
    double width,
    bool isDarkMode,
    Color cardColor,
    Color cardBorderColor,
    Color textColor,
    Color secondaryTextColor,
  ) {
    final isUrdu = selectedLang == "UR";

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(
        horizontal: width * 0.02,
        vertical: width * 0.02,
      ),
      padding: EdgeInsets.all(width * 0.05),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(width * 0.05),
        border: Border.all(color: cardBorderColor),
        boxShadow: isDarkMode
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(width * 0.03),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.blue.shade900.withOpacity(0.3)
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(width * 0.03),
                ),
                child: Icon(
                  Icons.science,
                  color: isDarkMode ? Colors.blue[300] : Colors.blue.shade700,
                  size: width * 0.06,
                ),
              ),
              SizedBox(width: width * 0.03),
              Text(
                isUrdu ? 'سینسر ڈیٹا' : 'Sensor Data',
                style: GoogleFonts.inter(
                  fontSize: width * 0.048,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          SizedBox(height: width * 0.04),

          // Crop info
          Container(
            padding: EdgeInsets.all(width * 0.04),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.green.shade900.withOpacity(0.2)
                  : Colors.green.shade50,
              borderRadius: BorderRadius.circular(width * 0.03),
              border: Border.all(
                color: isDarkMode
                    ? Colors.green.shade800
                    : Colors.green.shade100,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.grass,
                  color: isDarkMode ? Colors.green[300] : Colors.green.shade700,
                ),
                SizedBox(width: width * 0.03),
                Text(
                  isUrdu ? 'فصل: ' : 'Crop: ',
                  style: GoogleFonts.inter(
                    fontSize: width * 0.04,
                    color: secondaryTextColor,
                  ),
                ),
                Text(
                  _sensorData['crop_name']?.toString() ?? 'Unknown',
                  style: GoogleFonts.inter(
                    fontSize: width * 0.04,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? Colors.green[300]
                        : Colors.green.shade800,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: width * 0.04),

          // NPK values
          Text(
            isUrdu ? 'مٹی کی غذائیت' : 'Soil Nutrients',
            style: GoogleFonts.inter(
              fontSize: width * 0.04,
              fontWeight: FontWeight.w600,
              color: secondaryTextColor,
            ),
          ),
          SizedBox(height: width * 0.02),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNPKItem(
                'N',
                '${_sensorData['nitrogen']} mg/kg',
                Colors.red,
                width,
                isDarkMode,
              ),
              _buildNPKItem(
                'P',
                '${_sensorData['phosphorus']} mg/kg',
                Colors.blue,
                width,
                isDarkMode,
              ),
              _buildNPKItem(
                'K',
                '${_sensorData['potassium']} mg/kg',
                Colors.green,
                width,
                isDarkMode,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNPKItem(
    String label,
    String value,
    Color color,
    double width,
    bool isDarkMode,
  ) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(width * 0.03),
          decoration: BoxDecoration(
            color: color.withOpacity(isDarkMode ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(width * 0.03),
            border: Border.all(
              color: color.withOpacity(isDarkMode ? 0.4 : 0.3),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: width * 0.05,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        SizedBox(height: width * 0.01),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: width * 0.035,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.grey[300] : const Color(0xFF555555),
          ),
        ),
      ],
    );
  }

  Widget _buildFertilizerRecommendationCard(
    double width,
    bool isDarkMode,
    Color cardColor,
    Color cardBorderColor,
    Color textColor,
    Color secondaryTextColor,
  ) {
    if (_fertilizerRecommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    final isUrdu = selectedLang == "UR";
    final originalN = _sensorData['nitrogen'];
    final originalP = _sensorData['phosphorus'];
    final originalK = _sensorData['potassium'];
    final apiN = _apiFinalNPK['N'] ?? 0.0;
    final apiP = _apiFinalNPK['P'] ?? 0.0;
    final apiK = _apiFinalNPK['K'] ?? 0.0;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(
        horizontal: width * 0.02,
        vertical: width * 0.02,
      ),
      padding: EdgeInsets.all(width * 0.05),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(width * 0.05),
        border: Border.all(
          color: isDarkMode ? Colors.orange.shade800 : cardBorderColor,
        ),
        boxShadow: isDarkMode
            ? [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(width * 0.03),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.orange.shade900.withOpacity(0.3)
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(width * 0.03),
                ),
                child: Icon(
                  Icons.agriculture,
                  color: isDarkMode
                      ? Colors.orange[300]
                      : Colors.orange.shade700,
                  size: width * 0.06,
                ),
              ),
              SizedBox(width: width * 0.03),
              Expanded(
                child: Text(
                  isUrdu
                      ? 'AI سفارشات (پاکستان معیار)'
                      : 'AI Recommendations (Pakistan Standards)',
                  style: GoogleFonts.inter(
                    fontSize: width * 0.048,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: width * 0.04),

          // Conversion Info
          Container(
            padding: EdgeInsets.all(width * 0.04),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.blue.shade900.withOpacity(0.2)
                  : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(width * 0.03),
              border: Border.all(
                color: isDarkMode ? Colors.blue.shade800 : Colors.blue.shade100,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.autorenew,
                  color: isDarkMode ? Colors.blue[300] : Colors.blue.shade700,
                  size: width * 0.05,
                ),
                SizedBox(width: width * 0.03),
                Expanded(
                  child: Text(
                    isUrdu
                        ? 'مقامی مٹی معیار کے مطابق تبدیلی کی گئی ہے'
                        : 'Converted to local soil standards',
                    style: GoogleFonts.inter(
                      fontSize: width * 0.038,
                      color: isDarkMode
                          ? Colors.blue[300]
                          : Colors.blue.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: width * 0.04),

          // NPK Comparison
          Text(
            isUrdu ? 'غذائی تقابل' : 'Nutrient Comparison',
            style: GoogleFonts.inter(
              fontSize: width * 0.04,
              fontWeight: FontWeight.w600,
              color: secondaryTextColor,
            ),
          ),
          SizedBox(height: width * 0.02),

          // FIXED: Scrollable comparison table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: width * 0.9,
                maxWidth: width * 1.5,
              ),
              child: Container(
                padding: EdgeInsets.all(width * 0.04),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(width * 0.03),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Headers - FIXED with flexible widths
                    SizedBox(
                      width: width * 1.2,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(
                            width: width * 0.25,
                            child: Text(
                              isUrdu ? 'عنصر' : 'Element',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: width * 0.035,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: width * 0.25,
                            child: Text(
                              isUrdu ? 'اصل' : 'Current',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: width * 0.035,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: width * 0.3,
                            child: Text(
                              isUrdu ? 'مطلوبہ' : 'Required',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: width * 0.035,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: width * 0.3,
                            child: Text(
                              isUrdu ? 'فرق' : 'Difference',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: width * 0.035,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: width * 0.03),

                    // Rows
                    Column(
                      children: [
                        _buildComparisonDetailRow(
                          'N',
                          originalN,
                          apiN,
                          width,
                          isDarkMode,
                        ),
                        SizedBox(height: width * 0.02),
                        _buildComparisonDetailRow(
                          'P',
                          originalP,
                          apiP,
                          width,
                          isDarkMode,
                        ),
                        SizedBox(height: width * 0.02),
                        _buildComparisonDetailRow(
                          'K',
                          originalK,
                          apiK,
                          width,
                          isDarkMode,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(height: width * 0.04),

          // Detailed Recommendations
          Text(
            isUrdu ? 'تفصیلی سفارشات' : 'Detailed Recommendations',
            style: GoogleFonts.inter(
              fontSize: width * 0.04,
              fontWeight: FontWeight.w600,
              color: secondaryTextColor,
            ),
          ),
          SizedBox(height: width * 0.02),

          Column(
            children: _fertilizerRecommendations
                .map(
                  (rec) => Container(
                    margin: EdgeInsets.only(bottom: width * 0.03),
                    padding: EdgeInsets.all(width * 0.04),
                    decoration: BoxDecoration(
                      color: (rec['color'] as Color).withOpacity(
                        isDarkMode ? 0.15 : 0.1,
                      ),
                      borderRadius: BorderRadius.circular(width * 0.03),
                      border: Border.all(
                        color: (rec['color'] as Color).withOpacity(
                          isDarkMode ? 0.4 : 0.3,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.all(width * 0.02),
                          decoration: BoxDecoration(
                            color: rec['color'],
                            borderRadius: BorderRadius.circular(width * 0.02),
                          ),
                          child: Icon(
                            rec['icon'] as IconData,
                            color: Colors.white,
                            size: width * 0.05,
                          ),
                        ),
                        SizedBox(width: width * 0.03),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      rec['nutrient'],
                                      style: GoogleFonts.inter(
                                        fontSize: width * 0.04,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: width * 0.02),
                                  Flexible(
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: width * 0.02,
                                        vertical: width * 0.01,
                                      ),
                                      decoration: BoxDecoration(
                                        color: rec['color'].withOpacity(
                                          isDarkMode ? 0.3 : 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          width * 0.02,
                                        ),
                                      ),
                                      child: Text(
                                        rec['status'],
                                        style: GoogleFonts.inter(
                                          fontSize: width * 0.032,
                                          fontWeight: FontWeight.w600,
                                          color: rec['color'],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: width * 0.01),
                              Text(
                                rec['recommendation'],
                                style: GoogleFonts.inter(
                                  fontSize: width * 0.038,
                                  color: secondaryTextColor,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  // FIXED: Comparison detail row with no overflow
  Widget _buildComparisonDetailRow(
    String element,
    dynamic original,
    dynamic required,
    double width,
    bool isDarkMode,
  ) {
    final diff = required is double
        ? (required - (original is int ? original.toDouble() : original))
        : 0.0;
    final diffText = diff > 0
        ? '+${diff.toStringAsFixed(1)}'
        : diff.toStringAsFixed(1);
    Color diffColor = Colors.green;
    if (diff > 20)
      diffColor = Colors.red;
    else if (diff > 10)
      diffColor = Colors.orange;
    else if (diff > 0)
      diffColor = Colors.yellow.shade700;
    else if (diff < -10)
      diffColor = Colors.purple;

    return SizedBox(
      width: width * 1.2,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Element column
          SizedBox(
            width: width * 0.25,
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: width * 0.015,
                horizontal: width * 0.01,
              ),
              decoration: BoxDecoration(
                color: _getElementColor(
                  element,
                ).withOpacity(isDarkMode ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(width * 0.02),
                border: Border.all(
                  color: _getElementColor(
                    element,
                  ).withOpacity(isDarkMode ? 0.4 : 0.3),
                ),
              ),
              child: Text(
                element,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: width * 0.04,
                  fontWeight: FontWeight.bold,
                  color: _getElementColor(element),
                ),
              ),
            ),
          ),

          // Current value column
          SizedBox(
            width: width * 0.25,
            child: Container(
              padding: EdgeInsets.all(width * 0.012),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[700] : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(width * 0.02),
              ),
              child: Text(
                original.toString(),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: width * 0.035,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode
                      ? Colors.grey[300]
                      : const Color(0xFF555555),
                ),
              ),
            ),
          ),

          // Required value column
          SizedBox(
            width: width * 0.3,
            child: Container(
              padding: EdgeInsets.all(width * 0.012),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.blue.shade900.withOpacity(0.3)
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(width * 0.02),
                border: Border.all(
                  color: isDarkMode
                      ? Colors.blue.shade800
                      : Colors.blue.shade100,
                ),
              ),
              child: Text(
                required is double
                    ? required.toStringAsFixed(1)
                    : required.toString(),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: width * 0.035,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.blue[300] : Colors.blue.shade800,
                ),
              ),
            ),
          ),

          // Difference column
          SizedBox(
            width: width * 0.3,
            child: Container(
              padding: EdgeInsets.all(width * 0.012),
              decoration: BoxDecoration(
                color: diffColor.withOpacity(isDarkMode ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(width * 0.02),
                border: Border.all(
                  color: diffColor.withOpacity(isDarkMode ? 0.4 : 0.3),
                ),
              ),
              child: Text(
                diffText,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: width * 0.035,
                  fontWeight: FontWeight.bold,
                  color: diffColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getElementColor(String element) {
    switch (element) {
      case 'N':
        return Colors.red;
      case 'P':
        return Colors.blue;
      case 'K':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: true);
    final isDarkMode = themeProvider.isDarkMode;

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

    return WillPopScope(
      onWillPop: () async {
        if (_isSpeaking) {
          await ttsService.stop();
        }
        return true;
      },
      child: Container(
        color: backgroundColor,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: width * 0.04),
            child: Column(
              crossAxisAlignment: selectedLang == "UR"
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                SizedBox(height: height * 0.02),

                // Language Toggle Row with Speaker Icon
                Container(
                  margin: EdgeInsets.only(bottom: height * 0.03),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Language Toggle Container
                      Container(
                        width: width * 0.40,
                        height: width * 0.12,
                        padding: EdgeInsets.symmetric(
                          horizontal: width * 0.015,
                        ),
                        decoration: BoxDecoration(
                          color: languageBgColor,
                          borderRadius: BorderRadius.circular(width * 0.03),
                          border: Border.all(
                            color: languageBorderColor,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  _updateLanguage("EN");
                                },
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
                                onTap: () {
                                  _updateLanguage("UR");
                                },
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

                      // Speaker Icon
                      GestureDetector(
                        onTap: _speakScreenContent,
                        child: Container(
                          width: width * 0.12,
                          height: width * 0.12,
                          decoration: BoxDecoration(
                            color: _isSpeaking
                                ? speakerActiveBg
                                : languageBgColor,
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
                                  : (isDarkMode
                                        ? Colors.grey[400]
                                        : languageTextColor),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Title
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: width * 0.02),
                  child: Text(
                    selectedLang == "UR"
                        ? 'AI زرعی مشورہ'
                        : 'AI Agriculture Advice',
                    style: GoogleFonts.inter(
                      fontSize: width * 0.055,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),

                SizedBox(height: height * 0.02),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: width * 0.02),
                  child: Text(
                    selectedLang == "UR"
                        ? 'پاکستان کے مٹی معیار کے مطابق کھاد کی سفارشات'
                        : 'Fertilizer recommendations according to Pakistan soil standards',
                    style: GoogleFonts.inter(
                      fontSize: width * 0.035,
                      color: secondaryTextColor,
                    ),
                  ),
                ),

                SizedBox(height: height * 0.03),

                if (_isLoading)
                  _buildLoadingBlock(width, isDarkMode)
                else if (_errorMessage.isNotEmpty && _apiResponse == null)
                  _buildErrorBlock(width, isDarkMode)
                else ...[
                  _buildSensorDataCard(
                    width,
                    isDarkMode,
                    cardColor,
                    cardBorderColor,
                    textColor,
                    secondaryTextColor,
                  ),
                  _buildFertilizerRecommendationCard(
                    width,
                    isDarkMode,
                    cardColor,
                    cardBorderColor,
                    textColor,
                    secondaryTextColor,
                  ),

                  SizedBox(height: width * 0.04),

                  // Refresh Button
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: width * 0.02),
                    child: ElevatedButton(
                      onPressed: _getLatestSensorData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(width * 0.03),
                        ),
                        minimumSize: Size(double.infinity, width * 0.12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.refresh, color: Colors.white),
                          SizedBox(width: width * 0.02),
                          Text(
                            selectedLang == "UR"
                                ? 'نیا ڈیٹا حاصل کریں'
                                : 'Get New AI Advice',
                            style: GoogleFonts.inter(
                              fontSize: width * 0.04,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: width * 0.05),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    ttsService.dispose();
    super.dispose();
  }
}
