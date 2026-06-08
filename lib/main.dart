import 'package:flutter/material.dart';
import 'home_page.dart';
import 'overlay_widget.dart';
import 'repository/counter_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final repository = CounterRepository();
  await repository.init();

  runApp(
    CounterProvider(
      notifier: repository,
      child: const CounterApp(),
    ),
  );
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

class CounterProvider extends InheritedNotifier<CounterRepository> {
  const CounterProvider({
    super.key,
    required super.notifier,
    required super.child,
  });

  static CounterRepository of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<CounterProvider>();
    assert(provider != null, 'No CounterProvider found in context');
    return provider!.notifier!;
  }
}

class CounterApp extends StatelessWidget {
  const CounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0D0E12), // AppColors.darkBg
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF6C63FF),
        surface: Color(0xFF151720),
      ),
    );

    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF9FAFC), // AppColors.lightBg
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF6C63FF),
        surface: Color(0xFFFFFFFF),
      ),
    );

    return MaterialApp(
      title: 'FlipTap',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: CounterProvider.of(context).themeMode,
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}