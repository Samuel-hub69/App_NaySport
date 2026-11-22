import 'package:flutter/material.dart';
import '../data.dart';
import '../main.dart' show expandMainWindow;
import '../theme.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  double _progress = 0;
  String _status = 'Iniciando...';
  bool _started = false;
  late final AnimationController _fade =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  /// Precarga el logo y las imágenes de los productos para que todo esté listo al entrar.
  Future<void> _load() async {
    final total = kProducts.length;
    var done = 0;
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await precacheImage(const AssetImage('assets/logo.png'), context);
    if (!mounted) return;
    setState(() => _status = 'Cargando catálogo...');
    await Future.wait(kProducts.map((p) async {
      try {
        await precacheImage(NetworkImage(p.imageUrl), context)
            .timeout(const Duration(seconds: 8));
      } catch (_) {/* sin conexión: se usará el fallback */}
      done++;
      if (mounted) {
        setState(() {
          _progress = done / total;
          _status = done < total ? 'Cargando productos ($done/$total)...' : '¡Listo!';
        });
      }
    }));
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    expandMainWindow();
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (_, a, _) => FadeTransition(opacity: a, child: const HomeScreen()),
    ));
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NayColors.logoBg,
      body: Container(
        decoration: BoxDecoration(border: Border.all(color: NayColors.primary.withValues(alpha: 0.4))),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const NayLogo(size: 150),
                const SizedBox(height: 4),
                const Text('NaySport',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800, color: NayColors.primary, letterSpacing: 1.5)),
                const SizedBox(height: 20),
                SizedBox(
                  width: 220,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progress == 0 ? null : _progress,
                      minHeight: 4,
                      color: NayColors.primary,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(_status, style: const TextStyle(color: NayColors.dark, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
