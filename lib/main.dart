import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'app_state.dart';
import 'theme.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final window = WindowManager.instance.getCurrent();
    if (window != null) {
      window.setFrameless(false);
      window.titleBarStyle = TitleBarStyle.normal;
      window.isResizable = true;
      window.minimumSize = const Size(1100, 700).toNative();
      window.title = 'NaySport';
      window.maximize();
      window.focus();
    }
  } catch (_) {/* si falla, la app sigue funcionando normal */}
  runApp(NaySportApp(state: AppState()));
}

/// Asegura que la ventana principal esté lista y enfocada al salir del splash.
Future<void> expandMainWindow() async {
  try {
    final window = WindowManager.instance.getCurrent();
    if (window == null) return;
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
