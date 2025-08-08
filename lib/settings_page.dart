import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _shakeEnabled = prefs.getBool('shakeEnabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
    });
  }

  void _toggleShake(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _shakeEnabled = value);
    prefs.setBool('shakeEnabled', value);
  }

  void _toggleVibration(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _vibrationEnabled = value);
    prefs.setBool('vibrationEnabled', value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Settings'),
        centerTitle: true,
        foregroundColor: AppColors.text,
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Enable Flip to Increment'),
            value: _shakeEnabled,
            onChanged: _toggleShake,
            activeColor: AppColors.button,
            tileColor: AppColors.background,
          ),
          SwitchListTile(
            title: const Text('Enable Vibration'),
            value: _vibrationEnabled,
            onChanged: _toggleVibration,
            activeColor: AppColors.button,
            tileColor: AppColors.background,
          ),
        ],
      ),
    );
  }
}
