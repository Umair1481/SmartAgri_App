import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  String currentLang = "EN";

  LanguageProvider(String defaultLang) {
    currentLang = defaultLang;
  }

  Future<void> changeLang(String lang) async {
    currentLang = lang;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("app_lang", lang);

    notifyListeners();
  }
}
