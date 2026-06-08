import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'color_lib.dart';
import 'main.dart';
import 'models/counter_model.dart';
import 'repository/counter_repository.dart';
import 'settings_page.dart';

const String kMainPortName = 'main_counter_port';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver, TickerProviderStateMixin {
  bool _shakeEnabled = true;
  bool _vibrationEnabled = true;
  bool _overlayEnabled = true;
  bool _flipped = false;
  bool _showLogs = false;

  late ReceivePort _receivePort;
  StreamSubscription<AccelerometerEvent>? _sensorSubscription;

  // Celebration particle controllers
  final List<CelebrationParticle> _particles = [];
  late AnimationController _particleAnimationController;

  static const _channel = MethodChannel('com.techbysh.fliptap/overlay');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPreferences();
    _setupMainPort();
    _recoverFromKill();

    _particleAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addListener(() {
        if (_particles.isNotEmpty) {
          setState(() {
            _particles.removeWhere((p) => p.isDead);
            for (final p in _particles) {
              p.update();
            }
          });
        }
      });
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
        // Overlay sent update: reload state from SharedPrefs
        _reloadRepo();
      }
    });
  }

  Future<void> _reloadRepo() async {
    final repo = CounterProvider.of(context);
    await repo.reload();
    _pushCounterToOverlay();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    setState(() {
      _shakeEnabled = prefs.getBool('shakeEnabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
      _overlayEnabled = prefs.getBool('overlayEnabled') ?? true;
    });

    _sensorSubscription?.cancel();
    _sensorSubscription = accelerometerEventStream().listen(_handleFlip);
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
    final repo = CounterProvider.of(context);
    final active = repo.activeCounter;
    if (active == null) return;

    final wasTargetReached = active.target > 0 && active.value >= active.target;
    repo.incrementActive();

    // Check if goal just reached after increment
    final currentVal = active.value + 1;
    final isTargetReachedNow = active.target > 0 && currentVal == active.target;

    if (isTargetReachedNow && !wasTargetReached) {
      _triggerCelebration();
    }

    _pushCounterToOverlay();
    if (_vibrationEnabled) {
      HapticFeedback.mediumImpact();
    }
  }

  void _decrementCounter() {
    final repo = CounterProvider.of(context);
    repo.decrementActive();
    _pushCounterToOverlay();
    if (_vibrationEnabled) {
      HapticFeedback.selectionClick();
    }
  }

  void _resetCounter() {
    final repo = CounterProvider.of(context);
    repo.resetActive();
    _pushCounterToOverlay();
    if (_vibrationEnabled) {
      HapticFeedback.heavyImpact();
    }
  }

  void _triggerCelebration() {
    // Spawn celebration particles
    final random = math.Random();
    _particles.clear();
    for (int i = 0; i < 60; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final speed = random.nextDouble() * 8 + 4;
      _particles.add(
        CelebrationParticle(
          x: 150, // Center of our standard layout card
          y: 200,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed - 2.5, // slightly upward bias
          color: AppColors.counterThemes[random.nextInt(AppColors.counterThemes.length)].primaryColor,
          size: random.nextDouble() * 8 + 6,
        ),
      );
    }
    _particleAnimationController.forward(from: 0.0);
  }

  void _pushCounterToOverlay() {
    final repo = CounterProvider.of(context);
    final active = repo.activeCounter;
    if (active == null) return;

    final overlayPort = IsolateNameServer.lookupPortByName('overlay_counter_port');
    overlayPort?.send(active.value);
    FlutterOverlayWindow.shareData(active.value);
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
      overlayContent: 'Active floating counter',
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.none,
      width: WindowSize.matchParent,
      height: 320,
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
      final wasShowing = await _channel.invokeMethod<bool>('wasOverlayShowingOnKill') ?? false;
      if (wasShowing) {
        await _closeOverlay();
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.paused:
        if (_overlayEnabled) await _showOverlay();
        break;

      case AppLifecycleState.resumed:
        await _closeOverlay();
        await Future.delayed(const Duration(milliseconds: 150));
        await _reloadRepo();
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
    _sensorSubscription?.cancel();
    _receivePort.close();
    _particleAnimationController.dispose();
    IsolateNameServer.removePortNameMapping(kMainPortName);
    super.dispose();
  }

  void _addNewCounterSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController();
    final targetController = TextEditingController();
    int selectedTheme = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Create New Counter',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                    decoration: InputDecoration(
                      labelText: 'Counter Name',
                      labelStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: AppColors.accent, width: 2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                    decoration: InputDecoration(
                      labelText: 'Target Limit (Optional)',
                      labelStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      helperText: '0 or empty means no goal target',
                      helperStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: AppColors.accent, width: 2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Select Color Theme',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: AppColors.counterThemes.length,
                      itemBuilder: (context, idx) {
                        final theme = AppColors.counterThemes[idx];
                        final isSelected = selectedTheme == idx;
                        return GestureDetector(
                          onTap: () => setModalState(() => selectedTheme = idx),
                          child: Container(
                            margin: const EdgeInsets.only(right: 14),
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: theme.gradient),
                              border: Border.all(
                                color: isSelected
                                    ? (isDark ? Colors.white : Colors.black)
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: theme.primaryColor.withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameController.text.trim().isEmpty) return;
                        final target = int.tryParse(targetController.text) ?? 0;
                        final repo = CounterProvider.of(context);
                        repo.addCounter(
                          nameController.text.trim(),
                          target: target,
                          themeIndex: selectedTheme,
                        );
                        Navigator.pop(context);
                        if (_vibrationEnabled) HapticFeedback.mediumImpact();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Add Counter',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirm(CounterModel counter) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Delete Counter?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete "${counter.name}"? This cannot be undone.',
            style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.accent)),
            ),
            TextButton(
              onPressed: () {
                final repo = CounterProvider.of(context);
                repo.deleteCounter(counter.id);
                Navigator.pop(context);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = CounterProvider.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = repo.activeCounter;

    if (active == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final activeTheme = AppColors.getThemeByIndex(active.themeIndex);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text(
          'fliptap.',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              _showLogs ? Icons.history_toggle_off : Icons.history,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            onPressed: () => setState(() => _showLogs = !_showLogs),
          ),
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            onPressed: _goToSettings,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Horizontal Counters Swiper
            _buildCountersSwiper(repo, isDark),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Main Tap Interaction card
                    Expanded(
                      flex: 3,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _buildTapCard(active, activeTheme, isDark),
                          // Custom Painted Celebration Confetti Overlay
                          if (_particles.isNotEmpty)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: ParticlePainter(_particles),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Log Panel on the side if toggled
                    if (_showLogs) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: _buildLogsPanel(active, isDark),
                      ),
                    ]
                  ],
                ),
              ),
            ),

            // Controls Row
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0, left: 24.0, right: 24.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.remove_rounded,
                      label: 'Subtract',
                      onTap: _decrementCounter,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onDoubleTap: _resetCounter,
                      child: _buildActionButton(
                        icon: Icons.refresh_rounded,
                        label: 'Double Tap Reset',
                        onTap: () {
                          // Visual hint
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Double-tap to reset counter'),
                              duration: Duration(milliseconds: 600),
                            ),
                          );
                        },
                        isDark: isDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountersSwiper(CounterRepository repo, bool isDark) {
    return Container(
      height: 72,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: repo.counters.length + 1,
        itemBuilder: (context, idx) {
          if (idx == repo.counters.length) {
            // "+" Add New Card
            return GestureDetector(
              onTap: _addNewCounterSheet,
              child: Container(
                width: 60,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  size: 26,
                ),
              ),
            );
          }

          final counter = repo.counters[idx];
          final isActive = repo.activeCounterId == counter.id;
          final theme = AppColors.getThemeByIndex(counter.themeIndex);

          return GestureDetector(
            onTap: () {
              repo.setActiveCounter(counter.id);
              _pushCounterToOverlay();
              if (_vibrationEnabled) HapticFeedback.selectionClick();
            },
            onLongPress: () {
              if (repo.counters.length > 1) {
                _showDeleteConfirm(counter);
              }
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isActive
                    ? theme.primaryColor.withValues(alpha: 0.15)
                    : (isDark ? AppColors.darkCard : AppColors.lightCard),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isActive
                      ? theme.primaryColor
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: theme.gradient),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        counter.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                          color: isActive
                              ? (isDark ? Colors.white : Colors.black)
                              : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        ),
                      ),
                      Text(
                        '${counter.value}',
                        style: TextStyle(fontFamily: 'monospace', 
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isActive ? theme.primaryColor : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTapCard(CounterModel active, CounterThemeData theme, bool isDark) {
    final double progress = active.target > 0 ? (active.value / active.target).clamp(0.0, 1.0) : 0.0;

    return TouchRippleArea(
      onTap: _incrementCounter,
      rippleColor: theme.primaryColor.withValues(alpha: 0.15),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black45 : Colors.black12,
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                active.name,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedProgress, child) {
                    return CustomPaint(
                      painter: ProgressRingPainter(
                        progress: animatedProgress,
                        gradientColors: theme.gradient,
                        trackColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        hasTarget: active.target > 0,
                      ),
                      child: Container(
                        width: 200,
                        height: 200,
                        alignment: Alignment.center,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 150),
                          transitionBuilder: (child, animation) {
                            return ScaleTransition(
                              scale: Tween<double>(begin: 0.85, end: 1.0).animate(
                                CurvedAnimation(parent: animation, curve: Curves.easeOut),
                              ),
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            '${active.value}',
                            key: ValueKey<int>(active.value),
                            style: TextStyle(fontFamily: 'monospace', 
                              fontSize: 56,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              shadows: isDark
                                  ? [
                                      Shadow(
                                        color: theme.primaryColor.withValues(alpha: 0.3),
                                        blurRadius: 12,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (active.target > 0) ...[
              Text(
                'Goal: ${active.target}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: active.value >= active.target ? theme.primaryColor : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              'TAP CARD TO COUNT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsPanel(CounterModel active, bool isDark) {
    final logs = active.history.reversed.toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.list_alt_rounded,
                size: 18,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Activity Log',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: logs.isEmpty
                ? Center(
                    child: Text(
                      'No counts registered yet.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, idx) {
                      final time = logs[idx];
                      // Format HH:MM:SS
                      final timeStr =
                          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
                      final countNum = logs.length - idx;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Count #$countNum',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                            Text(
                              timeStr,
                              style: TextStyle(fontFamily: 'monospace', 
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Progress Ring Painter ──────────────────────────────────────────────────

class ProgressRingPainter extends CustomPainter {
  final double progress;
  final List<Color> gradientColors;
  final Color trackColor;
  final bool hasTarget;

  ProgressRingPainter({
    required this.progress,
    required this.gradientColors,
    required this.trackColor,
    required this.hasTarget,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    // Track circle
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (!hasTarget || progress <= 0) return;

    // Active progress arc
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
      colors: gradientColors,
    );

    final activePaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.gradientColors != gradientColors ||
        oldDelegate.hasTarget != hasTarget;
  }
}

// ── Custom Tap Ripple Zone ─────────────────────────────────────────────────

class TouchRippleArea extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color rippleColor;

  const TouchRippleArea({
    super.key,
    required this.child,
    required this.onTap,
    required this.rippleColor,
  });

  @override
  State<TouchRippleArea> createState() => _TouchRippleAreaState();
}

class _TouchRippleAreaState extends State<TouchRippleArea> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Offset _tapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _tapPosition = details.localPosition;
    });
    _controller.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  if (!_controller.isAnimating) return const SizedBox.shrink();
                  return CustomPaint(
                    painter: RippleEffectPainter(
                      position: _tapPosition,
                      radius: _controller.value * 220,
                      opacity: (1.0 - _controller.value),
                      color: widget.rippleColor,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RippleEffectPainter extends CustomPainter {
  final Offset position;
  final double radius;
  final double opacity;
  final Color color;

  RippleEffectPainter({
    required this.position,
    required this.radius,
    required this.opacity,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity * color.a)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(position, radius, paint);
  }

  @override
  bool shouldRepaint(covariant RippleEffectPainter oldDelegate) {
    return oldDelegate.position != position ||
        oldDelegate.radius != radius ||
        oldDelegate.opacity != opacity ||
        oldDelegate.color != color;
  }
}

// ── Celebration Confetti Particles ──────────────────────────────────────────

class CelebrationParticle {
  double x;
  double y;
  double vx;
  double vy;
  Color color;
  double size;
  double opacity = 1.0;
  double rotation = 0.0;
  double rotationSpeed = 0.0;

  CelebrationParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
  }) {
    final random = math.Random();
    rotation = random.nextDouble() * 2 * math.pi;
    rotationSpeed = (random.nextDouble() - 0.5) * 0.3;
  }

  void update() {
    x += vx;
    y += vy;
    vy += 0.25; // gravity
    vx *= 0.98; // drag
    rotation += rotationSpeed;
    opacity = (opacity - 0.02).clamp(0.0, 1.0);
  }

  bool get isDead => opacity <= 0.0;
}

class ParticlePainter extends CustomPainter {
  final List<CelebrationParticle> particles;

  ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);
      
      // Draw rectangular confetti piece
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) => true;
}