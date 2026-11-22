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

  /// Carga la base de datos y precarga las imágenes para que todo esté listo al entrar.
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
      final provider = ProductImage.provider(p.image);
      if (provider != null && mounted) {
        try {
          await precacheImage(provider, context, onError: (_, _) {}).timeout(const Duration(seconds: 5));
        } catch (_) {/* sin conexión o archivo faltante: se usa el fallback */}
      }
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
      pageBuilder: (_, a, _) => FadeTransition(opacity: a, child: const LoginScreen(isEntryGate: true)),
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
                const NayLogo(size: 140),
                const BrandName(fontSize: 38),
                const SizedBox(height: 14),
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
