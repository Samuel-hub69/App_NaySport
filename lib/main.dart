import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'app_state.dart';
import 'theme.dart';
import 'screens/splash_screen.dart';

/// Tamaño de la ventanita del splash (estilo Word).
const kSplashSize = Size(460, 320);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final window = WindowManager.instance.getCurrent();
    if (window != null) {
      window.setFrameless(true);
      window.isResizable = false;
      window.setSize(kSplashSize.toNative(), false);
      window.center();
      window.title = 'NaySport';
    }
  } catch (_) {/* si falla, la app sigue funcionando normal */}
  runApp(NaySportApp(state: AppState()));
}

/// Agranda la ventana cuando terminó de cargar.
void expandMainWindow() {
  try {
    final window = WindowManager.instance.getCurrent();
    if (window == null) return;
    window.setFrameless(false);
    window.titleBarStyle = TitleBarStyle.normal; // devuelve el marco y la barra de título
    window.isResizable = true;
    window.minimumSize = const Size(1100, 700).toNative();
    window.setSize(const Size(1366, 820).toNative(), true);
    window.center();
    window.maximize();
    window.focus();
  } catch (_) {}
}

class NaySportApp extends StatelessWidget {
  final AppState state;
  const NaySportApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'NaySport',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const SplashScreen(),
      ),
    );
  }
}
