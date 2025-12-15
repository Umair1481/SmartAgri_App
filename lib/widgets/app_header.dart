import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartagriapp/screens/login_screen.dart';

class AppHeader extends StatelessWidget {
  final String selectedLang;
  const AppHeader({super.key, required this.selectedLang});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 28, left: 16, right: 16, bottom: 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            icon: const Icon(
              Icons.arrow_back_ios,
              size: 16,
              color: Color(0xFF686868),
            ),
          ),

          const SizedBox(width: 8),

          Image.asset('assets/images/logo_left.png', width: 29, height: 29),

          const SizedBox(width: 8),

          Text(
            "SmartAgri",
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF686868),
            ),
          ),

          const Spacer(),

          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.volume_up_outlined,
              color: Color(0xFF686868),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.person_outline, color: Color(0xFF686868)),
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
