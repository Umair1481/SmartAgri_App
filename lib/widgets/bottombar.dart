import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../state/themeprovier.dart';

class BottomNavBarWidget extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;
  final String selectedLang;

  const BottomNavBarWidget({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    required this.selectedLang,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: true);
    final isDarkMode = themeProvider.isDarkMode;

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900]! : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDarkMode ? Colors.grey[700]! : const Color(0xFFE4E6E9),
            width: 1,
          ),
        ),
        boxShadow: isDarkMode
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
      ),
      child: Row(
        children: [
          // Dashboard - Index 0
          _navItemIcon(
            index: 0,
            iconAsset: 'assets/images/dashboard.png',
            labelEN: 'Dashboard',
            labelUR: 'ڈیش بورڈ',
            isDarkMode: isDarkMode,
            activeIndex: selectedIndex,
          ),

          // Disease Detection - Index 1
          _navItemIcon(
            index: 1,
            iconAsset: 'assets/images/disease.png',
            labelEN: 'Disease',
            labelUR: 'امراض',
            isDarkMode: isDarkMode,
            activeIndex: selectedIndex,
          ),

          // AI Advice - Index 2
          _navItemBuilt(
            index: 2,
            icon: Icons.tips_and_updates,
            labelEN: 'AI Advice',
            labelUR: 'AI مشورہ',
            isDarkMode: isDarkMode,
            activeIndex: selectedIndex,
          ),

          // Weather - Index 3
          _navItemBuilt(
            index: 3,
            icon: Icons.cloud,
            labelEN: 'Weather',
            labelUR: 'موسم',
            isDarkMode: isDarkMode,
            activeIndex: selectedIndex,
          ),

          // Chat - Index 4
          _navItemIcon(
            index: 4,
            iconAsset: 'assets/images/chat.png',
            labelEN: 'Chat',
            labelUR: 'چیٹ',
            isDarkMode: isDarkMode,
            activeIndex: selectedIndex,
          ),

          // User - Index 5 (LAST POSITION)
          _navItemBuilt(
            index: 5,
            icon: Icons.person,
            labelEN: 'User',
            labelUR: 'صارف',
            isDarkMode: isDarkMode,
            activeIndex: selectedIndex,
          ),
        ].map((e) => Expanded(child: e)).toList(),
      ),
    );
  }

  // BUILT-IN ICON NAV ITEM
  Widget _navItemBuilt({
    required int index,
    required IconData icon,
    required String labelEN,
    required String labelUR,
    required bool isDarkMode,
    required int activeIndex,
  }) {
    final active = activeIndex == index;
    final label = selectedLang == "UR" ? labelUR : labelEN;
    final primaryColor = const Color(0xFF21C357);
    final inactiveColor = isDarkMode
        ? Colors.grey[500]!
        : const Color(0xFFAEAEAE);

    return GestureDetector(
      onTap: () => onTap(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: active ? primaryColor : inactiveColor),
          const SizedBox(height: 4),
          Text(
            label,
            textDirection: selectedLang == "UR"
                ? TextDirection.rtl
                : TextDirection.ltr,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: active ? primaryColor : inactiveColor,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ASSET IMAGE NAV ITEM
  Widget _navItemIcon({
    required int index,
    required String iconAsset,
    required String labelEN,
    required String labelUR,
    required bool isDarkMode,
    required int activeIndex,
  }) {
    final active = activeIndex == index;
    final label = selectedLang == "UR" ? labelUR : labelEN;
    final primaryColor = const Color(0xFF21C357);
    final inactiveColor = isDarkMode
        ? Colors.grey[500]!
        : const Color(0xFFAEAEAE);

    return GestureDetector(
      onTap: () => onTap(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              active ? primaryColor : inactiveColor,
              BlendMode.srcIn,
            ),
            child: Image.asset(
              iconAsset,
              width: 22,
              height: 22,
              errorBuilder: (context, error, stackTrace) {
                // Fallback icon if image fails to load
                return Icon(
                  _getFallbackIcon(index),
                  size: 22,
                  color: active ? primaryColor : inactiveColor,
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textDirection: selectedLang == "UR"
                ? TextDirection.rtl
                : TextDirection.ltr,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: active ? primaryColor : inactiveColor,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method for fallback icons
  IconData _getFallbackIcon(int index) {
    switch (index) {
      case 0: // Dashboard
        return Icons.dashboard;
      case 1: // Disease
        return Icons.health_and_safety;
      case 4: // Chat
        return Icons.chat;
      default:
        return Icons.error;
    }
  }
}
