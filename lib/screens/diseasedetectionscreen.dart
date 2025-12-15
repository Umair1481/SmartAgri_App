import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; // Added for ThemeProvider
import 'package:smartagriapp/services/service.dart';
import '../state/themeprovier.dart'; // Import  ThemeProvider

class DiseaseContent extends StatefulWidget {
  final String selectedLang;

  const DiseaseContent({super.key, required this.selectedLang});

  @override
  State<DiseaseContent> createState() => _DiseaseContentState();
}

class _DiseaseContentState extends State<DiseaseContent> {
  late String selectedLang;
  late TTSService ttsService;
  bool _isSpeaking = false;
  bool _isFinishedSpeaking = false;

  String? _selectedImagePath;
  String? _selectedCrop;
  bool _isLoading = false;
  Map<String, dynamic>? _result;

  final ImagePicker _picker = ImagePicker();
  final String apiUrl = "https://smartagri-leaf.ngrok-free.app/predict";
  final List<String> crops = ["cotton", "wheat", "rice", "maize", "tomato"];

  @override
  void initState() {
    super.initState();
    selectedLang = widget.selectedLang;
    ttsService = TTSService();
    _isSpeaking = false;
    _isFinishedSpeaking = false;

    // Initialize TTS with correct language
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ttsService.setLanguage(selectedLang == "UR" ? "ur-PK" : "en-US");
    });
  }

  // -----------------------------------------------------------
  // SPEAK SCREEN CONTENT
  // -----------------------------------------------------------
  Future<void> _speakScreenContent() async {
    // If currently speaking, stop it
    if (_isSpeaking) {
      await ttsService.stop();
      setState(() {
        _isSpeaking = false;
        _isFinishedSpeaking = false;
      });
      return;
    }

    // If just finished speaking and user clicks again, start over
    if (_isFinishedSpeaking) {
      _isFinishedSpeaking = false;
    }

    setState(() {
      _isSpeaking = true;
      _isFinishedSpeaking = false;
    });

    // Generate narration based on current state
    String narration = "";
    if (selectedLang == "EN") {
      narration =
          """
Disease Detection Screen.
${_selectedCrop != null ? "Selected crop is $_selectedCrop." : "No crop selected."}
${_selectedImagePath != null ? "Image is selected." : "No image selected."}
${_result != null ? "Disease detected: ${_result!['disease']}. Confidence: ${_result!['confidence'].toStringAsFixed(2)}%. ${_getPreventionAdvice(_result!['disease'])}" : "No analysis results yet."}
Use the capture or upload buttons to add an image.
""";
    } else {
      narration =
          """
بیماری کی تشخیص کا اسکرین۔
${_selectedCrop != null ? "منتخب فصل $_selectedCrop ہے۔" : "کوئی فصل منتخب نہیں۔"}
${_selectedImagePath != null ? "تصویر منتخب کی گئی ہے۔" : "کوئی تصویر منتخب نہیں۔"}
${_result != null ? "پائی گئی بیماری: ${_result!['disease']}۔ اعتماد: ${_result!['confidence'].toStringAsFixed(2)}%۔ ${_getPreventionAdviceUrdu(_result!['disease'])}" : "ابھی تک کوئی تجزیہ نتیجہ نہیں۔"}
تصویر شامل کرنے کے لیے کھینچیں یا اپ لوڈ کریں کے بٹن استعمال کریں۔
""";
    }

    await ttsService.speak(
      narration,
      langCode: selectedLang == "UR" ? "ur-PK" : "en-US",
    );

    // Estimate speech completion time
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

          // Reset finished state after a short delay
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
  // DEMO BUTTON - Show sample results when server is down
  // -----------------------------------------------------------
  void _showDemoResults() {
    final demoResult = {"disease": "Early Blight", "confidence": 92.5};

    setState(() {
      _result = demoResult;
    });

    // Show message in selected language
    final message = selectedLang == "EN"
        ? "Demo results loaded. Server responses would appear like this."
        : "ڈیمو نتائج لوڈ ہو گئے۔ سرور کے جوابات اس طرح ظاہر ہوں گے۔";

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        backgroundColor: const Color(0xFF21C357),
      ),
    );
  }

  // Prevention advice methods
  String _getPreventionAdvice(String disease) {
    final advice = {
      "healthy": "The plant appears healthy. Continue current practices.",
      "bacterial_spot":
          "Remove infected leaves. Use copper-based bactericides.",
      "early_blight":
          "Remove infected leaves. Apply fungicides containing chlorothalonil.",
      "late_blight": "Destroy infected plants. Use fungicides with metalaxyl.",
      "leaf_mold": "Improve air circulation. Reduce watering frequency.",
      "leaf_spot": "Remove affected leaves. Apply appropriate fungicide.",
      "powdery_mildew": "Apply sulfur or potassium bicarbonate sprays.",
      "rust":
          "Remove infected leaves. Apply fungicides containing myclobutanil.",
    };

    return advice[disease.toLowerCase()] ??
        "Consult local agricultural expert for specific treatment.";
  }

  String _getPreventionAdviceUrdu(String disease) {
    final advice = {
      "healthy": "پودا صحت مند نظر آتا ہے۔ موجودہ طریقوں کو جاری رکھیں۔",
      "bacterial_spot":
          "متاثرہ پتے ہٹا دیں۔ تانبے پر مبنی بیکٹیریا کش ادویات استعمال کریں۔",
      "early_blight":
          "متاثرہ پتے ہٹا دیں۔ کلوروتھالونیل پر مشتمل فنگس کش ادویات لگائیں۔",
      "late_blight":
          "متاثرہ پودے تباہ کریں۔ میٹالاکسل پر مشتمل فنگس کش ادویات استعمال کریں۔",
      "leaf_mold": "ہوا کی گردش بہتر بنائیں۔ پانی دینے کی فریکوئنسی کم کریں۔",
      "leaf_spot": "متاثرہ پتے ہٹا دیں۔ مناسب فنگس کش ادویات لگائیں۔",
      "powdery_mildew": "سلفر یا پوٹاشیم بائی کاربونیٹ سپرے لگائیں۔",
      "rust":
          "متاثرہ پتے ہٹا دیں۔ مائی کلو بیوٹانل پر مشتمل فنگس کش ادویات لگائیں۔",
    };

    return advice[disease.toLowerCase()] ??
        "مخصوص علاج کے لیے مقامی زرعی ماہر سے مشورہ کریں۔";
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
    final dropdownBgColor = isDarkMode ? Colors.grey[800]! : Colors.white;
    final dropdownBorderColor = isDarkMode
        ? Colors.grey[600]!
        : Colors.grey.shade300;
    final imageFrameBgColor = isDarkMode
        ? Colors.grey[800]!
        : const Color(0xFFF9F9F9);
    final emptyPlaceholderColor = isDarkMode ? Colors.grey[600]! : Colors.grey;
    final preventionCardBg = isDarkMode
        ? const Color(0xFF2E7D32).withOpacity(0.2)
        : const Color(0xFFE8F5E9);
    final preventionCardBorder = isDarkMode
        ? const Color(0xFF2E7D32).withOpacity(0.4)
        : const Color(0xFFC8E6C9);
    final preventionTextColor = isDarkMode
        ? Colors.green[100]!
        : const Color(0xFF2E7D32);

    return WillPopScope(
      onWillPop: () async {
        // Stop TTS if speaking
        if (_isSpeaking) {
          await ttsService.stop();
        }
        // Let it go back to dashboard (default behavior)
        return true;
      },
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Container(
          color: backgroundColor,
          padding: EdgeInsets.symmetric(horizontal: width * 0.07),
          child: Column(
            crossAxisAlignment: selectedLang == "UR"
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              SizedBox(height: height * 0.02),

              // Language Toggle Row with Speaker Icon at Right Edge
              Container(
                margin: EdgeInsets.only(bottom: height * 0.03),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Language Toggle Container
                    Container(
                      width: width * 0.40,
                      height: width * 0.12,
                      padding: EdgeInsets.symmetric(horizontal: width * 0.015),
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

                    // Speaker Icon at Right Edge
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

              // Screen Title
              Text(
                selectedLang == "EN" ? "Disease Detection" : "بیماری کی تشخیص",
                style: GoogleFonts.inter(
                  fontSize: width * 0.055,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),

              const SizedBox(height: 20),

              // Demo Button (only show when no results)
              if (_result == null) ...[
                Center(
                  child: ElevatedButton(
                    onPressed: _showDemoResults,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF57C00),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: width * 0.06,
                        vertical: width * 0.03,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(width * 0.03),
                      ),
                    ),
                    child: Text(
                      selectedLang == "EN"
                          ? "View Demo Results (Server Down)"
                          : "ڈیمو نتائج دیکھیں (سرور ڈاؤن)",
                      style: GoogleFonts.inter(
                        fontSize: width * 0.035,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Crop dropdown
              _cropDropdown(
                width,
                isDarkMode,
                dropdownBgColor,
                dropdownBorderColor,
                textColor,
              ),

              const SizedBox(height: 20),

              _imageFrame(
                width,
                height,
                isDarkMode,
                imageFrameBgColor,
                cardBorderColor,
                emptyPlaceholderColor,
              ),

              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _detectDiseaseButton(width, isDarkMode),
                  if (_result != null) _resetButton(width, isDarkMode),
                ],
              ),

              const SizedBox(height: 28),

              if (_result != null)
                _resultsSection(
                  width,
                  isDarkMode,
                  cardColor,
                  cardBorderColor,
                  cardShadow,
                  textColor,
                  secondaryTextColor,
                  preventionCardBg,
                  preventionCardBorder,
                  preventionTextColor,
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------ CROP DROPDOWN ------------------
  Widget _cropDropdown(
    double width,
    bool isDarkMode,
    Color bgColor,
    Color borderColor,
    Color textColor,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: width * 0.04,
        vertical: width * 0.02,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(width * 0.03),
      ),
      child: DropdownButton<String>(
        isExpanded: true,
        value: _selectedCrop,
        hint: Text(
          selectedLang == "EN" ? "Select Crop" : "فصل منتخب کریں",
          style: GoogleFonts.inter(
            fontSize: width * 0.04,
            color: isDarkMode ? Colors.grey[400] : const Color(0xFF555555),
          ),
        ),
        underline: Container(),
        dropdownColor: bgColor,
        icon: Icon(
          Icons.arrow_drop_down,
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
        items: crops.map((crop) {
          return DropdownMenuItem(
            value: crop,
            child: Text(
              crop.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: width * 0.04,
                color: textColor,
              ),
            ),
          );
        }).toList(),
        onChanged: (val) {
          setState(() => _selectedCrop = val);
        },
      ),
    );
  }

  // ------------------ IMAGE FRAME ------------------
  Widget _imageFrame(
    double width,
    double height,
    bool isDarkMode,
    Color bgColor,
    Color borderColor,
    Color placeholderColor,
  ) {
    return Container(
      padding: EdgeInsets.all(width * 0.04),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(width * 0.04),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _greenButton(
                  selectedLang == "EN" ? "Capture Image" : "تصویر کھینچیں",
                  Icons.camera_alt,
                  _captureImage,
                  width,
                  isDarkMode,
                ),
              ),
              SizedBox(width: width * 0.03),
              Expanded(
                child: _whiteButton(
                  selectedLang == "EN" ? "Upload Image" : "تصویر اپ لوڈ کریں",
                  Icons.upload_file,
                  _pickImage,
                  width,
                  isDarkMode,
                ),
              ),
            ],
          ),

          SizedBox(height: height * 0.02),

          Container(
            height: height * 0.25,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800]! : Colors.white,
              borderRadius: BorderRadius.circular(width * 0.04),
              border: Border.all(color: borderColor),
            ),
            child: _isLoading
                ? _loadingIndicator(isDarkMode)
                : _selectedImagePath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(width * 0.04),
                    child: Image.file(
                      File(_selectedImagePath!),
                      fit: BoxFit.cover,
                    ),
                  )
                : _emptyPlaceholder(width, placeholderColor),
          ),
        ],
      ),
    );
  }

  Widget _loadingIndicator(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF21C357)),
          const SizedBox(height: 10),
          Text(
            selectedLang == "EN" ? "Analyzing..." : "تجزیہ ہو رہا ہے...",
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400]! : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyPlaceholder(double width, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image, size: width * 0.15, color: color),
          SizedBox(height: width * 0.02),
          Text(
            selectedLang == "EN"
                ? "No Image Selected"
                : "کوئی تصویر منتخب نہیں",
            style: GoogleFonts.inter(color: color, fontSize: width * 0.04),
          ),
        ],
      ),
    );
  }

  // ------------------ BUTTON WIDGETS ------------------
  Widget _greenButton(
    String text,
    IconData icon,
    Function handler,
    double width,
    bool isDarkMode,
  ) {
    return ElevatedButton(
      onPressed: () => handler(),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF21C357),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: width * 0.035),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(width * 0.03),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: width * 0.05),
          SizedBox(width: width * 0.02),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: width * 0.035,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _whiteButton(
    String text,
    IconData icon,
    Function handler,
    double width,
    bool isDarkMode,
  ) {
    return ElevatedButton(
      onPressed: () => handler(),
      style: ElevatedButton.styleFrom(
        backgroundColor: isDarkMode ? Colors.grey[700]! : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black87,
        padding: EdgeInsets.symmetric(vertical: width * 0.035),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(width * 0.03),
          side: BorderSide(
            color: isDarkMode ? Colors.grey[600]! : const Color(0xFFE9E9E9),
            width: 2,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isDarkMode ? Colors.white : Colors.black87,
            size: width * 0.05,
          ),
          SizedBox(width: width * 0.02),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: width * 0.035,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------ PICK / CAPTURE IMAGE ------------------
  Future<void> _captureImage() async {
    final XFile? img = await _picker.pickImage(source: ImageSource.camera);
    if (img != null) {
      setState(() => _selectedImagePath = img.path);
    }
  }

  Future<void> _pickImage() async {
    final XFile? img = await _picker.pickImage(source: ImageSource.gallery);
    if (img != null) {
      setState(() => _selectedImagePath = img.path);
    }
  }

  // ------------------ DETECT DISEASE BUTTON ------------------
  Widget _detectDiseaseButton(double width, bool isDarkMode) {
    return ElevatedButton(
      onPressed: _selectedImagePath == null ? null : _analyzeImage,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF21C357),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: width * 0.08,
          vertical: width * 0.04,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(width * 0.04),
        ),
      ),
      child: Text(
        selectedLang == "EN" ? "Detect Disease" : "بیماری معلوم کریں",
        style: GoogleFonts.inter(
          fontSize: width * 0.04,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ------------------ RESET BUTTON ------------------
  Widget _resetButton(double width, bool isDarkMode) {
    return ElevatedButton(
      onPressed: _resetScreen,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF44336),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: width * 0.06,
          vertical: width * 0.04,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(width * 0.04),
        ),
      ),
      child: Text(
        selectedLang == "EN" ? "Reset" : "دوبارہ شروع کریں",
        style: GoogleFonts.inter(
          fontSize: width * 0.04,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _resetScreen() {
    setState(() {
      _selectedImagePath = null;
      _result = null;
      _isSpeaking = false;
      _isFinishedSpeaking = false;
    });
    ttsService.stop();
  }

  // ------------------ API CALL ------------------
  Future<void> _analyzeImage() async {
    if (_selectedCrop == null) {
      _showSnack(
        selectedLang == "EN"
            ? "Please select a crop first"
            : "پہلے ایک فصل منتخب کریں",
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bytes = File(_selectedImagePath!).readAsBytesSync();
      final base64Img = base64Encode(bytes);

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"crop": _selectedCrop, "image": base64Img}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _result = data);
        _saveToFirebase(data);

        // Speak the result
        if (mounted) {
          final resultNarration = selectedLang == "EN"
              ? "Disease detected: ${data['disease']}. Confidence: ${data['confidence'].toStringAsFixed(2)}%. ${_getPreventionAdvice(data['disease'])}"
              : "پائی گئی بیماری: ${data['disease']}۔ اعتماد: ${data['confidence'].toStringAsFixed(2)}%۔ ${_getPreventionAdviceUrdu(data['disease'])}";

          await ttsService.speak(
            resultNarration,
            langCode: selectedLang == "UR" ? "ur-PK" : "en-US",
          );
        }
      } else {
        _showSnack(
          selectedLang == "EN"
              ? "API Error: ${response.statusCode}. Showing demo results."
              : "API خرابی: ${response.statusCode}۔ ڈیمو نتائج دکھا رہے ہیں۔",
        );
        // Show demo results on API error
        _showDemoResults();
      }
    } catch (e) {
      _showSnack(
        selectedLang == "EN"
            ? "Network Error: $e. Showing demo results."
            : "نیٹ ورک خرابی: $e۔ ڈیمو نتائج دکھا رہے ہیں۔",
      );
      // Show demo results on network error
      _showDemoResults();
    }

    setState(() => _isLoading = false);
  }

  // ------------------ FIREBASE SAVE ------------------
  Future<void> _saveToFirebase(Map<String, dynamic> result) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("disease_history")
        .add({
          "crop": _selectedCrop,
          "disease": result["disease"],
          "confidence": result["confidence"],
          "timestamp": DateTime.now(),
        });
  }

  // ------------------ RESULTS ------------------
  Widget _resultsSection(
    double width,
    bool isDarkMode,
    Color cardColor,
    Color cardBorderColor,
    Color cardShadow,
    Color textColor,
    Color secondaryTextColor,
    Color preventionCardBg,
    Color preventionCardBorder,
    Color preventionTextColor,
  ) {
    return Column(
      children: [
        // Disease Detected Card
        _resultCard(
          selectedLang == "EN" ? "Disease Detected" : "پائی گئی بیماری",
          _result!["disease"],
          width,
          isDarkMode,
          cardColor,
          cardBorderColor,
          cardShadow,
          textColor,
          secondaryTextColor,
        ),
        SizedBox(height: width * 0.04),

        // AI Confidence Card
        _resultCard(
          selectedLang == "EN" ? "AI Confidence" : "AI اعتماد",
          "${_result!["confidence"].toStringAsFixed(2)}%",
          width,
          isDarkMode,
          cardColor,
          cardBorderColor,
          cardShadow,
          textColor,
          secondaryTextColor,
        ),
        SizedBox(height: width * 0.06),

        // Prevention Tips Card
        _buildPreventionTipsCard(
          width,
          isDarkMode,
          preventionCardBg,
          preventionCardBorder,
          preventionTextColor,
        ),
      ],
    );
  }

  Widget _resultCard(
    String title,
    String value,
    double width,
    bool isDarkMode,
    Color cardColor,
    Color cardBorderColor,
    Color cardShadow,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(width * 0.04),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(width * 0.04),
        border: Border.all(color: cardBorderColor),
        boxShadow: [
          BoxShadow(
            color: cardShadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: width * 0.04,
              fontWeight: FontWeight.bold,
              color: secondaryTextColor,
            ),
          ),
          SizedBox(height: width * 0.02),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: width * 0.05,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF21C357),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreventionTipsCard(
    double width,
    bool isDarkMode,
    Color bgColor,
    Color borderColor,
    Color textColor,
  ) {
    final disease = _result!["disease"];
    final tips = selectedLang == "EN"
        ? _getPreventionAdvice(disease)
        : _getPreventionAdviceUrdu(disease);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(width * 0.04),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(width * 0.04),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety, color: const Color(0xFF21C357)),
              SizedBox(width: width * 0.02),
              Text(
                selectedLang == "EN" ? "Prevention Tips" : "بچاؤ کے طریقے",
                style: GoogleFonts.inter(
                  fontSize: width * 0.04,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          SizedBox(height: width * 0.02),
          Text(
            tips,
            style: GoogleFonts.inter(
              fontSize: width * 0.035,
              color: isDarkMode ? Colors.grey[300] : const Color(0xFF424242),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------ SNACKBAR ------------------
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  @override
  void dispose() {
    ttsService.dispose();
    super.dispose();
  }
}
