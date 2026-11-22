import 'dart:io';
import 'package:flutter/material.dart';
import 'app_state.dart';
import 'format.dart';
import 'models.dart';

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

/// Logo redondo de la tienda (assets/logo.png).
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
        errorBuilder: (_, _, _) => Container(
          width: size,
          height: size,
          color: NayColors.logoBg,
          alignment: Alignment.center,
          child: Text('N', style: TextStyle(fontSize: size / 2, color: NayColors.primary)),
        ),
      ),
    );
  }
}

/// Nombre de la tienda en letra cursiva.
class BrandName extends StatelessWidget {
  final double fontSize;
  final Color color;
  const BrandName({super.key, this.fontSize = 34, this.color = NayColors.primary});

  @override
  Widget build(BuildContext context) => Text(
        'NaySport',
        style: TextStyle(fontFamily: 'GreatVibes', fontSize: fontSize, color: color, height: 1.1),
      );
}

/// Logo + nombre cursivo (para la barra superior).
class BrandHeader extends StatelessWidget {
  final double logoSize;
  const BrandHeader({super.key, this.logoSize = 52});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        NayLogo(size: logoSize),
        const SizedBox(width: 12),
        BrandName(fontSize: logoSize * 0.78),
      ]);
}

/// Imagen de producto: acepta URL (http), archivo local o asset.
class ProductImage extends StatelessWidget {
  final String src;
  final IconData fallbackIcon;
  const ProductImage(this.src, {super.key, this.fallbackIcon = Icons.checkroom});

  Widget _fallback() => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.pink.shade100, Colors.purple.shade100]),
        ),
        alignment: Alignment.center,
        child: Icon(fallbackIcon, size: 56, color: Colors.white),
      );

  @override
  Widget build(BuildContext context) {
    if (src.isEmpty) return _fallback();
    if (src.startsWith('http')) {
      return Image.network(
        src,
        fit: BoxFit.cover,
        loadingBuilder: (c, child, p) => p == null
            ? child
            : Container(
                color: Colors.pink.shade50,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    if (src.startsWith('assets/')) {
      return Image.asset(src, fit: BoxFit.cover, errorBuilder: (_, _, _) => _fallback());
    }
    return Image.file(File(src), fit: BoxFit.cover, errorBuilder: (_, _, _) => _fallback());
  }

  static ImageProvider? provider(String src) {
    if (src.isEmpty) return null;
    if (src.startsWith('http')) return NetworkImage(src);
    if (src.startsWith('assets/')) return AssetImage(src);
    return FileImage(File(src));
  }
}

/// Precio en dólares con su equivalente en bolívares debajo.
class PriceText extends StatelessWidget {
  final double usdValue;
  final double fontSize;
  final Color? color;
  final CrossAxisAlignment align;
  const PriceText(this.usdValue,
      {super.key, this.fontSize = 17, this.color, this.align = CrossAxisAlignment.start});

  @override
  Widget build(BuildContext context) {
    final rate = AppScope.of(context).settings.exchangeRate;
    return Column(crossAxisAlignment: align, mainAxisSize: MainAxisSize.min, children: [
      Text(usd(usdValue), style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: color)),
      Text(bs(usdValue, rate), style: TextStyle(fontSize: fontSize * 0.7, color: Colors.grey.shade600)),
    ]);
  }
}

/// Círculo de color (soporta paleta base y colores personalizados del admin).
class ColorDot extends StatelessWidget {
  final String colorName;
  final double size;
  final bool selected;
  final int? hexOverride;
  const ColorDot(this.colorName, {super.key, this.size = 28, this.selected = false, this.hexOverride});

  @override
  Widget build(BuildContext context) {
    final scopeHex = context.dependOnInheritedWidgetOfExactType<AppScope>()?.notifier?.colorHexFor(colorName);
    final hex = hexOverride ?? scopeHex ?? kColorPalette[colorName] ?? 0xFFCCCCCC;
    final c = Color(hex);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c,
        gradient: colorName == 'Estampado'
            ? const SweepGradient(colors: [Colors.pink, Colors.orange, Colors.purple, Colors.pink])
            : null,
        border: Border.all(
          color: selected ? NayColors.primary : Colors.grey.shade400,
          width: selected ? 3 : 1,
        ),
        boxShadow: selected ? [BoxShadow(color: NayColors.primary.withValues(alpha: 0.4), blurRadius: 6)] : null,
      ),
    );
  }
}

void showSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? Colors.red.shade700 : null,
    behavior: SnackBarBehavior.floating,
    width: 420,
  ));
}
