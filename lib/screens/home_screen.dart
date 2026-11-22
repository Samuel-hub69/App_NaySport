import 'package:flutter/material.dart';
import '../admin/admin_screen.dart';
import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import 'cart_screen.dart';
import 'login_screen.dart';

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
          color: Colors.white,
          elevation: 1,
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
                    decoration: InputDecoration(
                      hintText: 'Buscar productos...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
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
                          icon: const Icon(Icons.admin_panel_settings, size: 18),
                          label: const Text('Panel admin'),
                          onPressed: () => Navigator.push(
                              context, MaterialPageRoute(builder: (_) => const AdminScreen())),
                        ),
                      ),
                    if (state.isLoggedIn) Flexible(child: _AccountMenu(state: state)) else
                      TextButton.icon(
                        icon: const Icon(Icons.person_outline),
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
            child: CustomScrollView(
              slivers: [
                if (_selected == null && _query.isEmpty) const SliverToBoxAdapter(child: _HeroBanner()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      _selected == null ? 'Todos los productos' : state.categoryName(_selected!),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
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
    Widget tile(String label, IconData icon, String? id) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          selected: selected == id,
          selectedTileColor: NayColors.primary.withValues(alpha: 0.1),
          leading: Icon(icon),
          title: Text(label),
          onTap: () => onSelect(id),
        ),
      );
    }

    return Container(
      width: 230,
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(28, 0, 0, 8),
            child: Text('CATEGORÍAS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          tile('Todo', Icons.apps, null),
          for (final c in categories) tile(c.name, c.icon, c.id),
        ],
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

class ProductCard extends StatelessWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final soldOut = product.stock <= 0;
    void open() => showDialog(context: context, builder: (_) => ProductDialog(product: product));
    return Card(
      elevation: 0,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: open,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(fit: StackFit.expand, children: [
                ProductImage(product.image, fallbackIcon: state.categoryIcon(product.categoryId)),
                if (soldOut)
                  Container(
                    color: Colors.white60,
                    alignment: Alignment.center,
                    child: const Chip(label: Text('AGOTADO'), backgroundColor: Colors.black87,
                        labelStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                else if (product.stock <= 5)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Chip(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.orange.shade100,
                      label: Text('¡Quedan ${product.stock}!', style: const TextStyle(fontSize: 11)),
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
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  if (product.colors.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      for (final c in product.colors.take(5))
                        Padding(padding: const EdgeInsets.only(right: 4), child: ColorDot(c, size: 14)),
                      if (product.colors.length > 5) Text('+${product.colors.length - 5}', style: const TextStyle(fontSize: 11)),
                    ]),
                  ],
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: PriceText(product.price, fontSize: 16)),
                    IconButton.filledTonal(
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

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = widget.product;
    final available = state.availableFor(p);
    final inCart = state.qtyInCart(p.id);
    final pct = state.discountFor(inCart + _qty);
    final gross = p.price * _qty;
    final rules = [...state.settings.discounts]..sort((a, b) => a.minQty.compareTo(b.minQty));

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 860,
        height: 580,
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
                  Text(p.description, style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 6),
                  Text(
                    available > 0 ? 'Disponibles: $available' : 'Sin stock disponible',
                    style: TextStyle(color: available > 0 ? Colors.green.shade700 : Colors.red, fontSize: 13),
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
                        ChoiceChip(
                          avatar: ColorDot(c, size: 18),
                          label: Text(c),
                          selected: _color == c,
                          onSelected: (_) => setState(() => _color = c),
                        ),
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
                      onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                    ),
                    SizedBox(
                      width: 44,
                      child: Text('$_qty', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
                    ),
                    IconButton.outlined(
                      icon: const Icon(Icons.add),
                      onPressed: _qty < available ? () => setState(() => _qty++) : null,
                    ),
                  ]),
                  if (rules.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final r in rules)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: inCart + _qty >= r.minQty ? Colors.green.shade100 : Colors.pink.shade50,
                          label: Text('${r.minQty}+ unid: -${r.percent.toStringAsFixed(0)}%',
                              style: const TextStyle(fontSize: 12)),
                        ),
                    ]),
                  ],
                  const SizedBox(height: 14),
                  if (pct > 0)
                    Text(
                      '¡Descuento de ${pct.toStringAsFixed(0)}% aplicado! '
                      'Pagas ${usd(gross * (1 - pct / 100))} en vez de ${usd(gross)}',
                      style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600),
                    ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.shopping_bag),
                      label: Text(available <= 0 ? 'Sin stock disponible' : 'Agregar $_qty al carrito'),
                      onPressed: available <= 0
                          ? null
                          : () {
                              if (_missing != null) {
                                setState(() => _triedSubmit = true);
                                showSnack(context, _missing!, error: true);
                                return;
                              }
                              final ok = state.add(p, size: _size, color: _color, qty: _qty);
                              Navigator.pop(context);
                              showSnack(context, ok ? '$_qty × ${p.name} agregado al carrito' : 'No hay stock suficiente',
                                  error: !ok);
                            },
                    ),
                  ),
                  if (_triedSubmit && _missing != null)
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
