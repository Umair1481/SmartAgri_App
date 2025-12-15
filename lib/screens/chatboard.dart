import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart'; // Added for ThemeProvider
import '../state/themeprovier.dart'; // Import  ThemeProvider

class ChatBoard extends StatefulWidget {
  const ChatBoard({super.key});

  @override
  State<ChatBoard> createState() => _ChatBoardState();
}

class _ChatBoardState extends State<ChatBoard> {
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();

  List<Map<String, dynamic>> messages = [];

  bool isLoading = false;
  bool isRecording = false;

  // Voice System
  late stt.SpeechToText speech;
  final FlutterTts tts = FlutterTts();

  // API URL
  static const String baseUrl = "https://smartagri-chatbot.ngrok-free.app";

  @override
  void initState() {
    super.initState();
    speech = stt.SpeechToText();
  }

  // Chatbot API Call
  Future<String> askChatbot(String question) async {
    final url = Uri.parse("$baseUrl/ask");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"question": question}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["answer"];
    } else {
      return "Chatbot API error: ${response.statusCode}";
    }
  }

  // Send Message
  void sendTextMessage() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add({"sender": "user", "msg": text});
      isLoading = true;
    });

    controller.clear();
    scrollToBottom();

    final reply = await askChatbot(text);

    setState(() {
      messages.add({"sender": "bot", "msg": reply});
      isLoading = false;
    });

    speak(reply);
    scrollToBottom();
  }

  // Voice Input (Auto detect Urdu or English)
  void startListening() async {
    bool available = await speech.initialize();
    if (available) {
      setState(() {
        isRecording = true;
      });

      speech.listen(
        listenMode: stt.ListenMode.deviceDefault,
        onResult: (result) {
          controller.text = result.recognizedWords;
        },
      );
    }
  }

  void stopListening() {
    speech.stop();
    setState(() => isRecording = false);

    if (controller.text.trim().isNotEmpty) {
      sendTextMessage();
    }
  }

  // Auto-Detect TTS Language
  Future speak(String text) async {
    bool isUrdu = RegExp(r'[\u0600-\u06FF]').hasMatch(text);

    await tts.setLanguage(isUrdu ? "ur-PK" : "en-US");
    await tts.setPitch(1.0);
    await tts.speak(text);
  }

  void scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // Build individual message bubble
  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isDarkMode) {
    bool isUser = msg["sender"] == "user";

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF19B34B) // User message color (green)
              : isDarkMode
              ? Colors.grey[800]! // Bot message in dark mode
              : const Color(0xFFFCF8F0), // Bot message in light mode
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isUser ? 14 : 6),
            topRight: Radius.circular(isUser ? 6 : 14),
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(14),
          ),
          boxShadow: isDarkMode
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isUser ? Icons.person : Icons.smart_toy,
                  size: 16,
                  color: isUser
                      ? Colors.white
                      : (isDarkMode
                            ? Colors.grey[300]
                            : const Color(0xFF7D6E5A)),
                ),
                const SizedBox(width: 6),
                Text(
                  isUser ? "You" : "AgriBot",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isUser
                        ? Colors.white
                        : (isDarkMode
                              ? Colors.grey[300]
                              : const Color(0xFF7D6E5A)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              msg["msg"],
              style: TextStyle(
                color: isUser
                    ? Colors.white
                    : (isDarkMode ? Colors.grey[200] : const Color(0xFF7D6E5A)),
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: true);
    final isDarkMode = themeProvider.isDarkMode;
    final width = MediaQuery.of(context).size.width;

    // Theme-aware colors
    final backgroundColor = isDarkMode ? Colors.grey[900]! : Colors.transparent;
    final inputBgColor = isDarkMode ? Colors.grey[800]! : Colors.white;
    final inputBorderColor = isDarkMode ? Colors.grey[600]! : Colors.grey[300]!;
    final inputTextColor = isDarkMode ? Colors.white : Colors.black;
    final hintTextColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    final iconColor = isDarkMode ? Colors.grey[300]! : Colors.green;

    return Container(
      decoration: isDarkMode
          ? BoxDecoration(color: Colors.grey[900])
          : const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  "https://firebasestorage.googleapis.com/v0/b/codeless-app.appspot.com/o/projects%2F0SB2MS1_SmL3yiBAMZgN%2F88b82c548c5ccd7611ea9e3f92ff43d701003cb2Image.png?alt=media",
                ),
                fit: BoxFit.cover,
              ),
            ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[850]! : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF19B34B).withOpacity(0.2)
                        : const Color(0xFF19B34B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.smart_toy,
                    color: isDarkMode
                        ? const Color(0xFF19B34B)
                        : const Color(0xFF19B34B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "AgriBot Assistant",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        "Ask me anything about agriculture",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Listening Indicator
          if (isRecording)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: isDarkMode
                  ? Colors.red[900]!.withOpacity(0.2)
                  : Colors.red[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic, color: Colors.red, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    "Listening… Speak now",
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Messages Area
          Expanded(
            child: Container(
              color: isDarkMode
                  ? Colors.grey[900]!.withOpacity(0.8)
                  : Colors.transparent,
              child: messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: isDarkMode
                                ? Colors.grey[600]
                                : Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Start a conversation with AgriBot",
                            style: TextStyle(
                              fontSize: 16,
                              color: isDarkMode
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Ask about crops, fertilizers, or farming tips",
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode
                                  ? Colors.grey[500]
                                  : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessageBubble(messages[index], isDarkMode);
                      },
                    ),
            ),
          ),

          // Loading Indicator
          if (isLoading)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: isDarkMode ? Colors.grey[850]! : Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[800]! : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDarkMode
                                  ? const Color(0xFF19B34B)
                                  : const Color(0xFF19B34B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "AgriBot is thinking...",
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.grey[300]
                                : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Input + Buttons
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: inputBgColor,
              border: Border(
                top: BorderSide(color: inputBorderColor, width: 1),
              ),
              boxShadow: isDarkMode
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Mic Button
                  GestureDetector(
                    onLongPress: startListening,
                    onLongPressUp: stopListening,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isRecording
                            ? Colors.red
                            : const Color(0xFF19B34B),
                        boxShadow: isRecording
                            ? [
                                BoxShadow(
                                  color: Colors.red.withOpacity(
                                    isDarkMode ? 0.4 : 0.3,
                                  ),
                                  blurRadius: 16,
                                  spreadRadius: 3,
                                ),
                              ]
                            : isDarkMode
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        isRecording ? Icons.mic : Icons.mic_none,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Text Input
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[700]! : Colors.grey[50],
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: inputBorderColor, width: 1),
                      ),
                      child: TextField(
                        controller: controller,
                        style: TextStyle(color: inputTextColor, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: "Type or speak your message...",
                          hintStyle: TextStyle(
                            color: hintTextColor,
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => sendTextMessage(),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Send Button
                  GestureDetector(
                    onTap: sendTextMessage,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: controller.text.trim().isNotEmpty
                            ? const Color(0xFF19B34B)
                            : (isDarkMode
                                  ? Colors.grey[700]!
                                  : Colors.grey[300]!),
                        boxShadow: isDarkMode
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        Icons.send,
                        color: controller.text.trim().isNotEmpty
                            ? Colors.white
                            : (isDarkMode
                                  ? Colors.grey[400]!
                                  : Colors.grey[600]!),
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
