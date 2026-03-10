import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'settings_page.dart';
import 'color_lib.dart';

const String kMainPortName = 'main_counter_port';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _counter = 0;
  bool _shakeEnabled = true;
  bool _vibrationEnabled = true;
  bool _overlayEnabled = true;
  bool _flipped = false;

  late ReceivePort _receivePort;

  static const _channel = MethodChannel('com.techbysh.fliptap/overlay');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPreferences();
    _setupMainPort();
    _recoverFromKill();
  }

  void _setupMainPort() {
    _receivePort = ReceivePort();
    IsolateNameServer.removePortNameMapping(kMainPortName);
    IsolateNameServer.registerPortWithName(
      _receivePort.sendPort,
      kMainPortName,
    );
    _receivePort.listen((message) {
      if (message is int) {
        // ✅ Update counter immediately when overlay sends a new value
        setState(() => _counter = message);
        // ✅ Also persist it so SharedPreferences stays in sync
        _persistCounter(message);
      }
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    // ✅ Force reload from disk every time
    await prefs.reload();
    setState(() {
      _counter = prefs.getInt('counter') ?? 0;
      _shakeEnabled = prefs.getBool('shakeEnabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
      _overlayEnabled = prefs.getBool('overlayEnabled') ?? true;
    });

    accelerometerEventStream().listen(_handleFlip);
  }

  // ✅ Separated counter persist so overlay port listener can call it too
  Future<void> _persistCounter(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('counter', value);
  }

  Future<void> _saveCounter() async {
    await _persistCounter(_counter);
  }

  void _handleFlip(AccelerometerEvent event) {
    if (!_shakeEnabled) return;
    final z = event.z;
    if (!_flipped && z < -7) {
      _flipped = true;
      _incrementCounter();
    } else if (_flipped && z > 7) {
      _flipped = false;
    }
  }

  void _incrementCounter() {
    setState(() => _counter++);
    _saveCounter();
    _pushCounterToOverlay();
    if (_vibrationEnabled) HapticFeedback.lightImpact();
  }

  void _decrementCounter() {
    setState(() {
      if (_counter > 0) _counter--;
    });
    _saveCounter();
    _pushCounterToOverlay();
    if (_vibrationEnabled) HapticFeedback.selectionClick();
  }

  void _resetCounter() {
    setState(() => _counter = 0);
    _saveCounter();
    _pushCounterToOverlay();
    if (_vibrationEnabled) HapticFeedback.heavyImpact();
  }

  void _pushCounterToOverlay() {
    final overlayPort =
        IsolateNameServer.lookupPortByName('overlay_counter_port');
    overlayPort?.send(_counter);
    FlutterOverlayWindow.shareData(_counter);
  }

  // ── Overlay lifecycle ────────────────────────────────────────────────────

  Future<void> _showOverlay() async {
    if (!_overlayEnabled) return;

    final hasPermission = await FlutterOverlayWindow.isPermissionGranted();
    if (!hasPermission) {
      await FlutterOverlayWindow.requestPermission();
      return;
    }

    final isActive = await FlutterOverlayWindow.isActive();
    if (isActive) return;

    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: 'FlipTap Counter',
      overlayContent: 'Counter overlay active',
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.none,
      width: 400,
      height: 200,
      startPosition: const OverlayPosition(0, -200),
    );

    await _channel.invokeMethod('setOverlayShowing', {'showing': true});

    await Future.delayed(const Duration(milliseconds: 300));
    _pushCounterToOverlay();
  }

  Future<void> _closeOverlay() async {
    final isActive = await FlutterOverlayWindow.isActive();
    if (isActive) {
      await FlutterOverlayWindow.closeOverlay();
    }
    await _channel.invokeMethod('setOverlayShowing', {'showing': false});
  }

  Future<void> _recoverFromKill() async {
    try {
      final wasShowing =
          await _channel.invokeMethod<bool>('wasOverlayShowingOnKill') ?? false;
      if (wasShowing) {
        await _closeOverlay();
      }
    } catch (_) {}
  }

  // ── App lifecycle ────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.paused:
        if (_overlayEnabled) await _showOverlay();
        break;

      case AppLifecycleState.resumed:
        // ✅ First close overlay, then wait briefly, then reload from prefs
        // This gives the overlay time to save its latest counter value
        await _closeOverlay();
        await Future.delayed(const Duration(milliseconds: 150));
        await _loadPreferences();
        break;

      case AppLifecycleState.detached:
        await _closeOverlay();
        break;

      default:
        break;
    }
  }

  void _goToSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
    _loadPreferences();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _receivePort.close();
    IsolateNameServer.removePortNameMapping(kMainPortName);
    super.dispose();
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 0,
          side: BorderSide(color: AppColors.primary, width: 1),
        ),
        child: Icon(
          icon,
          color: AppColors.darkText,
          size: 20,
          shadows: const [
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