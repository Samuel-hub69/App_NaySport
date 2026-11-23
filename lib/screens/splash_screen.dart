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

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  double _progress = 0;
  String _status = 'Iniciando...';
  bool _started = false;

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

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
    begin: const Offset(0, 0.35),
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

  /// Carga la base de datos y precarga miniaturas optimizadas para arrancar rápido y fluido.
  Future<void> _load() async {
    final state = AppScope.read(context);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _status = 'Cargando base de datos...');
    await state.load();
    if (!mounted) return;
    if (state.settings.autoSyncBcv) {
      setState(() => _status = 'Actualizando tasa BCV...');
      await state.syncBcvRate();
      if (!mounted) return;
    }
    await precacheImage(const AssetImage('assets/logo.png'), context);
    if (!mounted) return;
    setState(() => _status = 'Cargando catálogo...');

    final products = state.activeProducts;
    final total = products.isEmpty ? 1 : products.length;
    var done = 0;
    await Future.wait(products.map((p) async {
      final provider = ProductImage.provider(p.image, cacheWidth: 480);
      if (provider != null && mounted) {
        try {
          await precacheImage(provider, context, onError: (_, _) {}).timeout(const Duration(seconds: 4));
        } catch (_) {/* sin conexión o archivo faltante: se usa el fallback */}
      }
      done++;
      if (mounted && (done % 4 == 0 || done == total)) {
        setState(() {
          _progress = done / total;
          _status = done < total ? 'Cargando productos ($done/$total)...' : '¡Listo!';
        });
      }
    }));
    await Future.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    expandMainWindow();
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, a, _) => FadeTransition(opacity: a, child: const LoginScreen(isEntryGate: true)),
    ));
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
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
                      animation: Listenable.merge([_intro, _pulse]),
                      builder: (_, child) {
                        final glow = 0.35 + _pulse.value * 0.4;
                        final blur = 18.0 + _pulse.value * 16.0;
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
                                boxShadow: [
                                  BoxShadow(
                                    color: NayColors.primary.withValues(alpha: glow),
                                    blurRadius: blur,
                                    spreadRadius: 2,
                                  ),
                                ],
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
                                            width: 48,
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
                  child: const BrandName(fontSize: 42),
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
    );
  }
}
