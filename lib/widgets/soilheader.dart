// header_widget.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HeaderWidget extends StatelessWidget {
  final bool isSpeaking;
  final VoidCallback onSpeakPressed;

  const HeaderWidget({
    super.key,
    required this.isSpeaking,
    required this.onSpeakPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 35, 16, 15),
      child: Row(
        children: [
          Image.network(
            'https://firebasestorage.googleapis.com/v0/b/codeless-app.appspot.com/o/projects%2F0SB2MS1_SmL3yiBAMZgN%2F7647655bf07ad3bc8d79daf4d2a787c4f1437d4eImage.png?alt=media&token=1b51c775-41e2-4de1-ac69-d428ce697477',
            width: 29,
            height: 29,
          ),
          const SizedBox(width: 8),

          Text(
            'SmartAgri',
            style: GoogleFonts.inter(
              color: const Color(0xFF686868),
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),

          const Spacer(),

          IconButton(
            onPressed: onSpeakPressed,
            icon: Icon(
              isSpeaking ? Icons.volume_off : Icons.volume_up,
              color: isSpeaking ? Color(0xFF21C357) : Color(0xFF686868),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}
