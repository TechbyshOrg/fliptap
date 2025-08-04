import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_page.dart';
import 'color_lib.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _counter = 0;
  bool _shakeEnabled = true;
  bool _vibrationEnabled = true;
  bool _flipped = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _counter = prefs.getInt('counter') ?? 0;
    _shakeEnabled = prefs.getBool('shakeEnabled') ?? true;
    _vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;

    setState(() {}); // Update UI

    // ✅ Start accelerometer stream after preferences are loaded
    accelerometerEventStream().listen(_handleFlip);
  }

  Future<void> _saveCounter() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('counter', _counter);
  }

  void _handleFlip(AccelerometerEvent event) {
    if (!_shakeEnabled) return;

    double z = event.z;

    if (!_flipped && z < -7) {
      _flipped = true;
      _incrementCounter();
    } else if (_flipped && z > 7) {
      _flipped = false;
    }
  }

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
    _saveCounter();

    if (_vibrationEnabled) {
      HapticFeedback.lightImpact();
      debugPrint('Vibrating: lightImpact');
    }
  }

  void _decrementCounter() {
    setState(() {
      if (_counter > 0) _counter--;
    });
    _saveCounter();

    if (_vibrationEnabled) {
      HapticFeedback.selectionClick();
      debugPrint('Vibrating: selectionClick');
    }
  }

  void _resetCounter() {
    setState(() {
      _counter = 0;
    });
    _saveCounter();

    if (_vibrationEnabled) {
      HapticFeedback.heavyImpact();
      debugPrint('Vibrating: heavyImpact');
    }
  }

  void _goToSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
    _loadPreferences(); // Reload after settings update
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Wibble Counter'),
        titleTextStyle: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontFamily: 'RobotoMono',
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _goToSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _incrementCounter,
              child: Center(
                child: Container(
                  height: 300,
                  width: 300,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 110),
                      Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 100),
                          child: Text(
                            '$_counter',
                            key: ValueKey<int>(_counter),
                            style: const TextStyle(
                              fontSize: 48,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 60),
                      const Text(
                        'Tap to Increment',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white60,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _smallButton(Icons.remove, _decrementCounter),
              const SizedBox(width: 20),
              _smallButton(Icons.refresh, _resetCounter),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _smallButton(IconData icon, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      child: Icon(icon, color: Colors.white),
    );
  }
}
