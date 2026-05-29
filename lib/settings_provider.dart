import 'package:flutter/material.dart';

class SettingsProvider extends ChangeNotifier {
  // Default values
  String _fontFamily = "OpenDyslexic";
  double _fontSize = 18;
  Color _backgroundColor = const Color(0xFFFDF6E3); // warm cream
  Color _textColor = Colors.black;

  String get fontFamily => _fontFamily;
  double get fontSize => _fontSize;
  Color get backgroundColor => _backgroundColor;
  Color get textColor => _textColor;

  void setFontFamily(String font) {
    _fontFamily = font;
    notifyListeners();
  }

  void setFontSize(double size) {
    _fontSize = size;
    notifyListeners();
  }

  void setTheme(String theme) {
    if (theme == "Light") {
      _backgroundColor = const Color(0xFFFDF6E3);
      _textColor = Colors.black;
    } else if (theme == "Sepia") {
      _backgroundColor = const Color(0xFFF4ECD8);
      _textColor = Colors.brown[900]!;
    } else if (theme == "Dark") {
      _backgroundColor = Colors.black;
      _textColor = Colors.white;
    }
    notifyListeners();
  }
}
