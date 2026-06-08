import 'package:flutter/material.dart';

class CounterThemeData {
  final String name;
  final Color primaryColor;
  final Color accentColor;
  final List<Color> gradient;
  final Color glowColor;

  const CounterThemeData({
    required this.name,
    required this.primaryColor,
    required this.accentColor,
    required this.gradient,
    required this.glowColor,
  });
}

class AppColors {
  // Common Colors
  static const Color accent = Color(0xFF6C63FF);
  
  // Premium Dark Theme Palette (Obsidian/Slate)
  static const Color darkBg = Color(0xFF0D0E12);
  static const Color darkCard = Color(0xFF151720);
  static const Color darkCardPressed = Color(0xFF1C1E2A);
  static const Color darkBorder = Color(0xFF26293A);
  static const Color darkTextPrimary = Color(0xFFF1F3F9);
  static const Color darkTextSecondary = Color(0xFF8C93AB);
  static const Color darkTextMuted = Color(0xFF4A4E69);
  static const Color darkGlow = Color(0x1F6C63FF);

  // Premium Light Theme Palette (Warm Soft Off-white)
  static const Color lightBg = Color(0xFFF9FAFC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardPressed = Color(0xFFF1F3F6);
  static const Color lightBorder = Color(0xFFE2E6EE);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);
  static const Color lightGlow = Color(0x0F0F172A);

  // Predefined Premium Color Themes for individual counters
  static const List<CounterThemeData> counterThemes = [
    CounterThemeData(
      name: 'Emerald Aurora',
      primaryColor: Color(0xFF10B981),
      accentColor: Color(0xFF34D399),
      gradient: [Color(0xFF059669), Color(0xFF10B981)],
      glowColor: Color(0x3310B981),
    ),
    CounterThemeData(
      name: 'Indigo Twilight',
      primaryColor: Color(0xFF6366F1),
      accentColor: Color(0xFF818CF8),
      gradient: [Color(0xFF4F46E5), Color(0xFF6366F1)],
      glowColor: Color(0x336366F1),
    ),
    CounterThemeData(
      name: 'Sunset Coral',
      primaryColor: Color(0xFFF43F5E),
      accentColor: Color(0xFFFB7185),
      gradient: [Color(0xFFE11D48), Color(0xFFF43F5E)],
      glowColor: Color(0x33F43F5E),
    ),
    CounterThemeData(
      name: 'Amber Glow',
      primaryColor: Color(0xFFF59E0B),
      accentColor: Color(0xFFFBBF24),
      gradient: [Color(0xFFD97706), Color(0xFFF59E0B)],
      glowColor: Color(0x33F59E0B),
    ),
    CounterThemeData(
      name: 'Royal Amethyst',
      primaryColor: Color(0xFF8B5CF6),
      accentColor: Color(0xFFA78BFA),
      gradient: [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
      glowColor: Color(0x338B5CF6),
    ),
  ];

  static CounterThemeData getThemeByIndex(int index) {
    if (index < 0 || index >= counterThemes.length) {
      return counterThemes[0];
    }
    return counterThemes[index];
  }
}
