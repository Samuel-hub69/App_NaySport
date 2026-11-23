import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../main.dart' show expandMainWindow;
import '../theme.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  double _progress = 0;
  String _status = 'Iniciando...';
  bool _started = false;

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  )..forward();

  late final Animation<double> _logoScale = Tween<double>(begin: 0.25, end: 1.0).animate(
    CurvedAnimation(parent: _intro, curve: const Interval(0.0, 0.58, curve: Curves.elasticOut)),
  );
  late final Animation<double> _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(parent: _intro, curve: const Interval(0.0, 0.25, curve: Curves.easeOut)),
  );
  late final Animation<double> _ring1 = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.08, 0.80, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _ring2 = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.22, 0.95, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _shine = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.45, 0.95, curve: Curves.easeInOut),
  );
  late final Animation<double> _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(parent: _intro, curve: const Interval(0.28, 0.72, curve: Curves.easeOut)),
  );
  late final Animation<Offset> _textSlide = Tween<Offset>(
    begin: const Offset(0, 0.30),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _intro, curve: const Interval(0.28, 0.75, curve: Curves.easeOutCubic)));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  /// Carga rápida: abre BD local, sincroniza BCV en segundo plano sin bloquear
  /// y precarga solo el logo y los primeros productos visibles (el resto carga bajo demanda).
  Future<void> _load() async {
    final state = AppScope.read(context);
    final startedAt = DateTime.now();
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    await state.load();
    if (!mounted) return;
    setState(() {
      _progress = 0.35;
      _status = 'Preparando catálogo...';
    });

    // Sincroniza tasa BCV en segundo plano para no retrasar el arranque
    if (state.settings.autoSyncBcv) {
      unawaited(state.syncBcvRate());
    }

    try {
      await precacheImage(const AssetImage('assets/logo.png'), context);
    } catch (_) {}
    if (!mounted) return;

    final firstBatch = state.activeProducts.take(8).toList();
    final total = firstBatch.isEmpty ? 1 : firstBatch.length;
    var done = 0;
    for (final p in firstBatch) {
      final provider = ProductImage.provider(p.image, cacheWidth: 320);
      if (provider != null && mounted) {
        try {
          await precacheImage(provider, context, onError: (_, _) {}).timeout(const Duration(seconds: 2));
        } catch (_) {}
      }
      done++;
      if (mounted) {
        setState(() {
          _progress = 0.35 + (done / total) * 0.65;
          _status = done < total ? 'Preparando catálogo...' : '¡Listo!';
        });
      }
    }

    final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
    if (elapsed < 1150) {
      await Future.delayed(Duration(milliseconds: 1150 - elapsed));
    }
    if (!mounted) return;
    await expandMainWindow();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, a, _) => FadeTransition(opacity: a, child: const LoginScreen(isEntryGate: true)),
    ));
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Widget _expandingRing(Animation<double> anim, Color color, double width) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, _) {
        final t = anim.value;
        if (t <= 0 || t >= 1) return const SizedBox.shrink();
        final scale = 0.55 + t * 1.55;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 124,
            height: 124,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: (1 - t) * 0.85),
                width: width,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF140B10),
      body: Container(
        decoration: BoxDecoration(
          gradient: const RadialGradient(
            center: Alignment(0, -0.18),
            radius: 0.95,
            colors: [Color(0xFF2D1422), Color(0xFF160B12), Color(0xFF0A0608)],
          ),
          border: Border.all(color: NayColors.primary.withValues(alpha: 0.45)),
        ),
        child: Center(
          child: RepaintBoundary(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 170,
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _expandingRing(_ring1, NayColors.primary, 2.2),
                      _expandingRing(_ring2, NayColors.accent, 1.4),
                      AnimatedBuilder(
                        animation: _intro,
                        builder: (_, child) {
                          return FadeTransition(
                            opacity: _logoOpacity,
                            child: Transform.scale(
                              scale: _logoScale.value,
                              child: Container(
                                width: 122,
                                height: 122,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: NayColors.primary, width: 2.2),
                                ),
                                child: ClipOval(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      child!,
                                      if (_shine.value > 0 && _shine.value < 1)
                                        Transform.translate(
                                          offset: Offset(-160 + _shine.value * 320, 0),
                                          child: Transform.rotate(
                                            angle: -math.pi / 8,
                                            child: Container(
                                              width: 46,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.transparent,
                                                    Colors.white.withValues(alpha: 0.55),
                                                    Colors.transparent,
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        child: const NayLogo(size: 118),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                FadeTransition(
                  opacity: _textOpacity,
                  child: SlideTransition(
                    position: _textSlide,
                    child: const BrandName(fontSize: 42, animated: false),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: 220,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progress == 0 ? null : _progress,
                      minHeight: 4,
                      color: NayColors.primary,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _status,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
