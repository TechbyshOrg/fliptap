import 'package:flutter/material.dart';

import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'color_lib.dart';
import 'main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _shakeEnabled = true;
  bool _vibrationEnabled = true;
  bool _overlayEnabled = true;
  bool _overlayPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final hasPermission = await FlutterOverlayWindow.isPermissionGranted();
    setState(() {
      _shakeEnabled = prefs.getBool('shakeEnabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
      _overlayEnabled = prefs.getBool('overlayEnabled') ?? true;
      _overlayPermissionGranted = hasPermission;
    });
  }

  Future<void> _toggleShake(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _shakeEnabled = value);
    prefs.setBool('shakeEnabled', value);
  }

  Future<void> _toggleVibration(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _vibrationEnabled = value);
    prefs.setBool('vibrationEnabled', value);
  }

  Future<void> _toggleOverlay(bool value) async {
    if (value && !_overlayPermissionGranted) {
      await FlutterOverlayWindow.requestPermission();
      final granted = await FlutterOverlayWindow.isPermissionGranted();
      if (!granted) {
        _showPermissionDialog();
        return;
      }
      setState(() => _overlayPermissionGranted = true);
    }

    final prefs = await SharedPreferences.getInstance();
    setState(() => _overlayEnabled = value);
    prefs.setBool('overlayEnabled', value);
  }

  void _showPermissionDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Permission Required',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        content: Text(
          'To show the overlay popup when the app is minimised, please grant '
          '"Display over other apps" permission in Settings.',
          style: TextStyle(
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FlutterOverlayWindow.requestPermission();
              final granted = await FlutterOverlayWindow.isPermissionGranted();
              setState(() => _overlayPermissionGranted = granted);
            },
            child: const Text(
              'Open Settings',
              style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repo = CounterProvider.of(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          _sectionHeader('GESTURES & FEEDBACK', isDark),
          _buildSettingsCard([
            _buildSwitchTile(
              title: 'Flip to Increment',
              subtitle: 'Flip phone face-down to count',
              icon: Icons.flip_to_back_rounded,
              value: _shakeEnabled,
              onChanged: _toggleShake,
              isDark: isDark,
            ),
            _buildDivider(isDark),
            _buildSwitchTile(
              title: 'Haptic Feedback',
              subtitle: 'Vibrate on tap and sensor counts',
              icon: Icons.vibration_rounded,
              value: _vibrationEnabled,
              onChanged: _toggleVibration,
              isDark: isDark,
            ),
          ], isDark),

          const SizedBox(height: 24),

          _sectionHeader('APP THEME', isDark),
          _buildSettingsCard([
            _buildThemeOption(
              context: context,
              title: 'System Default',
              mode: ThemeMode.system,
              currentMode: repo.themeMode,
              icon: Icons.brightness_auto_rounded,
              isDark: isDark,
            ),
            _buildDivider(isDark),
            _buildThemeOption(
              context: context,
              title: 'Light Mode',
              mode: ThemeMode.light,
              currentMode: repo.themeMode,
              icon: Icons.light_mode_rounded,
              isDark: isDark,
            ),
            _buildDivider(isDark),
            _buildThemeOption(
              context: context,
              title: 'Dark Mode',
              mode: ThemeMode.dark,
              currentMode: repo.themeMode,
              icon: Icons.dark_mode_rounded,
              isDark: isDark,
            ),
          ], isDark),

          const SizedBox(height: 24),

          _sectionHeader('BACKGROUND OVERLAY', isDark),
          _buildSettingsCard([
            _buildSwitchTile(
              title: 'Overlay When Minimised',
              subtitle: _overlayPermissionGranted
                  ? 'Floating widget displays over other apps'
                  : 'Requires permission - tap to enable',
              icon: Icons.picture_in_picture_alt_rounded,
              value: _overlayEnabled,
              onChanged: _toggleOverlay,
              isDark: isDark,
              textColor: _overlayPermissionGranted ? null : Colors.orange,
            ),
            if (!_overlayPermissionGranted) ...[
              _buildDivider(isDark),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const Icon(Icons.security_rounded, color: AppColors.accent),
                title: Text(
                  'Grant System Permission',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                subtitle: Text(
                  'Allows display over other apps',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
                trailing: Icon(
                  Icons.open_in_new_rounded,
                  size: 16,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                onTap: () async {
                  await FlutterOverlayWindow.requestPermission();
                  final granted = await FlutterOverlayWindow.isPermissionGranted();
                  setState(() => _overlayPermissionGranted = granted);
                },
              ),
            ]
          ], isDark),

          const SizedBox(height: 32),
          
          Center(
            child: Text(
              'fliptap v1.2.0',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
    Color? textColor,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      secondary: Icon(
        icon,
        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: textColor ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required String title,
    required ThemeMode mode,
    required ThemeMode currentMode,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = currentMode == mode;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(
        icon,
        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_rounded, color: AppColors.accent)
          : null,
      onTap: () {
        CounterProvider.of(context).setThemeMode(mode);
      },
    );
  }
}