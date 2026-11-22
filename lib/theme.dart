import 'package:flutter/material.dart';

class NayColors {
  static const primary = Color(0xFFF0609E); // rosa del logo
  static const dark = Color(0xFF4A2338);
  static const accent = Color(0xFFFF9EC4);
  static const bg = Color(0xFFFFF5F9);
  static const logoBg = Color(0xFFFFD6E4); // fondo rosado del logo
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: NayColors.primary,
    primary: NayColors.primary,
    secondary: NayColors.accent,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: NayColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: NayColors.dark,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}

/// Muestra el logo de assets/logo.png; si no existe, muestra el nombre estilizado.
class NayLogo extends StatelessWidget {
  final double size;
  const NayLogo({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
      'assets/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => SizedBox(
        width: size * 2,
        height: size,
        child: FittedBox(
          child: RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: 2),
              children: [
                TextSpan(text: 'Nay', style: TextStyle(color: NayColors.primary)),
                TextSpan(text: 'Sport', style: TextStyle(color: NayColors.dark)),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// Imagen de red con placeholder y fallback.
class NetImage extends StatelessWidget {
  final String url;
  final IconData fallbackIcon;
  const NetImage(this.url, {super.key, this.fallbackIcon = Icons.checkroom});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (c, child, p) => p == null
          ? child
          : Container(
              color: Colors.pink.shade50,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
      errorBuilder: (_, __, ___) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.pink.shade100, Colors.purple.shade100]),
        ),
        alignment: Alignment.center,
        child: Icon(fallbackIcon, size: 64, color: Colors.white),
      ),
    );
  }
}
