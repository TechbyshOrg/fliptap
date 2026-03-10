import 'package:flutter/material.dart';
import 'home_page.dart';
import 'overlay_widget.dart';

void main() {
  runApp(const CounterApp());
}

/// Overlay entry point — required by flutter_overlay_window.
/// This runs in a separate isolate when the overlay is shown.
@pragma('vm:entry-point')
void overlayMain() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverlayWidget(),
    ),
  );
}

class CounterApp extends StatelessWidget {
  const CounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlipTap',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}