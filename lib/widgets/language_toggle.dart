import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LanguageToggle extends StatelessWidget {
  final String selectedLang;
  final Function(String) onChange;

  const LanguageToggle({
    super.key,
    required this.selectedLang,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return Container(
      width: w * 0.40,
      height: h * 0.065,
      padding: EdgeInsets.symmetric(horizontal: w * 0.015),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(w * 0.03),
        border: Border.all(color: Colors.grey.shade200, width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChange("EN"),
              child: Container(
                height: h * 0.045,
                decoration: BoxDecoration(
                  color: selectedLang == "EN"
                      ? const Color(0xFF21C357)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(w * 0.03),
                ),
                child: Center(
                  child: Text(
                    "EN",
                    style: GoogleFonts.inter(
                      fontSize: w * 0.035,
                      fontWeight: FontWeight.bold,
                      color: selectedLang == "EN"
                          ? Colors.white
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
              onTap: () => onChange("UR"),
              child: Container(
                height: h * 0.045,
                decoration: BoxDecoration(
                  color: selectedLang == "UR"
                      ? const Color(0xFF21C357)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(w * 0.03),
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
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
