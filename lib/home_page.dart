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
        title: const Text('FlipTap'),
        titleTextStyle: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.darkText,
          fontFamily: 'RobotoMono',
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _goToSettings,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // Your tappable counter card
                    Expanded(
                      child: GestureDetector(
                        onTap: _incrementCounter,
                        child: Center(
                          child: Container(
                            height: 400,
                            width: 300,
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.cardBorder,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                const SizedBox(height: 160),
                                Center(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 100),
                                    child: Text(
                                      '$_counter',
                                      key: ValueKey<int>(_counter),
                                      style: const TextStyle(
                                        fontSize: 48,
                                        color: AppColors.cardText,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 100),
                                const Text(
                                  'Tap to Increment',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.cardFadeText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _smallButton(Icons.remove, _decrementCounter),
                        const SizedBox(width: 20),
                        _smallButton(Icons.refresh, _resetCounter),
                      ],
                    ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

  }

  Widget _smallButton(IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 100,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 0,
          side: BorderSide(color: AppColors.primary, width: 1),
        ),
        child: Icon(
          icon,
          color: AppColors.darkText,
          size: 20,
          // Use shadows to simulate a thicker stroke
          shadows: [
            Shadow(
              blurRadius: 0,
              color: AppColors.primary,
              offset: Offset(0, 0),
            ),
            Shadow(
              blurRadius: 2,
              color: AppColors.primary,
              offset: Offset(0, 0),
            ),
          ],
        ),
      ),
    );
  }
}
