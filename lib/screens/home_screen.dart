import 'package:flutter/material.dart';
import '../admin/admin_screen.dart';
import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import 'cart_screen.dart';
import 'cashier_screen.dart';
import 'login_screen.dart';

const _kStoreDarkSurface = Color(0xFF141418);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selected; // id de categoría
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final filtered = state.activeProducts.where((p) {
      final byCat = _selected == null || p.categoryId == _selected;
      final byQuery = _query.isEmpty || p.name.toLowerCase().contains(_query.toLowerCase());
      return byCat && byQuery;
    }).toList();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(76),
        child: Material(
          color: _kStoreDarkSurface,
          elevation: 2,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                // Izquierda: logo + nombre en cursiva
                const Expanded(
                  child: Align(alignment: Alignment.centerLeft, child: BrandHeader(logoSize: 54)),
                ),
                // Centro: buscador
                SizedBox(
                  width: 360,
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Buscar productos...',
                      filled: true,
                      fillColor: NayColors.surfaceElevated,
                      prefixIcon: const Icon(Icons.search, color: NayColors.primary),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: NayColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: NayColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: NayColors.primary, width: 1.8),
                      ),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                // Derecha: cuenta, admin, carrito
                Expanded(
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (state.isAdmin)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            backgroundColor: NayColors.primary.withValues(alpha: 0.22),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.admin_panel_settings, size: 18),
                          label: const Text('Panel admin'),
                          onPressed: () => Navigator.push(
                              context, MaterialPageRoute(builder: (_) => const AdminScreen())),
                        ),
                      )
                    else if (state.isCashier)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            backgroundColor: NayColors.primary.withValues(alpha: 0.22),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.point_of_sale, size: 18),
                          label: const Text('Ir a Caja'),
                          onPressed: () => Navigator.pushReplacement(
                              context, MaterialPageRoute(builder: (_) => const CashierScreen())),
                        ),
                      ),
                    if (state.isLoggedIn) Flexible(child: _AccountMenu(state: state)) else
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        icon: const Icon(Icons.person_outline, color: NayColors.accent),
                        label: const Text('Iniciar sesión'),
                        onPressed: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                      ),
                    const SizedBox(width: 8),
                    Badge(
                      isLabelVisible: state.itemCount > 0,
                      label: Text('${state.itemCount}'),
                      child: IconButton(
                        tooltip: 'Carrito',
                        color: Colors.white,
                        icon: const Icon(Icons.shopping_bag_outlined),
                        onPressed: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => const CartScreen())),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
      body: Row(
        children: [
          _Sidebar(
            categories: state.categories,
            selected: _selected,
            onSelect: (c) => setState(() => _selected = c),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.025), end: Offset.zero).animate(anim),
                  child: child,
                ),
              ),
              child: CustomScrollView(
                key: ValueKey('cat_${_selected ?? 'all'}'),
                slivers: [
                  if (_selected == null && _query.isEmpty) const SliverToBoxAdapter(child: _HeroBanner()),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    sliver: SliverToBoxAdapter(
                      child: Row(children: [
                        if (_selected != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: NayColors.primary.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: NayColors.primary.withValues(alpha: 0.45)),
                            ),
                            child: Icon(state.categoryIcon(_selected!), color: NayColors.primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Text(
                          _selected == null ? 'Todos los productos' : state.categoryName(_selected!),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: NayColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: NayColors.border),
                          ),
                          child: Text(
                            '${filtered.length} ${filtered.length == 1 ? 'artículo' : 'artículos'}',
                            style: const TextStyle(fontSize: 12, color: NayColors.textMuted),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  if (filtered.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('No hay productos en esta categoría')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(24),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 280,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 20,
                          childAspectRatio: 0.62,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => ProductCard(product: filtered[i]),
                          childCount: filtered.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountMenu extends StatelessWidget {
  final AppState state;
  const _AccountMenu({required this.state});

  @override
  Widget build(BuildContext context) {
    final u = state.user!;
    return PopupMenuButton<String>(
      tooltip: 'Mi cuenta',
      onSelected: (v) {
        if (v == 'logout') state.logout();
      },
      itemBuilder: (_) => [
        PopupMenuItem(enabled: false, child: Text(u.email)),
        const PopupMenuItem(value: 'logout', child: Text('Cerrar sesión')),
      ],
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: NayColors.primary,
          child: Text(u.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 13)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Hola, ${u.name.split(' ').first}',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ),
      ]),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final List<CategoryModel> categories;
  final String? selected;
  final ValueChanged<String?> onSelect;
  const _Sidebar({required this.categories, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      color: _kStoreDarkSurface,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(28, 0, 0, 8),
            child: Text('CATEGORÍAS', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFBDB3B8))),
          ),
          _CategorySidebarItem(
            label: 'Todo',
            icon: Icons.apps,
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          for (final c in categories)
            _CategorySidebarItem(
              label: c.name,
              icon: c.icon,
              selected: selected == c.id,
              onTap: () => onSelect(c.id),
            ),
        ],
      ),
    );
  }
}

class _CategorySidebarItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CategorySidebarItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_CategorySidebarItem> createState() => _CategorySidebarItemState();
}

class _CategorySidebarItemState extends State<_CategorySidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;
    final hovered = _hovered;
    final fgColor = hovered ? Colors.white : (active ? NayColors.accent : Colors.white70);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            hoverColor: Colors.transparent,
            splashColor: NayColors.primary.withValues(alpha: 0.25),
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              padding: EdgeInsets.symmetric(horizontal: hovered ? 16 : 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: hovered
                    ? const LinearGradient(colors: [NayColors.primary, Color(0xFFFF7EB6)])
                    : null,
                color: hovered
                    ? null
                    : (active ? NayColors.primary.withValues(alpha: 0.22) : Colors.transparent),
                border: Border.all(
                  color: hovered
                      ? NayColors.primary
                      : (active ? NayColors.primary.withValues(alpha: 0.85) : Colors.transparent),
                ),
                boxShadow: hovered
                    ? [
                        BoxShadow(
                          color: NayColors.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Row(children: [
                Icon(widget.icon, size: 20, color: fgColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: hovered ? Colors.white : (active ? Colors.white : Colors.white.withValues(alpha: 0.9)),
                      fontWeight: (hovered || active) ? FontWeight.bold : FontWeight.w500,
                      fontSize: 14.5,
                    ),
                  ),
                ),
                if (hovered) const Icon(Icons.chevron_right, size: 18, color: Colors.white),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final rules = [...state.settings.discounts]..sort((a, b) => a.minQty.compareTo(b.minQty));
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      height: 220,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(colors: [NayColors.dark, NayColors.primary, NayColors.accent]),
      ),
      child: Stack(children: [
        Positioned(
          right: -40,
          top: -40,
          child: Opacity(opacity: 0.25, child: NayLogo(size: 300)),
        ),
        Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Nueva Colección 2026',
                  style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                'Moda casual y deportiva para ella.\n'
                'Envío gratis en compras mayores a ${usd(state.settings.freeShippingFrom)}.',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              if (rules.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, children: [
                  for (final r in rules)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.white,
                      label: Text('Lleva ${r.minQty}+ y ahorra ${r.percent.toStringAsFixed(0)}%',
                          style: const TextStyle(color: NayColors.primary, fontWeight: FontWeight.bold)),
                    ),
                ]),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}

class ProductCard extends StatefulWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final product = widget.product;
    final soldOut = product.stock <= 0;
    void open() => showAnimatedDialog(context: context, builder: (_) => ProductDialog(product: product));
    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
          decoration: BoxDecoration(
            color: NayColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered ? NayColors.primary.withValues(alpha: 0.7) : NayColors.border,
              width: _hovered ? 1.4 : 1,
            ),
            boxShadow: _hovered
                ? [BoxShadow(color: NayColors.primary.withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 6))]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: open,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(fit: StackFit.expand, children: [
                      ProductImage(
                        product.image,
                        fallbackIcon: state.categoryIcon(product.categoryId),
                        cacheWidth: 420,
                      ),
                      if (soldOut)
                        Container(
                          color: Colors.black54,
                          alignment: Alignment.center,
                          child: const Chip(
                            label: Text('AGOTADO'),
                            backgroundColor: Colors.black87,
                            labelStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        )
                      else if (product.stock <= 5)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Chip(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: Colors.orange.shade900.withValues(alpha: 0.9),
                            side: BorderSide(color: Colors.orange.shade300),
                            label: Text('¡Quedan ${product.stock}!',
                                style: const TextStyle(fontSize: 11, color: Colors.white)),
                          ),
                        ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(state.categoryName(product.categoryId).toUpperCase(),
                            style: const TextStyle(fontSize: 11, color: NayColors.primary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white)),
                        if (product.colors.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(children: [
                            for (final c in product.colors.take(5))
                              Padding(padding: const EdgeInsets.only(right: 4), child: ColorDot(c, size: 14)),
                            if (product.colors.length > 5)
                              Text('+${product.colors.length - 5}',
                                  style: const TextStyle(fontSize: 11, color: NayColors.textMuted)),
                          ]),
                        ],
                        const SizedBox(height: 6),
                        Row(children: [
                          Expanded(child: PriceText(product.price, fontSize: 16)),
                          IconButton.filledTonal(
                            style: IconButton.styleFrom(
                              backgroundColor: NayColors.primary.withValues(alpha: 0.2),
                              foregroundColor: NayColors.accent,
                            ),
                            tooltip: 'Agregar al carrito',
                            icon: const Icon(Icons.add_shopping_cart, size: 20),
                            onPressed: soldOut ? null : open,
                          ),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProductDialog extends StatefulWidget {
  final Product product;
  const ProductDialog({super.key, required this.product});

  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  String? _size;
  String? _color;
  int _qty = 1;
  bool _triedSubmit = false;
  final List<({String? color, String? size, int qty})> _bundle = [];

  @override
  void initState() {
    super.initState();
    if (widget.product.colors.length == 1) _color = widget.product.colors.first;
    if (widget.product.sizes.length == 1) _size = widget.product.sizes.first;
  }

  String? get _missing {
    final p = widget.product;
    if (p.colors.isNotEmpty && _color == null) return 'Elige un color para agregar al carrito';
    if (p.sizes.isNotEmpty && _size == null) return 'Elige una talla para agregar al carrito';
    return null;
  }

  void _addVariantAndChooseAnother(int remainingForNew) {
    if (_missing != null) {
      setState(() => _triedSubmit = true);
      showSnack(context, _missing!, error: true);
      return;
    }
    if (remainingForNew <= 0) return;
    final addQty = _qty.clamp(1, remainingForNew);
    final p = widget.product;
    setState(() {
      final idx = _bundle.indexWhere((e) => e.color == _color && e.size == _size);
      if (idx >= 0) {
        final prev = _bundle[idx];
        _bundle[idx] = (color: prev.color, size: prev.size, qty: prev.qty + addQty);
      } else {
        _bundle.add((color: _color, size: _size, qty: addQty));
      }
      _color = p.colors.length == 1 ? p.colors.first : null;
      _size = p.sizes.length == 1 ? p.sizes.first : null;
      _qty = 1;
      _triedSubmit = false;
    });
  }

  int _availForColor(AppState state, String? c) {
    final p = widget.product;
    if (p.colors.isNotEmpty && c == null) return state.availableFor(p);
    final inBundle = _bundle.where((e) => e.color == c).fold(0, (s, e) => s + e.qty);
    return (state.availableFor(p, color: c) - inBundle).clamp(0, 1 << 30);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = widget.product;
    final availableTotal = state.availableFor(p);
    final bundleQty = _bundle.fold(0, (s, e) => s + e.qty);
    final colorRemaining = (p.colors.isNotEmpty && _color != null)
        ? _availForColor(state, _color)
        : (availableTotal - bundleQty).clamp(0, availableTotal);
    final safeQty = colorRemaining == 0 ? 0 : _qty.clamp(1, colorRemaining);
    final hasCurrentReady = _missing == null && safeQty > 0;
    final totalSelected = bundleQty + ((_bundle.isEmpty || hasCurrentReady) ? safeQty : 0);

    final inCart = state.qtyInCart(p.id);
    final pct = state.discountFor(inCart + totalSelected);
    final gross = p.price * totalSelected;
    final rules = [...state.settings.discounts]..sort((a, b) => a.minQty.compareTo(b.minQty));
    final canCombine = p.colors.length > 1 || p.sizes.length > 1;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 880,
        height: 620,
        child: Row(children: [
          SizedBox(
            width: 360,
            height: double.infinity,
            child: ProductImage(p.image, fallbackIcon: state.categoryIcon(p.categoryId)),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ),
                  Text(p.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  PriceText(p.price, fontSize: 24, color: NayColors.primary),
                  const SizedBox(height: 12),
                  Text(p.description, style: const TextStyle(color: NayColors.textMuted)),
                  const SizedBox(height: 6),
                  Text(
                    (p.colors.isNotEmpty && _color != null)
                        ? (colorRemaining > 0 ? 'Disponibles en $_color: $colorRemaining' : 'Agotado en $_color')
                        : (availableTotal > 0 ? 'Disponibles en total: $availableTotal' : 'Sin stock disponible'),
                    style: TextStyle(
                      color: (p.colors.isNotEmpty && _color != null ? colorRemaining : availableTotal) > 0
                          ? Colors.green.shade700
                          : Colors.red,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (p.colors.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Row(children: [
                      Text('Color: ${_color ?? 'Sin elegir'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (_triedSubmit && _color == null)
                        const Text('  ← Elige uno', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final c in p.colors)
                        Builder(builder: (_) {
                          final cAvail = _availForColor(state, c);
                          return ChoiceChip(
                            avatar: ColorDot(c, size: 18),
                            label: Text(cAvail > 0 ? '$c ($cAvail)' : '$c (Agotado)'),
                            selected: _color == c,
                            onSelected: cAvail <= 0 ? null : (_) => setState(() => _color = c),
                          );
                        }),
                    ]),
                  ],
                  if (p.sizes.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Row(children: [
                      Text('Talla: ${_size ?? 'Sin elegir'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (_triedSubmit && _size == null)
                        const Text('  ← Elige una', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final s in p.sizes)
                        ChoiceChip(
                          label: Text(s),
                          selected: _size == s,
                          onSelected: (_) => setState(() => _size = s),
                        ),
                    ]),
                  ],
                  const SizedBox(height: 18),
                  Row(children: [
                    const Text('Cantidad', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 16),
                    IconButton.outlined(
                      icon: const Icon(Icons.remove),
                      onPressed: safeQty > 1 ? () => setState(() => _qty = safeQty - 1) : null,
                    ),
                    SizedBox(
                      width: 44,
                      child: Text('$safeQty', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
                    ),
                    IconButton.outlined(
                      icon: const Icon(Icons.add),
                      onPressed: safeQty < colorRemaining ? () => setState(() => _qty = safeQty + 1) : null,
                    ),
                    if (canCombine && colorRemaining > 0) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('Añadir y elegir otro color/talla'),
                          onPressed: () => _addVariantAndChooseAnother(colorRemaining),
                        ),
                      ),
                    ],
                  ]),
                  if (_bundle.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: NayColors.logoBg.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: NayColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Combinación armada ($bundleQty unid.):',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (var i = 0; i < _bundle.length; i++)
                            Chip(
                              visualDensity: VisualDensity.compact,
                              avatar: _bundle[i].color != null ? ColorDot(_bundle[i].color!, size: 14) : null,
                              label: Text(
                                '${_bundle[i].qty}× ${[?_bundle[i].color, if (_bundle[i].size != null) 'Talla ${_bundle[i].size}'].join(' • ')}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onDeleted: () => setState(() => _bundle.removeAt(i)),
                            ),
                        ]),
                      ]),
                    ),
                  ],
                  if (rules.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final r in rules)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: inCart + totalSelected >= r.minQty ? Colors.green.shade100 : Colors.pink.shade50,
                          label: Text('${r.minQty}+ unid: -${r.percent.toStringAsFixed(0)}%',
                              style: const TextStyle(fontSize: 12)),
                        ),
                    ]),
                  ],
                  const SizedBox(height: 14),
                  if (pct > 0)
                    Text(
                      '¡Descuento de ${pct.toStringAsFixed(0)}% aplicado por llevar $totalSelected unidades! '
                      'Pagas ${usd(gross * (1 - pct / 100))} en vez de ${usd(gross)}',
                      style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600),
                    ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.shopping_bag),
                      label: Text(availableTotal <= 0
                          ? 'Sin stock disponible'
                          : (_bundle.isEmpty
                              ? 'Agregar $safeQty al carrito'
                              : 'Agregar $totalSelected al carrito')),
                      onPressed: availableTotal <= 0
                          ? null
                          : () {
                              if (_bundle.isEmpty && _missing != null) {
                                setState(() => _triedSubmit = true);
                                showSnack(context, _missing!, error: true);
                                return;
                              }
                              var addedCount = 0;
                              for (final item in _bundle) {
                                if (state.add(p, size: item.size, color: item.color, qty: item.qty)) {
                                  addedCount += item.qty;
                                }
                              }
                              if (hasCurrentReady && state.add(p, size: _size, color: _color, qty: safeQty)) {
                                addedCount += safeQty;
                              }
                              Navigator.pop(context);
                              showSnack(
                                context,
                                addedCount > 0 ? '$addedCount × ${p.name} agregado al carrito' : 'No hay stock suficiente',
                                error: addedCount == 0,
                              );
                            },
                    ),
                  ),
                  if (_triedSubmit && _missing != null && _bundle.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_missing!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
