import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Port name used to receive counter updates pushed from the main app isolate.
const String kOverlayPortName = 'overlay_counter_port';

/// The widget rendered inside the system overlay (separate isolate).
/// Shows the current counter and an increment button, styled to match the app.
class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});

  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> {
  int _counter = 0;
  late ReceivePort _receivePort;

  @override
  void initState() {
    super.initState();
    _loadCounter();
    _setupPort();

    // Listen for data pushed from the main isolate (e.g. flip increments).
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is int) {
        setState(() => _counter = data);
      }
    });
  }

  Future<void> _loadCounter() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _counter = prefs.getInt('counter') ?? 0;
    });
  }

  void _setupPort() {
    _receivePort = ReceivePort();
    // Remove any stale registration first.
    IsolateNameServer.removePortNameMapping(kOverlayPortName);
    IsolateNameServer.registerPortWithName(
      _receivePort.sendPort,
      kOverlayPortName,
    );
    _receivePort.listen((message) {
      if (message is int) {
        setState(() => _counter = message);
      }
    });
  }

  Future<void> _incrementCounter() async {
    setState(() => _counter++);

    // Persist the new value.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('counter', _counter);

    HapticFeedback.lightImpact();

    // Notify main app isolate so its UI also updates when reopened.
    final mainPort = IsolateNameServer.lookupPortByName('main_counter_port');
    mainPort?.send(_counter);
  }

  @override
  void dispose() {
    _receivePort.close();
    IsolateNameServer.removePortNameMapping(kOverlayPortName);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Counter display
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_counter',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF212121),
                    ),
                  ),
                  const Text(
                    'count',
                    style: TextStyle(
                      fontSize: 9,
                      color: Color(0xFF9E9E9E),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 12),

              // Divider
              Container(
                width: 1,
                height: 36,
                color: const Color(0xFFE0E0E0),
              ),

              const SizedBox(width: 12),

              // Increment button
              GestureDetector(
                onTap: _incrementCounter,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF00897B),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Color(0xFF212121),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}