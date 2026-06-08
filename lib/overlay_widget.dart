import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'color_lib.dart';
import 'models/counter_model.dart';

/// Port name used to receive counter updates pushed from the main app isolate.
const String kOverlayPortName = 'overlay_counter_port';

class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});

  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> {
  int _counter = 0;
  int _themeIndex = 0;
  late ReceivePort _receivePort;

  @override
  void initState() {
    super.initState();
    _loadCounter();
    _setupPort();

    // Listen for data pushed from the main isolate (e.g. flip increments).
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is int) {
        _loadCounter();
      }
    });
  }

  Future<void> _loadCounter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final rawJson = prefs.getString('fliptap_counters_list');
    final activeId = prefs.getString('fliptap_active_counter_id');

    if (rawJson != null && activeId != null) {
      try {
        final List<dynamic> parsed = jsonDecode(rawJson) as List<dynamic>;
        final List<CounterModel> counters = parsed
            .map((item) => CounterModel.fromJson(item as Map<String, dynamic>))
            .toList();
        final activeIndex = counters.indexWhere((c) => c.id == activeId);
        if (activeIndex != -1) {
          final active = counters[activeIndex];
          setState(() {
            _counter = active.value;
            _themeIndex = active.themeIndex;
          });
          return;
        }
      } catch (_) {}
    }

    setState(() {
      _counter = prefs.getInt('counter') ?? 0;
      _themeIndex = 0;
    });
  }

  void _setupPort() {
    _receivePort = ReceivePort();
    IsolateNameServer.removePortNameMapping(kOverlayPortName);
    IsolateNameServer.registerPortWithName(
      _receivePort.sendPort,
      kOverlayPortName,
    );
    _receivePort.listen((message) {
      if (message is int) {
        _loadCounter();
      }
    });
  }

  Future<void> _incrementCounter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final rawJson = prefs.getString('fliptap_counters_list');
    final activeId = prefs.getString('fliptap_active_counter_id');

    int newValue = _counter + 1;

    if (rawJson != null && activeId != null) {
      try {
        final List<dynamic> parsed = jsonDecode(rawJson) as List<dynamic>;
        final List<Map<String, dynamic>> countersJson =
            parsed.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final activeIdx = countersJson.indexWhere((c) => c['id'] == activeId);
        if (activeIdx != -1) {
          final activeItem = countersJson[activeIdx];
          final currentVal = activeItem['value'] as int? ?? 0;
          newValue = currentVal + 1;
          activeItem['value'] = newValue;

          final List<dynamic> history = activeItem['history'] as List? ?? [];
          history.add(DateTime.now().millisecondsSinceEpoch);
          activeItem['history'] = history;

          await prefs.setString('fliptap_counters_list', jsonEncode(countersJson));
        }
      } catch (_) {}
    }

    setState(() {
      _counter = newValue;
    });

    await prefs.setInt('counter', newValue);
    HapticFeedback.lightImpact();

    // Notify main app isolate
    final mainPort = IsolateNameServer.lookupPortByName('main_counter_port');
    mainPort?.send(newValue);
  }

  @override
  void dispose() {
    _receivePort.close();
    IsolateNameServer.removePortNameMapping(kOverlayPortName);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme = AppColors.getThemeByIndex(_themeIndex);

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xE6151720), // Translucent premium dark color
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF26293A), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Theme gradient color indicator strip
              Container(
                width: 6,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: LinearGradient(
                    colors: activeTheme.gradient,
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Counter value
              Text(
                '$_counter',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFF1F3F9),
                ),
              ),

              const SizedBox(width: 12),

              // Elegant Divider
              Container(
                width: 1,
                height: 24,
                color: const Color(0xFF26293A),
              ),

              const SizedBox(width: 12),

              // Increment Button
              GestureDetector(
                onTap: _incrementCounter,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: activeTheme.gradient),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: activeTheme.primaryColor.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
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