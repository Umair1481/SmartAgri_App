import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, stopped }

class TTSService {
  late FlutterTts _flutterTts;
  TtsState _state = TtsState.stopped;
  String _currentLang = "en-US";
  
  TTSService() {
    _init();
  }
  
  bool get isPlaying => _state == TtsState.playing;
  TtsState get state => _state;
  
  Future<void> _init() async {
    _flutterTts = FlutterTts();
    
    await _flutterTts.setLanguage(_currentLang);
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setVolume(1.0);
    
    _flutterTts.setCompletionHandler(() {
      _state = TtsState.stopped;
    });
    
    _flutterTts.setCancelHandler(() {
      _state = TtsState.stopped;
    });
    
    _flutterTts.setErrorHandler((msg) {
      _state = TtsState.stopped;
    });
  }
  
  Future<void> speak(String text, {String langCode = "en-US"}) async {
    if (_state == TtsState.playing) {
      await stop();
    }
    
    if (langCode != _currentLang) {
      await setLanguage(langCode);
    }
    
    _state = TtsState.playing;
    await _flutterTts.speak(text);
  }
  
  Future<void> stop() async {
    await _flutterTts.stop();
    _state = TtsState.stopped;
  }
  
  Future<void> setLanguage(String langCode) async {
    await _flutterTts.setLanguage(langCode);
    _currentLang = langCode;
  }
  
  Future<void> dispose() async {
    await _flutterTts.stop();
  }
}