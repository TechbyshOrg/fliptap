import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'color_lib.dart';

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
      // Request permission first
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
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Permission Required',
          style: TextStyle(
            color: AppColors.darkText,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'To show the overlay popup when the app is minimised, please grant '
          '"Display over other apps" permission in Settings.',
          style: TextStyle(color: AppColors.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FlutterOverlayWindow.requestPermission();
              final granted =
                  await FlutterOverlayWindow.isPermissionGranted();
              setState(() => _overlayPermissionGranted = granted);
            },
            child: const Text(
              'Open Settings',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.darkText,
          ),
        ),
        centerTitle: true,
        foregroundColor: AppColors.text,
      ),
      body: ListView(
        children: [
          // ── Counter behaviour ───────────────────────────────────────────
          _sectionHeader('Counter'),

          SwitchListTile(
            title: const Text(
              'Flip to Increment',
              style: TextStyle(color: AppColors.darkText),
            ),
            subtitle: const Text(
              'Flip phone face-down to count',
              style: TextStyle(color: AppColors.cardFadeText, fontSize: 12),
            ),
            value: _shakeEnabled,
            onChanged: _toggleShake,
            activeColor: AppColors.button,
            tileColor: AppColors.cardBackground,
          ),

          SwitchListTile(
            title: const Text(
              'Vibration Feedback',
              style: TextStyle(color: AppColors.darkText),
            ),
            subtitle: const Text(
              'Haptic feedback on tap / flip',
              style: TextStyle(color: AppColors.cardFadeText, fontSize: 12),
            ),
            value: _vibrationEnabled,
            onChanged: _toggleVibration,
            activeColor: AppColors.button,
            tileColor: AppColors.cardBackground,
          ),

          const SizedBox(height: 16),

          // ── Overlay ─────────────────────────────────────────────────────
          _sectionHeader('Overlay Popup'),

          SwitchListTile(
            title: const Text(
              'Show Overlay When Minimised',
              style: TextStyle(color: AppColors.darkText),
            ),
            subtitle: Text(
              _overlayPermissionGranted
                  ? 'Floating counter shows over other apps'
                  : 'Permission not granted — tap to request',
              style: TextStyle(
                color: _overlayPermissionGranted
                    ? AppColors.cardFadeText
                    : Colors.orange,
                fontSize: 12,
              ),
            ),
            value: _overlayEnabled,
            onChanged: _toggleOverlay,
            activeColor: AppColors.button,
            tileColor: AppColors.cardBackground,
          ),

          if (!_overlayPermissionGranted)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextButton.icon(
                onPressed: () async {
                  await FlutterOverlayWindow.requestPermission();
                  final granted =
                      await FlutterOverlayWindow.isPermissionGranted();
                  setState(() => _overlayPermissionGranted = granted);
                },
                icon: const Icon(Icons.open_in_new,
                    color: AppColors.primary, size: 16),
                label: const Text(
                  'Grant "Display over other apps" permission',
                  style: TextStyle(color: AppColors.primary, fontSize: 13),
                ),
              ),
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}