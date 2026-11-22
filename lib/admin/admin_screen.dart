import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../db.dart';
import '../format.dart';
import '../models.dart';
import '../pdf_export.dart';
import '../theme.dart';
import '../win_utils.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.admin_panel_settings, color: NayColors.primary),
          SizedBox(width: 10),
          Text('Panel de Administración — NaySport', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              avatar: const Icon(Icons.currency_exchange, size: 18, color: NayColors.primary),
              backgroundColor: NayColors.logoBg,
              label: Text('Tasa: ${state.settings.exchangeRate.toStringAsFixed(2)} Bs/\$',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: Row(children: [
        NavigationRail(
          extended: true,
          backgroundColor: Colors.white,
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), label: Text('Resumen')),
            NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), label: Text('Stock y Precios')),
            NavigationRailDestination(icon: Icon(Icons.category_outlined), label: Text('Categorías')),
            NavigationRailDestination(icon: Icon(Icons.receipt_long_outlined), label: Text('Historial y PDF')),
            NavigationRailDestination(icon: Icon(Icons.tune_outlined), label: Text('Configuración')),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: IndexedStack(index: _tab, children: [
            _DashboardTab(onGoTab: (i) => setState(() => _tab = i)),
            const _InventoryTab(),
            const _CategoriesTab(),
            const _OrdersTab(),
            const _SettingsTab(),
          ]),
        ),
      ]),
    );
  }
}

// ============================================================================
// 1. RESUMEN
// ============================================================================
class _DashboardTab extends StatelessWidget {
  final ValueChanged<int> onGoTab;
  const _DashboardTab({required this.onGoTab});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final rate = state.settings.exchangeRate;
    final totalSales = state.orders.fold(0.0, (s, o) => s + o.total);
    final totalUnits = state.orders.fold(0, (s, o) => s + o.units);
    final lowStock = state.products.where((p) => p.stock <= 5).toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));
    final clients = state.users.where((u) => !u.isAdmin).length;

    return ListView(padding: const EdgeInsets.all(24), children: [
      const Text('Resumen de la tienda', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      Wrap(spacing: 16, runSpacing: 16, children: [
        _KpiCard(
          title: 'Ventas totales',
          value: usd(totalSales),
          sub: bs(totalSales, rate),
          icon: Icons.attach_money,
          color: Colors.green,
        ),
        _KpiCard(
          title: 'Pedidos realizados',
          value: '${state.orders.length}',
          sub: '$totalUnits unidades vendidas',
          icon: Icons.shopping_bag_outlined,
          color: NayColors.primary,
        ),
        _KpiCard(
          title: 'Productos',
          value: '${state.activeProducts.length} / ${state.products.length}',
          sub: 'activos en tienda',
          icon: Icons.checkroom,
          color: Colors.purple,
        ),
        _KpiCard(
          title: 'Stock bajo / agotado',
          value: '${lowStock.length}',
          sub: 'productos con ≤ 5 unid.',
          icon: Icons.warning_amber_rounded,
          color: lowStock.isEmpty ? Colors.teal : Colors.orange.shade800,
        ),
        _KpiCard(
          title: 'Clientes registrados',
          value: '$clients',
          sub: 'en base de datos local',
          icon: Icons.people_outline,
          color: Colors.blue,
        ),
      ]),
      const SizedBox(height: 28),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Card(
            elevation: 0,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Text('Alertas de inventario', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton(onPressed: () => onGoTab(1), child: const Text('Ir a Stock')),
                ]),
                const Divider(),
                if (lowStock.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('Todo el inventario tiene buen stock 👍'),
                  )
                else
                  for (final p in lowStock.take(8))
                    ListTile(
                      dense: true,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(width: 40, height: 40, child: ProductImage(p.image)),
                      ),
                      title: Text(p.name),
                      subtitle: Text(state.categoryName(p.categoryId)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: p.stock == 0 ? Colors.red.shade100 : Colors.orange.shade100,
                          label: Text(p.stock == 0 ? 'Agotado' : '${p.stock} unid.'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () {
                            p.stock += 10;
                            state.commit();
                            showSnack(context, '+10 unidades agregadas a ${p.name}');
                          },
                          child: const Text('+10'),
                        ),
                      ]),
                    ),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Card(
            elevation: 0,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.receipt_long, color: NayColors.primary),
                  const SizedBox(width: 8),
                  const Text('Últimas ventas', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton(onPressed: () => onGoTab(3), child: const Text('Ver historial')),
                ]),
                const Divider(),
                if (state.orders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('Aún no se han registrado ventas.'),
                  )
                else
                  for (final o in state.orders.take(6))
                    ListTile(
                      dense: true,
                      title: Text('${o.id} — ${o.customerName}'),
                      subtitle: Text('${fmtDate(o.date)} • ${o.paymentMethod}'),
                      trailing: PriceText(o.total, fontSize: 14, align: CrossAxisAlignment.end),
                    ),
              ]),
            ),
          ),
        ),
      ]),
    ]);
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;
  const _KpiCard({
    required this.title,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 225,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: TextStyle(color: Colors.grey.shade700, fontSize: 13))),
        ]),
        const SizedBox(height: 12),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(sub, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ]),
    );
  }
}

// ============================================================================
// 2. STOCK, PRODUCTOS Y AJUSTE DE PRECIOS
// ============================================================================
class _InventoryTab extends StatefulWidget {
  const _InventoryTab();

  @override
  State<_InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<_InventoryTab> {
  String _query = '';
  String? _catFilter;
  String _stockFilter = 'all'; // all | low | out | hidden

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final list = state.products.where((p) {
      if (_catFilter != null && p.categoryId != _catFilter) return false;
      if (_query.isNotEmpty && !p.name.toLowerCase().contains(_query.toLowerCase())) return false;
      switch (_stockFilter) {
        case 'low':
          return p.stock > 0 && p.stock <= 5;
        case 'out':
          return p.stock <= 0;
        case 'hidden':
          return !p.active;
        default:
          return true;
      }
    }).toList();

    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 240,
            child: TextField(
              decoration: const InputDecoration(hintText: 'Buscar prenda...', prefixIcon: Icon(Icons.search), isDense: true),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String?>(
              initialValue: _catFilter,
              decoration: const InputDecoration(labelText: 'Categoría', isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todas')),
                for (final c in state.categories) DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _catFilter = v),
            ),
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('Todos')),
              ButtonSegment(value: 'low', label: Text('Bajo')),
              ButtonSegment(value: 'out', label: Text('Agotado')),
              ButtonSegment(value: 'hidden', label: Text('Ocultos')),
            ],
            selected: {_stockFilter},
            onSelectionChanged: (s) => setState(() => _stockFilter = s.first),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Nuevo producto'),
            onPressed: () => _openProductDialog(context),
          ),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.trending_up),
            label: const Text('Ajustar precios (%)'),
            onPressed: () => _openBulkPriceDialog(context),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Stock PDF'),
            onPressed: () async {
              final bytes = await PdfExporter.buildStockPdf(state);
              final path = await PdfExporter.savePdf(bytes, 'Inventario_NaySport.pdf');
              if (path != null && context.mounted) {
                showSnack(context, 'PDF guardado');
                WinUtils.open(path);
              }
            },
          ),
        ]),
      ),
      Expanded(
        child: list.isEmpty
            ? const Center(child: Text('No hay productos con ese filtro'))
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final p = list[i];
                  return Card(
                    elevation: 0,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: ProductImage(p.image, fallbackIcon: state.categoryIcon(p.categoryId)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 3,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(state.categoryName(p.categoryId),
                                style: const TextStyle(color: NayColors.primary, fontSize: 12)),
                            if (p.colors.isNotEmpty || p.sizes.isNotEmpty)
                              Text(
                                [
                                  if (p.colors.isNotEmpty) 'Colores: ${p.colors.join(', ')}',
                                  if (p.sizes.isNotEmpty) 'Tallas: ${p.sizes.join(', ')}',
                                ].join(' • '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                          ]),
                        ),
                        SizedBox(width: 140, child: PriceText(p.price, fontSize: 15)),
                        Row(children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: p.stock > 0
                                ? () {
                                    p.stock--;
                                    state.commit();
                                  }
                                : null,
                          ),
                          InkWell(
                            onTap: () => _editStockQuick(context, p),
                            child: Chip(
                              backgroundColor: p.stock == 0
                                  ? Colors.red.shade100
                                  : (p.stock <= 5 ? Colors.orange.shade100 : Colors.green.shade100),
                              label: Text('${p.stock} unid.', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () {
                              p.stock++;
                              state.commit();
                            },
                          ),
                        ]),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: p.active ? 'Visible en la tienda' : 'Oculto',
                          child: Switch(
                            value: p.active,
                            onChanged: (v) {
                              p.active = v;
                              state.commit();
                            },
                          ),
                        ),
                        IconButton(
                          tooltip: 'Editar producto',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _openProductDialog(context, product: p),
                        ),
                        IconButton(
                          tooltip: 'Eliminar producto',
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () async {
                            final ok = await _confirmDialog(context, '¿Eliminar "${p.name}"?',
                                'Esta acción quitará la prenda del catálogo.');
                            if (ok) {
                              state.products.remove(p);
                              await state.commit();
                            }
                          },
                        ),
                      ]),
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  Future<void> _editStockQuick(BuildContext context, Product p) async {
    final state = AppScope.read(context);
    final ctrl = TextEditingController(text: '${p.stock}');
    final res = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Stock de ${p.name}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Cantidad disponible'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (res != null) {
      p.stock = res;
      await state.commit();
    }
  }

  Future<void> _openProductDialog(BuildContext context, {Product? product}) async {
    await showDialog(context: context, builder: (_) => _ProductEditorDialog(product: product));
  }

  Future<void> _openBulkPriceDialog(BuildContext context) async {
    final state = AppScope.read(context);
    final pctCtrl = TextEditingController(text: '10');
    String? catId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Ajuste masivo de precios'),
          content: SizedBox(
            width: 380,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Usa un número positivo para aumentar (ej. 10 = +10%) o negativo para rebajar (ej. -15 = -15%).'),
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                initialValue: catId,
                decoration: const InputDecoration(labelText: 'Aplicar a'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos los productos')),
                  for (final c in state.categories) DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setLocal(() => catId = v),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: pctCtrl,
                keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                decoration: const InputDecoration(labelText: 'Porcentaje (%)', suffixText: '%'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Aplicar cambio')),
          ],
        ),
      ),
    );
    if (ok == true) {
      final pct = double.tryParse(pctCtrl.text.replaceAll(',', '.'));
      if (pct == null || pct <= -100) {
        if (context.mounted) showSnack(context, 'Porcentaje no válido', error: true);
        return;
      }
      final count = await state.adjustPrices(pct, categoryId: catId);
      if (context.mounted) showSnack(context, 'Se actualizaron los precios de $count productos');
    }
  }
}

class _ProductEditorDialog extends StatefulWidget {
  final Product? product;
  const _ProductEditorDialog({this.product});

  @override
  State<_ProductEditorDialog> createState() => _ProductEditorDialogState();
}

class _ProductEditorDialogState extends State<_ProductEditorDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _sizes;
  late final TextEditingController _image;
  late String _catId;
  late List<String> _colors;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    final state = AppScope.read(context);
    _name = TextEditingController(text: p?.name ?? '');
    _desc = TextEditingController(text: p?.description ?? '');
    _price = TextEditingController(text: p != null ? p.price.toStringAsFixed(2) : '');
    _stock = TextEditingController(text: '${p?.stock ?? 10}');
    _sizes = TextEditingController(text: p?.sizes.join(', ') ?? '');
    _image = TextEditingController(text: p?.image ?? '');
    _catId = p?.categoryId ?? (state.categories.isNotEmpty ? state.categories.first.id : 'casual');
    _colors = List<String>.from(p?.colors ?? []);
    _active = p?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _price.dispose();
    _stock.dispose();
    _sizes.dispose();
    _image.dispose();
    super.dispose();
  }

  Future<void> _pickLocalImage() async {
    final picked = await WinUtils.pickImage();
    if (picked == null) return;
    final stored = await LocalDb.importImage(picked);
    if (mounted) setState(() => _image.text = stored);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final rate = state.settings.exchangeRate;
    final parsedPrice = double.tryParse(_price.text.replaceAll(',', '.')) ?? 0;

    return AlertDialog(
      title: Text(widget.product == null ? 'Nuevo producto' : 'Editar producto'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Column(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 150,
                      height: 170,
                      child: ProductImage(_image.text, fallbackIcon: state.categoryIcon(_catId)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Elegir foto'),
                    onPressed: _pickLocalImage,
                  ),
                ]),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(children: [
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Nombre del producto'),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _desc,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Descripción'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: state.categories.any((c) => c.id == _catId) ? _catId : null,
                      decoration: const InputDecoration(labelText: 'Categoría'),
                      items: [for (final c in state.categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
                      onChanged: (v) {
                        if (v != null) setState(() => _catId = v);
                      },
                      validator: (v) => v == null ? 'Elige una categoría' : null,
                    ),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Precio en Dólares (USD)',
                      prefixText: '\$ ',
                      helperText: 'Equivalente: ${bs(parsedPrice, rate)}',
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final d = double.tryParse((v ?? '').replaceAll(',', '.'));
                      return (d == null || d <= 0) ? 'Precio inválido' : null;
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextFormField(
                    controller: _stock,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Stock disponible (unidades)'),
                    validator: (v) => int.tryParse(v ?? '') == null ? 'Número inválido' : null,
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              TextFormField(
                controller: _image,
                decoration: InputDecoration(
                  labelText: 'Ruta o URL de la imagen (opcional)',
                  suffixIcon: _image.text.isEmpty
                      ? null
                      : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _image.clear())),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              Row(children: [
                const Text('Tallas (separadas por coma):', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(onPressed: () => _sizes.text = 'XS, S, M, L, XL', child: const Text('Ropa')),
                TextButton(onPressed: () => _sizes.text = '35, 36, 37, 38, 39, 40', child: const Text('Calzado')),
                TextButton(onPressed: () => _sizes.clear(), child: const Text('Sin tallas')),
              ]),
              TextFormField(
                controller: _sizes,
                decoration: const InputDecoration(hintText: 'Ej: XS, S, M, L, XL'),
              ),
              const SizedBox(height: 14),
              const Text('Colores disponibles:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in kColorPalette.keys)
                  FilterChip(
                    avatar: ColorDot(c, size: 16),
                    label: Text(c, style: const TextStyle(fontSize: 12)),
                    selected: _colors.contains(c),
                    onSelected: (sel) => setState(() {
                      if (sel) {
                        _colors.add(c);
                      } else {
                        _colors.remove(c);
                      }
                    }),
                  ),
              ]),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Visible en la tienda'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () async {
            if (!_form.currentState!.validate()) return;
            final sizes = _sizes.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
            final price = double.parse(_price.text.replaceAll(',', '.'));
            final stock = int.parse(_stock.text);

            if (widget.product == null) {
              state.products.insert(
                0,
                Product(
                  id: state.newId('p'),
                  name: _name.text.trim(),
                  description: _desc.text.trim(),
                  price: price,
                  categoryId: _catId,
                  image: _image.text.trim(),
                  sizes: sizes,
                  colors: _colors,
                  stock: stock,
                  active: _active,
                ),
              );
            } else {
              final p = widget.product!;
              p.name = _name.text.trim();
              p.description = _desc.text.trim();
              p.price = price;
              p.categoryId = _catId;
              p.image = _image.text.trim();
              p.sizes = sizes;
              p.colors = _colors;
              p.stock = stock;
              p.active = _active;
            }
            await state.commit();
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

// ============================================================================
// 3. CATEGORÍAS / TIPOS DE PRENDA
// ============================================================================
class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ListView(padding: const EdgeInsets.all(24), children: [
      Row(children: [
        const Text('Tipos de prenda / Categorías', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Spacer(),
        FilledButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Agregar categoría'),
          onPressed: () => _openCategoryDialog(context),
        ),
      ]),
      const SizedBox(height: 16),
      for (final c in state.categories) ...[
        Card(
          elevation: 0,
          color: Colors.white,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: NayColors.logoBg,
              child: Icon(c.icon, color: NayColors.primary),
            ),
            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${state.products.where((p) => p.categoryId == c.id).length} productos'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: 'Editar',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _openCategoryDialog(context, category: c),
              ),
              IconButton(
                tooltip: 'Eliminar',
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () async {
                  final used = state.products.where((p) => p.categoryId == c.id).length;
                  if (used > 0) {
                    showSnack(context, 'No puedes eliminar "${c.name}" porque tiene $used productos.', error: true);
                    return;
                  }
                  final ok = await _confirmDialog(context, '¿Eliminar categoría "${c.name}"?', '');
                  if (ok) {
                    state.categories.remove(c);
                    await state.commit();
                  }
                },
              ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
      ],
    ]);
  }

  Future<void> _openCategoryDialog(BuildContext context, {CategoryModel? category}) async {
    final nameCtrl = TextEditingController(text: category?.name ?? '');
    var iconKey = category?.iconKey ?? kCategoryIcons.keys.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(category == null ? 'Nueva categoría' : 'Editar categoría'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre de la categoría')),
              const SizedBox(height: 16),
              const Text('Ícono:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in kCategoryIcons.entries)
                  ChoiceChip(
                    label: Icon(e.value, size: 20),
                    selected: iconKey == e.key,
                    onSelected: (_) => setLocal(() => iconKey = e.key),
                  ),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok == true && nameCtrl.text.trim().isNotEmpty && context.mounted) {
      final state = AppScope.read(context);
      if (category == null) {
        state.categories.add(CategoryModel(id: state.newId('cat_'), name: nameCtrl.text.trim(), iconKey: iconKey));
      } else {
        category.name = nameCtrl.text.trim();
        category.iconKey = iconKey;
      }
      await state.commit();
    }
  }
}

// ============================================================================
// 4. HISTORIAL DE VENTAS Y PDF
// ============================================================================
class _OrdersTab extends StatefulWidget {
  const _OrdersTab();

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  String _query = '';
  String _period = 'all'; // all | today | week | month | custom
  DateTimeRange? _customRange;

  List<Order> _filtered(List<Order> all) {
    final now = DateTime.now();
    return all.where((o) {
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final match = o.id.toLowerCase().contains(q) ||
            o.customerName.toLowerCase().contains(q) ||
            o.customerEmail.toLowerCase().contains(q) ||
            o.paymentMethod.toLowerCase().contains(q);
        if (!match) return false;
      }
      switch (_period) {
        case 'today':
          return o.date.year == now.year && o.date.month == now.month && o.date.day == now.day;
        case 'week':
          return o.date.isAfter(now.subtract(const Duration(days: 7)));
        case 'month':
          return o.date.isAfter(now.subtract(const Duration(days: 30)));
        case 'custom':
          if (_customRange == null) return true;
          final end = _customRange!.end.add(const Duration(days: 1));
          return !o.date.isBefore(_customRange!.start) && o.date.isBefore(end);
        default:
          return true;
      }
    }).toList();
  }

  String get _filterLabel => switch (_period) {
        'today' => 'Hoy (${fmtDay(DateTime.now())})',
        'week' => 'Últimos 7 días',
        'month' => 'Últimos 30 días',
        'custom' when _customRange != null => '${fmtDay(_customRange!.start)} - ${fmtDay(_customRange!.end)}',
        _ => 'Todo el historial',
      };

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final orders = _filtered(state.orders);
    final rate = state.settings.exchangeRate;
    final totalUsd = orders.fold(0.0, (s, o) => s + o.total);

    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 240,
            child: TextField(
              decoration: const InputDecoration(
                  hintText: 'Buscar pedido o cliente...', prefixIcon: Icon(Icons.search), isDense: true),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('Todo')),
              ButtonSegment(value: 'today', label: Text('Hoy')),
              ButtonSegment(value: 'week', label: Text('7 días')),
              ButtonSegment(value: 'month', label: Text('30 días')),
              ButtonSegment(value: 'custom', label: Text('Rango')),
            ],
            selected: {_period},
            onSelectionChanged: (s) async {
              final next = s.first;
              if (next == 'custom') {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (picked == null) return;
                setState(() {
                  _customRange = picked;
                  _period = 'custom';
                });
              } else {
                setState(() => _period = next);
              }
            },
          ),
          FilledButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Descargar PDF'),
            onPressed: orders.isEmpty
                ? null
                : () async {
                    final bytes = await PdfExporter.buildSalesPdf(orders, rate, filterLabel: _filterLabel);
                    final path = await PdfExporter.savePdf(bytes, 'Historial_Ventas_NaySport.pdf');
                    if (path != null && context.mounted) showSnack(context, 'PDF guardado en $path');
                  },
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('Imprimir PDF'),
            onPressed: orders.isEmpty
                ? null
                : () async {
                    final bytes = await PdfExporter.buildSalesPdf(orders, rate, filterLabel: _filterLabel);
                    await PdfExporter.openToPrint(bytes, 'Historial_Ventas_NaySport.pdf');
                  },
          ),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Limpiar historial'),
            onPressed: state.orders.isEmpty
                ? null
                : () async {
                    final ok = await _confirmDialog(context, '¿Limpiar todo el historial de ventas?',
                        'Se borrarán todos los pedidos registrados. Esta acción no se puede deshacer.');
                    if (ok) await state.clearOrders();
                  },
          ),
        ]),
      ),
      Container(
        width: double.infinity,
        color: NayColors.logoBg.withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Text(
          '$_filterLabel • ${orders.length} pedidos • Total: ${usd(totalUsd)} (${bs(totalUsd, rate)})',
          style: const TextStyle(fontWeight: FontWeight.w600, color: NayColors.dark),
        ),
      ),
      Expanded(
        child: orders.isEmpty
            ? const Center(child: Text('No hay ventas registradas'))
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final o = orders[i];
                  return Card(
                    elevation: 0,
                    color: Colors.white,
                    child: ExpansionTile(
                      title: Text('${o.id} — ${o.customerName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${fmtDate(o.date)} • ${o.paymentMethod} • ${o.units} unid.'),
                      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(usd(o.total),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: NayColors.primary)),
                        Text(bs(o.total, o.exchangeRate > 0 ? o.exchangeRate : rate),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ]),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        const Divider(),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Correo: ${o.customerEmail}\nEnvío: ${o.address}, ${o.city}, ${o.country} (CP ${o.postalCode})'),
                        ),
                        const SizedBox(height: 8),
                        for (final l in o.lines)
                          Row(children: [
                            Expanded(
                                child: Text(
                                    '${l.qty}× ${l.productName}${l.variant.isNotEmpty ? ' (${l.variant})' : ''}')),
                            if (l.discountPercent > 0)
                              Text('-${l.discountPercent.toStringAsFixed(0)}%  ',
                                  style: const TextStyle(color: Colors.green)),
                            Text(usd(l.total)),
                          ]),
                        const SizedBox(height: 10),
                        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.print, size: 18),
                            label: const Text('Imprimir recibo PDF'),
                            onPressed: () async {
                              final bytes = await PdfExporter.buildReceiptPdf(o);
                              await PdfExporter.openToPrint(bytes, 'Recibo_${o.id}.pdf');
                            },
                          ),
                        ]),
                      ],
                    ),
                  );
                },
              ),
      ),
    ]);
  }
}

// ============================================================================
// 5. CONFIGURACIÓN (TASA BS, DESCUENTOS, CLIENTES, LIMPIEZA)
// ============================================================================
class _SettingsTab extends StatefulWidget {
  const _SettingsTab();

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  late final TextEditingController _rate;
  late final TextEditingController _ship;
  late final TextEditingController _freeShip;

  @override
  void initState() {
    super.initState();
    final s = AppScope.read(context).settings;
    _rate = TextEditingController(text: s.exchangeRate.toStringAsFixed(2));
    _ship = TextEditingController(text: s.shippingCost.toStringAsFixed(2));
    _freeShip = TextEditingController(text: s.freeShippingFrom.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _rate.dispose();
    _ship.dispose();
    _freeShip.dispose();
    super.dispose();
  }

  Future<void> _saveNumbers() async {
    final state = AppScope.read(context);
    final rate = double.tryParse(_rate.text.replaceAll(',', '.'));
    final ship = double.tryParse(_ship.text.replaceAll(',', '.'));
    final free = double.tryParse(_freeShip.text.replaceAll(',', '.'));
    if (rate == null || rate <= 0 || ship == null || ship < 0 || free == null || free < 0) {
      showSnack(context, 'Revisa los valores numéricos', error: true);
      return;
    }
    state.settings.exchangeRate = rate;
    state.settings.shippingCost = ship;
    state.settings.freeShippingFrom = free;
    await state.commit();
    if (mounted) showSnack(context, 'Configuración guardada');
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final previewRate = double.tryParse(_rate.text.replaceAll(',', '.')) ?? state.settings.exchangeRate;
    final rules = [...state.settings.discounts]..sort((a, b) => a.minQty.compareTo(b.minQty));

    return ListView(padding: const EdgeInsets.all(24), children: [
      Card(
        elevation: 0,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Moneda y Envíos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _rate,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Tasa del dólar (Bs por 1 \$)',
                    helperText: 'Ejemplo: \$10.00 = ${bs(10, previewRate)}',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _ship,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Costo de envío (USD)', prefixText: '\$ '),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _freeShip,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Envío gratis desde (USD)', prefixText: '\$ '),
                ),
              ),
              const SizedBox(width: 14),
              FilledButton(onPressed: _saveNumbers, child: const Text('Guardar')),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      Card(
        elevation: 0,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('Descuentos por cantidad', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add),
                label: const Text('Nueva regla'),
                onPressed: () => _addDiscountRule(context),
              ),
            ]),
            const SizedBox(height: 8),
            if (rules.isEmpty)
              const Text('No hay descuentos configurados.')
            else
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (final r in rules)
                  Chip(
                    label: Text('Desde ${r.minQty} unidades → -${r.percent.toStringAsFixed(0)}%'),
                    onDeleted: () {
                      state.settings.discounts.remove(r);
                      state.commit();
                    },
                  ),
              ]),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      Card(
        elevation: 0,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Usuarios registrados (${state.users.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            for (final u in state.users)
              ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: u.isAdmin ? NayColors.primary : Colors.grey.shade300,
                  child: Icon(u.isAdmin ? Icons.shield : Icons.person,
                      color: u.isAdmin ? Colors.white : Colors.black54, size: 18),
                ),
                title: Text(u.name),
                subtitle: Text('${u.email}${u.phone.isNotEmpty ? ' • ${u.phone}' : ''} • ${fmtDay(u.createdAt)}'),
                trailing: Chip(label: Text(u.isAdmin ? 'Admin' : 'Cliente')),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      Card(
        elevation: 0,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Seguridad y Base de Datos local', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SelectableText('Archivo de base de datos: ${LocalDb.file.path}',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            const SizedBox(height: 14),
            Wrap(spacing: 12, runSpacing: 12, children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text('Abrir carpeta de datos'),
                onPressed: () => WinUtils.open(LocalDb.dir.path),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.lock_reset),
                label: const Text('Cambiar contraseña admin'),
                onPressed: () => _changePasswordDialog(context),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                icon: const Icon(Icons.restore),
                label: const Text('Restablecer catálogo de prueba'),
                onPressed: () async {
                  final ok = await _confirmDialog(context, '¿Restablecer catálogo?',
                      'Se reemplazarán los productos y categorías por los de prueba iniciales.');
                  if (ok) {
                    await state.resetCatalog();
                    if (context.mounted) showSnack(context, 'Catálogo restablecido');
                  }
                },
              ),
            ]),
          ]),
        ),
      ),
    ]);
  }

  Future<void> _addDiscountRule(BuildContext context) async {
    final qtyCtrl = TextEditingController(text: '5');
    final pctCtrl = TextEditingController(text: '10');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo descuento por cantidad'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: qtyCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'A partir de cuántas unidades'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: pctCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Porcentaje de descuento (%)'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Agregar')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final q = int.tryParse(qtyCtrl.text);
      final p = double.tryParse(pctCtrl.text.replaceAll(',', '.'));
      if (q == null || q < 2 || p == null || p <= 0 || p >= 100) {
        showSnack(context, 'Valores inválidos (mínimo 2 unidades y 1%-99%)', error: true);
        return;
      }
      final state = AppScope.read(context);
      state.settings.discounts.add(DiscountRule(q, p));
      await state.commit();
    }
  }

  Future<void> _changePasswordDialog(BuildContext context) async {
    final p1 = TextEditingController();
    final p2 = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar contraseña de administrador'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: p1, obscureText: true, decoration: const InputDecoration(labelText: 'Nueva contraseña')),
          const SizedBox(height: 12),
          TextField(controller: p2, obscureText: true, decoration: const InputDecoration(labelText: 'Repetir contraseña')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      if (p1.text.length < 8 || p1.text != p2.text) {
        showSnack(context, 'La contraseña debe tener al menos 8 caracteres y coincidir', error: true);
        return;
      }
      await AppScope.read(context).changeAdminPassword(p1.text);
      if (context.mounted) showSnack(context, 'Contraseña actualizada');
    }
  }
}

Future<bool> _confirmDialog(BuildContext context, String title, String message) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: message.isEmpty ? null : Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Confirmar'),
        ),
      ],
    ),
  );
  return res == true;
}
