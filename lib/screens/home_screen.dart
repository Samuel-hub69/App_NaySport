import 'package:flutter/material.dart';
import '../app_state.dart';
import '../data.dart';
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
  Category? _selected;
  String _query = '';

  List<Product> get _filtered => kProducts.where((p) {
        final byCat = _selected == null || p.category == _selected;
        final byQuery = _query.isEmpty || p.name.toLowerCase().contains(_query.toLowerCase());
        return byCat && byQuery;
      }).toList();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: const Padding(padding: EdgeInsets.only(left: 8), child: NayLogo(size: 56)),
        actions: [
          SizedBox(
            width: 320,
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar productos...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(width: 16),
          if (state.isLoggedIn)
            PopupMenuButton<String>(
              tooltip: 'Mi cuenta',
              onSelected: (v) {
                if (v == 'logout') state.logout();
              },
              itemBuilder: (_) => [
                PopupMenuItem(enabled: false, child: Text(state.user!.email)),
                const PopupMenuItem(value: 'logout', child: Text('Cerrar sesión')),
              ],
              child: Row(children: [
                CircleAvatar(
                  backgroundColor: NayColors.primary,
                  child: Text(state.user!.name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 8),
                Text('Hola, ${state.user!.name.split(' ').first}'),
              ]),
            )
          else
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
          const SizedBox(width: 24),
        ],
      ),
      body: Row(
        children: [
          _Sidebar(selected: _selected, onSelect: (c) => setState(() => _selected = c)),
          Expanded(
            child: CustomScrollView(
              slivers: [
                if (_selected == null && _query.isEmpty)
                  const SliverToBoxAdapter(child: _HeroBanner()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      _selected?.label ?? 'Todos los productos',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 280,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      childAspectRatio: 0.66,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => ProductCard(product: _filtered[i]),
                      childCount: _filtered.length,
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

class _Sidebar extends StatelessWidget {
  final Category? selected;
  final ValueChanged<Category?> onSelect;
  const _Sidebar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, IconData icon, Category? c) {
      final active = selected == c;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          selected: active,
          selectedTileColor: NayColors.primary.withValues(alpha: 0.1),
          leading: Icon(icon),
          title: Text(label),
          onTap: () => onSelect(c),
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
            child: Text('CATEGORÍAS',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          tile('Todo', Icons.apps, null),
          for (final c in Category.values) tile(c.label, c.icon, c),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      height: 220,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
      child: Stack(fit: StackFit.expand, children: [
        const NetImage('https://loremflickr.com/1400/500/fashion,woman?lock=99'),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [NayColors.dark.withValues(alpha: 0.85), Colors.transparent],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Nueva Colección 2026',
                  style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
              SizedBox(height: 8),
              Text('Moda casual y deportiva para ella.\nEnvío gratis en compras mayores a \$150.',
                  style: TextStyle(color: Colors.white70, fontSize: 16)),
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
    return Card(
      elevation: 0,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => showDialog(context: context, builder: (_) => ProductDialog(product: product)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: NetImage(product.imageUrl, fallbackIcon: product.category.icon),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.category.label.toUpperCase(),
                      style: const TextStyle(fontSize: 11, color: NayColors.primary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text('\$${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton.filledTonal(
                      tooltip: 'Agregar al carrito',
                      icon: const Icon(Icons.add_shopping_cart, size: 20),
                      onPressed: () => showDialog(
                          context: context, builder: (_) => ProductDialog(product: product)),
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

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 760,
        height: 460,
        child: Row(children: [
          SizedBox(width: 340, height: double.infinity, child: NetImage(p.imageUrl, fallbackIcon: p.category.icon)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ),
                  Text(p.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('\$${p.price.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 22, color: NayColors.primary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text(p.description, style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 20),
                  if (p.sizes.isNotEmpty) ...[
                    const Text('Talla', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final s in p.sizes)
                          ChoiceChip(
                            label: Text(s),
                            selected: _size == s,
                            onSelected: (_) => setState(() => _size = s),
                          ),
                      ],
                    ),
                  ],
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.shopping_bag),
                      label: const Text('Agregar al carrito'),
                      onPressed: p.sizes.isNotEmpty && _size == null
                          ? null
                          : () {
                              AppScope.of(context).add(p, size: _size);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('${p.name} agregado al carrito'),
                                behavior: SnackBarBehavior.floating,
                                width: 400,
                              ));
                            },
                    ),
                  ),
                  if (p.sizes.isNotEmpty && _size == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Selecciona una talla', style: TextStyle(color: Colors.grey)),
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
