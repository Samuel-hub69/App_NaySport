import 'dart:io';
import 'package:flutter/material.dart';
import 'app_state.dart';
import 'format.dart';
import 'models.dart';

class NayColors {
  static const primary = Color(0xFFF0609E); // rosa del logo
  static const dark = Color(0xFF4A2338);
  static const wine = Color(0xFF341726);
  static const accent = Color(0xFFFF9EC4);
  static const bg = Color(0xFF110A0E); // fondo oscuro obsidiana-vino
  static const surface = Color(0xFF191015); // tarjetas y modales oscuros
  static const surfaceElevated = Color(0xFF23181F); // inputs y cajas elevadas
  static const border = Color(0xFF3A2230); // borde sutil rosado oscuro
  static const textMuted = Color(0xFFC2AAB6);
  static const logoBg = Color(0xFF2C1522); // acento oscuro-vino para chips y badges
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: NayColors.primary,
    brightness: Brightness.dark,
    primary: NayColors.primary,
    secondary: NayColors.accent,
    surface: NayColors.surface,
  ).copyWith(
    onPrimary: Colors.white,
    surfaceContainerLowest: NayColors.bg,
    surfaceContainerLow: NayColors.surface,
    surfaceContainer: NayColors.surfaceElevated,
    surfaceContainerHigh: const Color(0xFF2B1C25),
    outline: NayColors.border,
    outlineVariant: NayColors.border,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: NayColors.bg,
    canvasColor: NayColors.surface,
    dividerColor: NayColors.border,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF141016),
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 2,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: NayColors.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: NayColors.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: NayColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: NayColors.border, width: 1.2),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: NayColors.surfaceElevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: NayColors.border),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: NayColors.surfaceElevated,
      selectedColor: NayColors.primary.withValues(alpha: 0.24),
      side: const BorderSide(color: NayColors.border),
      checkmarkColor: NayColors.accent,
      labelStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: WidgetStateProperty.all(const BorderSide(color: NayColors.border)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? NayColors.primary.withValues(alpha: 0.25)
              : NayColors.surfaceElevated,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? NayColors.accent : Colors.white70,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: NayColors.surfaceElevated,
      labelStyle: const TextStyle(color: NayColors.textMuted),
      hintStyle: TextStyle(color: NayColors.textMuted.withValues(alpha: 0.7)),
      helperStyle: const TextStyle(color: NayColors.textMuted, fontSize: 12),
      prefixIconColor: NayColors.primary,
      suffixIconColor: NayColors.accent,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: NayColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: NayColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: NayColors.primary, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: NayColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: NayColors.border, width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: NayColors.accent),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : NayColors.textMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? NayColors.primary : NayColors.surfaceElevated,
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: const Color(0xFF140D12),
      indicatorColor: NayColors.primary.withValues(alpha: 0.22),
      selectedIconTheme: const IconThemeData(color: NayColors.primary),
      unselectedIconTheme: const IconThemeData(color: NayColors.textMuted),
      selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      unselectedLabelTextStyle: const TextStyle(color: NayColors.textMuted),
    ),
  );
}

/// Abre cualquier diálogo con animación suave de escala + desvanecimiento.
Future<T?> showAnimatedDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, _) => builder(ctx),
    transitionBuilder: (_, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.93, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
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
        cacheWidth: (size * 2).round(),
        fit: BoxFit.contain,
        gaplessPlayback: true,
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

/// Nombre de la tienda en letra cursiva con brillo rosado animado opcional.
class BrandName extends StatefulWidget {
  final double fontSize;
  final Color color;
  final bool animated;
  const BrandName({
    super.key,
    this.fontSize = 34,
    this.color = NayColors.primary,
    this.animated = true,
  });

  @override
  State<BrandName> createState() => _BrandNameState();
}

class _BrandNameState extends State<BrandName> with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animated) _shimmer.repeat();
  }

  @override
  void didUpdateWidget(covariant BrandName oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated && !_shimmer.isAnimating) {
      _shimmer.repeat();
    } else if (!widget.animated && _shimmer.isAnimating) {
      _shimmer.stop();
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Text(
      'NaySport',
      style: TextStyle(
        fontFamily: 'GreatVibes',
        fontSize: widget.fontSize,
        color: widget.animated ? Colors.white : widget.color,
        height: 1.1,
      ),
    );
    if (!widget.animated) return text;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _shimmer,
        builder: (_, child) {
          final slide = (_shimmer.value * 2.6) - 0.8;
          return ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment(slide - 0.6, 0),
              end: Alignment(slide + 0.6, 0),
              colors: const [
                NayColors.primary,
                Color(0xFFFFE3EF),
                NayColors.accent,
                NayColors.primary,
              ],
            ).createShader(bounds),
            child: child,
          );
        },
        child: text,
      ),
    );
  }
}

/// Logo + nombre cursivo animado (para la barra superior).
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

/// Imagen de producto optimizada con cacheWidth para fluidez al desplazarse o filtrar.
class ProductImage extends StatelessWidget {
  final String src;
  final IconData fallbackIcon;
  final int cacheWidth;
  const ProductImage(
    this.src, {
    super.key,
    this.fallbackIcon = Icons.checkroom,
    this.cacheWidth = 480,
  });

  Widget _fallback() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [NayColors.wine, Color(0xFF4A2038)]),
        ),
        alignment: Alignment.center,
        child: Icon(fallbackIcon, size: 56, color: NayColors.accent),
      );

  @override
  Widget build(BuildContext context) {
    if (src.isEmpty) return _fallback();
    if (src.startsWith('http')) {
      return Image.network(
        src,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        loadingBuilder: (c, child, p) => p == null
            ? child
            : Container(
                color: NayColors.surfaceElevated,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    if (src.startsWith('assets/')) {
      return Image.asset(
        src,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    return Image.file(
      File(src),
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => _fallback(),
    );
  }

  static ImageProvider? provider(String src, {int cacheWidth = 480}) {
    if (src.isEmpty) return null;
    final ImageProvider base;
    if (src.startsWith('http')) {
      base = NetworkImage(src);
    } else if (src.startsWith('assets/')) {
      base = AssetImage(src);
    } else {
      base = FileImage(File(src));
    }
    return ResizeImage(base, width: cacheWidth);
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
      Text(usd(usdValue), style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: color ?? Colors.white)),
      Text(bs(usdValue, rate), style: TextStyle(fontSize: fontSize * 0.7, color: NayColors.textMuted)),
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
          color: selected ? NayColors.primary : Colors.white.withValues(alpha: 0.35),
          width: selected ? 3 : 1,
        ),
        boxShadow: selected ? [BoxShadow(color: NayColors.primary.withValues(alpha: 0.5), blurRadius: 8)] : null,
      ),
    );
  }
}

void showSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(color: Colors.white)),
    backgroundColor: error ? Colors.red.shade700 : NayColors.wine,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: error ? Colors.redAccent : NayColors.primary.withValues(alpha: 0.5)),
    ),
    width: 420,
  ));
}
