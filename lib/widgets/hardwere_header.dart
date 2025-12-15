import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HardHeader extends StatelessWidget {
  const HardHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios,
              size: 16,
              color: Color(0xFF686868),
            ),
          ),
          const SizedBox(width: 8),
          Image.asset(
            'assets/images/logo_left.png',
            width: 29,
            height: 29,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return const Icon(
                Icons.agriculture,
                size: 29,
                color: Color(0xFF22C358),
              );
            },
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
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none,
              color: Color(0xFF686868),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.help_outline, color: Color(0xFF686868)),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF686868)),
          ),
        ],
      ),
    );
  }
}
