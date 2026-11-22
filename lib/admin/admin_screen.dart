import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../db.dart';
import '../format.dart';
import '../models.dart';
import '../pdf_export.dart';
import '../screens/cashier_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
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
          Chip(
            avatar: const Icon(Icons.currency_exchange, size: 18, color: NayColors.primary),
            backgroundColor: NayColors.logoBg,
            label: Text(
              '${state.settings.rateSource}: ${state.settings.exchangeRate.toStringAsFixed(2)} Bs/\$',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.storefront_outlined, size: 18),
            label: const Text('Ver tienda'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeScreen())),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Cerrar sesión'),
            onPressed: () {
              state.logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen(isEntryGate: true)),
                (_) => false,
              );
            },
          ),
          const SizedBox(width: 14),
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
            NavigationRailDestination(icon: Icon(Icons.point_of_sale), label: Text('Caja / Ventas')),
            NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), label: Text('Stock y Kardex')),
            NavigationRailDestination(icon: Icon(Icons.local_shipping_outlined), label: Text('Proveedores')),
            NavigationRailDestination(icon: Icon(Icons.category_outlined), label: Text('Categorías')),
            NavigationRailDestination(icon: Icon(Icons.people_outline), label: Text('Clientes')),
            NavigationRailDestination(icon: Icon(Icons.receipt_long_outlined), label: Text('Historial y PDF')),
            NavigationRailDestination(icon: Icon(Icons.tune_outlined), label: Text('Config y BCV')),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: IndexedStack(index: _tab, children: [
            _DashboardTab(onGoTab: (i) => setState(() => _tab = i)),
            const CashierPosView(),
            const _InventoryTab(),
            const _SuppliersTab(),
            const _CategoriesTab(),
            const _CustomersTab(),
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
    final totalProfit = state.orders.fold(
      0.0,
      (s, o) => s + o.lines.fold(0.0, (ls, l) => ls + l.estimatedProfit),
    );
    final lowStock = state.products.where((p) => p.stock <= 5).toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));
    final clients = state.users.where((u) => u.role == 'cliente').length;
    final pendingSuppliers = state.purchases.where((p) => !p.paid).length;
    final today = DateTime.now();
    final todayOrders = state.ordersForDay(today);
    final todayUsd = todayOrders.fold(0.0, (s, o) => s + o.total);
    final todayProfit = todayOrders.fold(0.0, (s, o) => s + o.estimatedProfit);
    final todayPhysical = todayOrders.where((o) => o.isPhysical).fold(0.0, (s, o) => s + o.total);
    final todayOnline = todayOrders.where((o) => !o.isPhysical).fold(0.0, (s, o) => s + o.total);
    final todayByMethod = <String, double>{};
    for (final o in todayOrders) {
      todayByMethod[o.paymentMethod] = (todayByMethod[o.paymentMethod] ?? 0) + o.total;
    }

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
          title: 'Ganancia estimada',
          value: usd(totalProfit),
          sub: totalProfit > 0 ? bs(totalProfit, rate) : 'Asigna costo a tus prendas',
          icon: Icons.trending_up,
          color: Colors.teal,
        ),
        _KpiCard(
          title: 'Pedidos realizados',
          value: '${state.orders.length}',
          sub: '$totalUnits unidades vendidas',
          icon: Icons.shopping_bag_outlined,
          color: NayColors.primary,
        ),
        _KpiCard(
          title: 'Productos activos',
          value: '${state.activeProducts.length} / ${state.products.length}',
          sub: '${lowStock.length} con stock bajo/agotado',
          icon: Icons.checkroom,
          color: Colors.purple,
        ),
        _KpiCard(
          title: 'Proveedores',
          value: '${state.suppliers.length}',
          sub: pendingSuppliers > 0 ? '$pendingSuppliers factura(s) por pagar' : '${state.purchases.length} entradas',
          icon: Icons.local_shipping_outlined,
          color: Colors.indigo,
        ),
        _KpiCard(
          title: 'Clientes registrados',
          value: '$clients',
          sub: 'en base de datos local',
          icon: Icons.people_outline,
          color: Colors.blue,
        ),
      ]),
      const SizedBox(height: 24),
      Card(
        elevation: 0,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.point_of_sale, color: NayColors.primary),
              const SizedBox(width: 8),
              Text('Cierre del Día — ${fmtDay(today)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              OutlinedButton.icon(
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Cierre PDF'),
                onPressed: () async {
                  final bytes = await PdfExporter.buildDailyClosingPdf(todayOrders, today, rate);
                  final path = await PdfExporter.savePdf(bytes, 'Cierre_Dia_NaySport.pdf');
                  if (path != null && context.mounted) showSnack(context, 'Cierre guardado');
                },
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Imprimir cierre'),
                onPressed: () async {
                  final bytes = await PdfExporter.buildDailyClosingPdf(todayOrders, today, rate);
                  await PdfExporter.openToPrint(bytes, 'Cierre_Dia_NaySport.pdf');
                },
              ),
            ]),
            const Divider(height: 20),
            Wrap(spacing: 28, runSpacing: 10, children: [
              Text('Ventas hoy: ${todayOrders.length}   •   Total: ${usd(todayUsd)} (${bs(todayUsd, rate)})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text('Ganancia hoy: ${usd(todayProfit)} (${bs(todayProfit, rate)})',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.teal.shade700)),
              Text('Tienda física: ${usd(todayPhysical)}  |  Online: ${usd(todayOnline)}',
                  style: TextStyle(color: Colors.grey.shade700)),
            ]),
            if (todayByMethod.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 8, children: [
                for (final e in todayByMethod.entries)
                  Chip(
                    backgroundColor: NayColors.bg,
                    label: Text('${e.key}: ${usd(e.value)} (${bs(e.value, rate)})'),
                  ),
              ]),
            ],
          ]),
        ),
      ),
      const SizedBox(height: 24),
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
                  TextButton(onPressed: () => onGoTab(2), child: const Text('Ir a Stock')),
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
                            state.adjustStock(p, p.stock + 10, reason: 'Reposición rápida desde Resumen');
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
                  TextButton(onPressed: () => onGoTab(6), child: const Text('Ver historial')),
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
        Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ]),
    );
  }
}

// ============================================================================
// 2. STOCK, PRECIOS Y KARDEX (MOVIMIENTOS)
// ============================================================================
class _InventoryTab extends StatefulWidget {
  const _InventoryTab();

  @override
  State<_InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<_InventoryTab> {
  bool _showMovements = false;
  String _query = '';
  String? _catFilter;
  String _stockFilter = 'all'; // all | low | out | hidden

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, icon: Icon(Icons.inventory_2_outlined, size: 18), label: Text('Catálogo')),
              ButtonSegment(value: true, icon: Icon(Icons.swap_vert, size: 18), label: Text('Movimientos (Kardex)')),
            ],
            selected: {_showMovements},
            onSelectionChanged: (s) => setState(() => _showMovements = s.first),
          ),
          SizedBox(
            width: 220,
            child: TextField(
              decoration: InputDecoration(
                hintText: _showMovements ? 'Buscar producto o motivo...' : 'Buscar prenda...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          if (!_showMovements) ...[
            SizedBox(
              width: 180,
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
              onPressed: () => showDialog(context: context, builder: (_) => const _ProductEditorDialog()),
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
          ] else ...[
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Limpiar movimientos'),
              onPressed: state.movements.isEmpty
                  ? null
                  : () async {
                      final ok = await _confirmDialog(
                          context, '¿Limpiar historial de movimientos?', 'No afectará el stock actual.');
                      if (ok) await state.clearMovements();
                    },
            ),
          ],
        ]),
      ),
      Expanded(
        child: _showMovements ? _movementsList(state) : _catalogList(state),
      ),
    ]);
  }

  Widget _catalogList(AppState state) {
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

    if (list.isEmpty) return const Center(child: Text('No hay productos con ese filtro'));
    return ListView.separated(
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
                  Text(
                    '${state.categoryName(p.categoryId)}${p.costPrice > 0 ? ' • Costo: ${usd(p.costPrice)}' : ''}',
                    style: const TextStyle(color: NayColors.primary, fontSize: 12),
                  ),
                  if (p.colors.isNotEmpty || p.sizes.isNotEmpty)
                    Text(
                      [
                        if (p.colors.isNotEmpty) p.colorStockSummary,
                        if (p.sizes.isNotEmpty) 'Tallas: ${p.sizes.join(', ')}',
                      ].join('  •  '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                ]),
              ),
              SizedBox(width: 140, child: PriceText(p.price, fontSize: 15)),
              Row(children: [
                if (p.colors.isEmpty)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: p.stock > 0 ? () => state.adjustStock(p, p.stock - 1) : null,
                  ),
                Tooltip(
                  message: p.colors.isNotEmpty ? 'Clic para editar stock por color' : 'Clic para editar stock',
                  child: InkWell(
                    onTap: () => _editStockQuick(context, p),
                    child: Chip(
                      backgroundColor: p.stock == 0
                          ? Colors.red.shade100
                          : (p.stock <= 5 ? Colors.orange.shade100 : Colors.green.shade100),
                      label: Text('${p.stock} unid.', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                if (p.colors.isEmpty)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => state.adjustStock(p, p.stock + 1),
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
                onPressed: () => showDialog(context: context, builder: (_) => _ProductEditorDialog(product: p)),
              ),
              IconButton(
                tooltip: 'Eliminar producto',
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () async {
                  final ok = await _confirmDialog(
                      context, '¿Eliminar "${p.name}"?', 'Esta acción quitará la prenda del catálogo.');
                  if (ok) await state.deleteProduct(p);
                },
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _movementsList(AppState state) {
    final list = state.movements.where((m) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return m.productName.toLowerCase().contains(q) || m.reason.toLowerCase().contains(q);
    }).toList();

    if (list.isEmpty) return const Center(child: Text('Aún no hay movimientos de inventario registrados'));
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final m = list[i];
        final isIn = m.delta > 0;
        final color = isIn ? Colors.green : (m.type == 'salida' ? Colors.red : Colors.orange);
        return Card(
          elevation: 0,
          color: Colors.white,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 20),
            ),
            title: Text(m.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${fmtDate(m.date)} • ${m.reason}'),
            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(m.delta == 0 ? 'Eliminado (0 unid.)' : '${isIn ? '+' : ''}${m.delta} unid.',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
              Text('Stock quedó en ${m.stockAfter}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _editStockQuick(BuildContext context, Product p) async {
    final state = AppScope.read(context);
    if (p.colors.isEmpty) {
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
            FilledButton(onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)), child: const Text('Guardar')),
          ],
        ),
      );
      if (res != null) await state.adjustStock(p, res, reason: 'Edición directa de stock');
      return;
    }

    final ctrls = {for (final c in p.colors) c: TextEditingController(text: '${p.stockForColor(c)}')};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Stock por color — ${p.name}'),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final c in p.colors) ...[
                TextField(
                  controller: ctrls[c],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Cantidad en $c',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12),
                      child: ColorDot(c, size: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok == true) {
      for (final c in p.colors) {
        final v = int.tryParse(ctrls[c]!.text);
        if (v != null) {
          await state.adjustColorStock(p, c, v, reason: 'Edición directa de stock');
        }
      }
    }
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
  late final TextEditingController _cost;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _sizes;
  late final TextEditingController _image;
  late String _catId;
  late List<String> _colors;
  late Map<String, TextEditingController> _colorCtrls;
  late bool _active;
  bool _costTouched = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    final state = AppScope.read(context);
    _name = TextEditingController(text: p?.name ?? '');
    _desc = TextEditingController(text: p?.description ?? '');
    _cost = TextEditingController(text: p != null && p.costPrice > 0 ? p.costPrice.toStringAsFixed(2) : '');
    _price = TextEditingController(text: p != null ? p.price.toStringAsFixed(2) : '');
    _stock = TextEditingController(text: '${p?.stock ?? 10}');
    _sizes = TextEditingController(text: p?.sizes.join(', ') ?? '');
    _image = TextEditingController(text: p?.image ?? '');
    _catId = p?.categoryId ?? (state.categories.isNotEmpty ? state.categories.first.id : 'casual');
    _colors = List<String>.from(p?.colors ?? []);
    _colorCtrls = {
      for (final c in _colors) c: TextEditingController(text: '${p?.stockForColor(c) ?? 5}'),
    };
    _active = p?.active ?? true;
    _costTouched = p != null && p.costPrice > 0;
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _cost.dispose();
    _price.dispose();
    _stock.dispose();
    _sizes.dispose();
    _image.dispose();
    for (final c in _colorCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLocalImage() async {
    final picked = await WinUtils.pickImage();
    if (picked == null) return;
    final stored = await LocalDb.importImage(picked);
    if (mounted) setState(() => _image.text = stored);
  }

  Future<void> _addCustomColorDialog() async {
    final nameCtrl = TextEditingController();
    const swatches = [
      0xFFE91E63, 0xFF9C27B0, 0xFF3F51B5, 0xFF009688,
      0xFF4CAF50, 0xFFFF9800, 0xFF795548, 0xFF607D8B,
      0xFFFFCDD2, 0xFFE1BEE7, 0xFFB2DFDB, 0xFFFFECB3,
    ];
    var pickedHex = swatches.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Nuevo color personalizado'),
          content: SizedBox(
            width: 340,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nombre del color (ej. Coral, Turquesa)'),
              ),
              const SizedBox(height: 14),
              const Text('Tono aproximado:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final hex in swatches)
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setLocal(() => pickedHex = hex),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(hex),
                        border: Border.all(
                          color: pickedHex == hex ? NayColors.primary : Colors.grey.shade400,
                          width: pickedHex == hex ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Agregar color')),
          ],
        ),
      ),
    );
    if (ok == true && nameCtrl.text.trim().isNotEmpty && mounted) {
      final name = nameCtrl.text.trim();
      await AppScope.read(context).addCustomColor(name, pickedHex);
      if (mounted && !_colors.contains(name)) {
        setState(() {
          _colors.add(name);
          _colorCtrls[name] = TextEditingController(text: '5');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final rate = state.settings.exchangeRate;
    final parsedPrice = double.tryParse(_price.text.replaceAll(',', '.')) ?? 0;

    return AlertDialog(
      title: Text(widget.product == null ? 'Nuevo producto' : 'Editar producto'),
      content: SizedBox(
        width: 740,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 8, right: 8),
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
                    controller: _cost,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _costTouched = true,
                    decoration: const InputDecoration(
                      labelText: 'Costo compra (USD)',
                      prefixText: '\$ ',
                      helperText: 'Sugerido: Venta - \$5 (solo admin)',
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Precio de venta (USD)',
                      prefixText: '\$ ',
                      helperText: 'Equivalente: ${bs(parsedPrice, rate)}',
                    ),
                    onChanged: (v) {
                      final d = double.tryParse(v.replaceAll(',', '.'));
                      if (!_costTouched && d != null && d > 5) {
                        _cost.text = (d - 5).toStringAsFixed(2);
                      }
                      setState(() {});
                    },
                    validator: (v) {
                      final d = double.tryParse((v ?? '').replaceAll(',', '.'));
                      return (d == null || d <= 0) ? 'Precio inválido' : null;
                    },
                  ),
                ),
                if (_colors.isEmpty) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextFormField(
                      controller: _stock,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Stock (unidades)'),
                      validator: (v) => int.tryParse(v ?? '') == null ? 'Número inválido' : null,
                    ),
                  ),
                ],
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
              Row(children: [
                const Text('Colores disponibles:', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.palette_outlined, size: 18),
                  label: const Text('Agregar color nuevo'),
                  onPressed: _addCustomColorDialog,
                ),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in state.allColorNames)
                  FilterChip(
                    avatar: ColorDot(c, size: 16),
                    label: Text(c, style: const TextStyle(fontSize: 12)),
                    selected: _colors.contains(c),
                    onSelected: (sel) => setState(() {
                      if (sel) {
                        _colors.add(c);
                        _colorCtrls.putIfAbsent(c, () => TextEditingController(text: '5'));
                      } else {
                        _colors.remove(c);
                      }
                    }),
                  ),
              ]),
              if (_colors.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('Stock disponible por cada color:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final c in _colors)
                    SizedBox(
                      width: 155,
                      child: TextFormField(
                        controller: _colorCtrls[c],
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: c,
                          prefixIcon: Padding(padding: const EdgeInsets.all(10), child: ColorDot(c, size: 14)),
                        ),
                        validator: (v) => int.tryParse(v ?? '') == null ? 'Inválido' : null,
                      ),
                    ),
                ]),
              ],
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
            final cost = double.tryParse(_cost.text.replaceAll(',', '.')) ??
                (price > 5 ? double.parse((price - 5).toStringAsFixed(2)) : 0);
            final newColorStock = <String, int>{
              for (final c in _colors) c: int.tryParse(_colorCtrls[c]?.text ?? '0') ?? 0,
            };
            final stock = _colors.isEmpty ? int.parse(_stock.text) : newColorStock.values.fold(0, (s, v) => s + v);

            if (widget.product == null) {
              final prod = Product(
                id: state.newId('p'),
                name: _name.text.trim(),
                description: _desc.text.trim(),
                price: price,
                costPrice: cost,
                categoryId: _catId,
                image: _image.text.trim(),
                sizes: sizes,
                colors: _colors,
                colorStock: {for (final c in _colors) c: 0},
                stock: 0,
                active: _active,
              );
              state.products.insert(0, prod);
              if (_colors.isNotEmpty) {
                for (final c in _colors) {
                  if ((newColorStock[c] ?? 0) > 0) {
                    await state.adjustColorStock(prod, c, newColorStock[c]!, reason: 'Stock inicial de producto nuevo');
                  }
                }
              } else if (stock > 0) {
                await state.adjustStock(prod, stock, reason: 'Stock inicial de producto nuevo');
              }
              await state.commit();
            } else {
              final p = widget.product!;
              final oldMap = Map<String, int>.from(p.colorStock);
              final hadColors = p.colors.isNotEmpty;
              p.name = _name.text.trim();
              p.description = _desc.text.trim();
              p.price = price;
              p.costPrice = cost;
              p.categoryId = _catId;
              p.image = _image.text.trim();
              p.sizes = sizes;
              p.active = _active;
              if (_colors.isNotEmpty) {
                p.syncColors(_colors, oldMap);
                for (final c in _colors) {
                  await state.adjustColorStock(p, c, newColorStock[c] ?? 0, reason: 'Editado desde ficha');
                }
              } else {
                p.syncColors([], {});
                if (hadColors || p.stock != stock) {
                  await state.adjustStock(p, stock, reason: 'Editado desde ficha de producto');
                } else {
                  await state.commit();
                }
              }
            }
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

// ============================================================================
// 3. PROVEEDORES Y LLEGADAS DE MERCANCÍA
// ============================================================================
class _SuppliersTab extends StatefulWidget {
  const _SuppliersTab();

  @override
  State<_SuppliersTab> createState() => _SuppliersTabState();
}

class _SuppliersTabState extends State<_SuppliersTab> {
  bool _showDirectory = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final rate = state.settings.exchangeRate;

    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, icon: Icon(Icons.inventory, size: 18), label: Text('Llegadas de mercancía')),
              ButtonSegment(value: true, icon: Icon(Icons.store_outlined, size: 18), label: Text('Proveedores')),
            ],
            selected: {_showDirectory},
            onSelectionChanged: (s) => setState(() => _showDirectory = s.first),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('Registrar llegada de mercancía'),
            onPressed: () {
              if (state.suppliers.isEmpty) {
                showSnack(context, 'Primero registra al menos un proveedor', error: true);
                setState(() => _showDirectory = true);
                _openSupplierDialog(context);
                return;
              }
              showDialog(context: context, builder: (_) => const _PurchaseDialog());
            },
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Nuevo proveedor'),
            onPressed: () => _openSupplierDialog(context),
          ),
          if (!_showDirectory && state.purchases.isNotEmpty) ...[
            OutlinedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('PDF Compras'),
              onPressed: () async {
                final bytes = await PdfExporter.buildPurchasesPdf(state.purchases, rate);
                final path = await PdfExporter.savePdf(bytes, 'Compras_Proveedores_NaySport.pdf');
                if (path != null && context.mounted) showSnack(context, 'PDF guardado');
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.print),
              label: const Text('Imprimir PDF'),
              onPressed: () async {
                final bytes = await PdfExporter.buildPurchasesPdf(state.purchases, rate);
                await PdfExporter.openToPrint(bytes, 'Compras_Proveedores_NaySport.pdf');
              },
            ),
          ],
        ]),
      ),
      Expanded(
        child: _showDirectory ? _suppliersList(state) : _purchasesList(state, rate),
      ),
    ]);
  }

  Widget _suppliersList(AppState state) {
    if (state.suppliers.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.local_shipping_outlined, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('No hay proveedores registrados todavía'),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Agregar primer proveedor'),
            onPressed: () => _openSupplierDialog(context),
          ),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: state.suppliers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final s = state.suppliers[i];
        return Card(
          elevation: 0,
          color: Colors.white,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: NayColors.logoBg,
              child: const Icon(Icons.store, color: NayColors.primary),
            ),
            title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              [
                if (s.phone.isNotEmpty) 'Tel: ${s.phone}',
                if (s.city.isNotEmpty) s.city,
                if (s.specialty.isNotEmpty) 'Surte: ${s.specialty}',
              ].join(' • '),
            ),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: 'Editar',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _openSupplierDialog(context, supplier: s),
              ),
              IconButton(
                tooltip: 'Eliminar',
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () async {
                  final ok = await _confirmDialog(context, '¿Eliminar proveedor "${s.name}"?', '');
                  if (ok) {
                    state.suppliers.remove(s);
                    await state.commit();
                  }
                },
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _purchasesList(AppState state, double rate) {
    if (state.purchases.isEmpty) {
      return const Center(child: Text('Aún no has registrado llegadas de mercancía'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: state.purchases.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final c = state.purchases[i];
        return Card(
          elevation: 0,
          color: Colors.white,
          child: ExpansionTile(
            title: Text('${c.id} — ${c.supplierName}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${fmtDate(c.date)} • ${c.totalUnits} unid.${c.invoiceRef.isNotEmpty ? ' • Fact. ${c.invoiceRef}' : ''}'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              ChoiceChip(
                label: Text(c.paid ? 'Pagada' : 'Pendiente'),
                selected: c.paid,
                selectedColor: Colors.green.shade100,
                backgroundColor: Colors.orange.shade100,
                onSelected: (v) {
                  c.paid = !c.paid;
                  state.commit();
                },
              ),
              const SizedBox(width: 12),
              PriceText(c.totalCost, fontSize: 15, align: CrossAxisAlignment.end),
            ]),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const Divider(),
              for (final l in c.lines)
                Row(children: [
                  Expanded(child: Text('${l.qty}× ${l.productName}${l.note != null && l.note!.isNotEmpty ? ' (${l.note})' : ''}')),
                  Text('${usd(l.unitCost)} c/u  →  ${usd(l.total)}'),
                ]),
              if (c.notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(alignment: Alignment.centerLeft, child: Text('Notas: ${c.notes}')),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openSupplierDialog(BuildContext context, {Supplier? supplier}) async {
    final nameCtrl = TextEditingController(text: supplier?.name ?? '');
    final phoneCtrl = TextEditingController(text: supplier?.phone ?? '');
    final emailCtrl = TextEditingController(text: supplier?.email ?? '');
    final cityCtrl = TextEditingController(text: supplier?.city ?? '');
    final specCtrl = TextEditingController(text: supplier?.specialty ?? '');
    final notesCtrl = TextEditingController(text: supplier?.notes ?? '');
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(supplier == null ? 'Nuevo proveedor' : 'Editar proveedor'),
        content: SizedBox(
          width: 460,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre o empresa'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: const [PlusDigitsPhoneFormatter()],
                  decoration: const InputDecoration(labelText: 'Teléfono', hintText: '+584140000000'),
                  validator: validatePhone,
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Correo')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(controller: cityCtrl, decoration: const InputDecoration(labelText: 'Ciudad / País')),
                  ),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: specCtrl,
                  decoration: const InputDecoration(labelText: '¿Qué surte? (ej. Ropa deportiva, Calzado)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notas adicionales'),
                ),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      final state = AppScope.read(context);
      if (supplier == null) {
        state.suppliers.add(Supplier(
          id: state.newId('sup_'),
          name: nameCtrl.text.trim(),
          phone: phoneCtrl.text.trim(),
          email: emailCtrl.text.trim(),
          city: cityCtrl.text.trim(),
          specialty: specCtrl.text.trim(),
          notes: notesCtrl.text.trim(),
        ));
      } else {
        supplier.name = nameCtrl.text.trim();
        supplier.phone = phoneCtrl.text.trim();
        supplier.email = emailCtrl.text.trim();
        supplier.city = cityCtrl.text.trim();
        supplier.specialty = specCtrl.text.trim();
        supplier.notes = notesCtrl.text.trim();
      }
      await state.commit();
    }
  }
}

class _PurchaseDialog extends StatefulWidget {
  const _PurchaseDialog();

  @override
  State<_PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends State<_PurchaseDialog> {
  String? _supplierId;
  final _invoice = TextEditingController();
  final _notes = TextEditingController();
  bool _paid = true;
  final List<PurchaseLine> _lines = [];

  @override
  void initState() {
    super.initState();
    final state = AppScope.read(context);
    if (state.suppliers.isNotEmpty) _supplierId = state.suppliers.first.id;
  }

  @override
  void dispose() {
    _invoice.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _addLine() async {
    final state = AppScope.read(context);
    if (state.products.isEmpty) return;
    Product selected = state.products.first;
    String? selectedColor = selected.colors.isNotEmpty ? selected.colors.first : null;
    final qtyCtrl = TextEditingController(text: '10');
    final costCtrl = TextEditingController(text: selected.costPrice > 0 ? selected.costPrice.toStringAsFixed(2) : '15.00');
    final noteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Agregar prenda recibida'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<Product>(
                initialValue: selected,
                decoration: const InputDecoration(labelText: 'Producto'),
                items: [for (final p in state.products) DropdownMenuItem(value: p, child: Text(p.name))],
                onChanged: (p) {
                  if (p == null) return;
                  setLocal(() {
                    selected = p;
                    selectedColor = p.colors.isNotEmpty ? p.colors.first : null;
                    if (p.costPrice > 0) costCtrl.text = p.costPrice.toStringAsFixed(2);
                  });
                },
              ),
              if (selected.colors.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedColor,
                  decoration: const InputDecoration(labelText: 'Color que llegó'),
                  items: [
                    for (final c in selected.colors)
                      DropdownMenuItem(
                        value: c,
                        child: Row(children: [ColorDot(c, size: 14), const SizedBox(width: 8), Text(c)]),
                      ),
                  ],
                  onChanged: (c) => setLocal(() => selectedColor = c),
                ),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Cantidad recibida'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: costCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Costo unitario (USD)', prefixText: '\$ '),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Tallas / Detalles (opcional)'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Agregar')),
          ],
        ),
      ),
    );
    if (ok == true) {
      final qty = int.tryParse(qtyCtrl.text) ?? 0;
      final cost = double.tryParse(costCtrl.text.replaceAll(',', '.')) ?? 0;
      if (qty <= 0) return;
      setState(() => _lines.add(PurchaseLine(
            productId: selected.id,
            productName: selected.name,
            color: selectedColor,
            qty: qty,
            unitCost: cost,
            note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
          )));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final total = _lines.fold(0.0, (s, l) => s + l.total);

    return AlertDialog(
      title: const Text('Registrar llegada de mercancía'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: _supplierId,
                  decoration: const InputDecoration(labelText: 'Proveedor'),
                  items: [for (final s in state.suppliers) DropdownMenuItem(value: s.id, child: Text(s.name))],
                  onChanged: (v) => setState(() => _supplierId = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _invoice,
                  decoration: const InputDecoration(labelText: 'N° Factura / Guía'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Prendas que llegaron:', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              FilledButton.tonalIcon(icon: const Icon(Icons.add), label: const Text('Agregar prenda'), onPressed: _addLine),
            ]),
            const SizedBox(height: 8),
            if (_lines.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Agrega las prendas que trajo el proveedor para sumar al stock.'),
              )
            else
              for (final l in _lines)
                ListTile(
                  dense: true,
                  title: Text('${l.qty}× ${l.productName}'),
                  subtitle: Text('${usd(l.unitCost)} c/u${l.note != null ? ' • ${l.note}' : ''}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(usd(l.total), style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.red),
                      onPressed: () => setState(() => _lines.remove(l)),
                    ),
                  ]),
                ),
            const Divider(),
            Row(children: [
              Expanded(child: TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notas'))),
              const SizedBox(width: 12),
              FilterChip(
                label: Text(_paid ? 'Factura Pagada' : 'Por Pagar'),
                selected: _paid,
                onSelected: (v) => setState(() => _paid = v),
              ),
            ]),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text('Total inversión: ${usd(total)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: NayColors.primary)),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _lines.isEmpty || _supplierId == null
              ? null
              : () async {
                  final sup = state.suppliers.firstWhere((s) => s.id == _supplierId);
                  await state.recordSupplierPurchase(
                    supplier: sup,
                    invoiceRef: _invoice.text.trim(),
                    paid: _paid,
                    notes: _notes.text.trim(),
                    lines: _lines,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    showSnack(context, 'Mercancía ingresada y sumada al stock');
                  }
                },
          child: const Text('Guardar entrada y sumar stock'),
        ),
      ],
    );
  }
}

// ============================================================================
// 4. CATEGORÍAS / TIPOS DE PRENDA
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
// 5. CLIENTES REGISTRADOS
// ============================================================================
class _CustomersTab extends StatefulWidget {
  const _CustomersTab();

  @override
  State<_CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<_CustomersTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final rate = state.settings.exchangeRate;
    final filtered = state.users.where((u) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return u.name.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.phone.toLowerCase().contains(q);
    }).toList();

    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          const Text('Clientes y Cuentas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(width: 20),
          SizedBox(
            width: 300,
            child: TextField(
              decoration: const InputDecoration(
                  hintText: 'Buscar por nombre, correo o teléfono...', prefixIcon: Icon(Icons.search), isDense: true),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const Spacer(),
          Text('Total: ${filtered.length} usuario(s)', style: TextStyle(color: Colors.grey.shade700)),
        ]),
      ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: filtered.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final u = filtered[i];
            final userOrders =
                state.orders.where((o) => o.customerEmail.toLowerCase() == u.email.toLowerCase()).toList();
            final spent = userOrders.fold(0.0, (s, o) => s + o.total);
            final lastOrder = userOrders.isNotEmpty ? userOrders.first : null;
            return Card(
              elevation: 0,
              color: Colors.white,
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: u.isAdmin ? NayColors.primary : NayColors.logoBg,
                  child: Icon(u.isAdmin ? Icons.shield : Icons.person,
                      color: u.isAdmin ? Colors.white : NayColors.primary),
                ),
                title: Row(children: [
                  Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(u.isAdmin ? 'Admin' : (u.isCashier ? 'Cajero' : 'Cliente'),
                      style: const TextStyle(fontSize: 11)),
                  ),
                ]),
                subtitle: Text(
                  '${u.email}${u.phone.isNotEmpty ? ' • Tel: ${u.phone}' : ''} • Registro: ${fmtDay(u.createdAt)}',
                ),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${userOrders.length} pedido(s)', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(usd(spent), style: const TextStyle(color: NayColors.primary, fontSize: 13)),
                ]),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  const Divider(),
                  if (lastOrder != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Última dirección: ${lastOrder.address}, ${lastOrder.city}, ${lastOrder.country} (CP ${lastOrder.postalCode})',
                        ),
                      ),
                    ),
                  if (userOrders.isEmpty)
                    const Text('Este usuario aún no ha realizado compras.')
                  else
                    for (final o in userOrders)
                      ListTile(
                        dense: true,
                        title: Text('${o.id} • ${fmtDate(o.date)} • ${o.paymentMethod}'),
                        subtitle: Text(o.lines.map((l) => '${l.qty}x ${l.productName}').join(', ')),
                        trailing: Text('${usd(o.total)} (${bs(o.total, o.exchangeRate > 0 ? o.exchangeRate : rate)})'),
                      ),
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
// 6. HISTORIAL DE VENTAS Y PDF (EXCLUSIVO ADMIN)
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
            o.customerPhone.toLowerCase().contains(q) ||
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
                      title: Row(children: [
                        Text('${o.id} — ${o.customerName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: o.isPhysical ? Colors.teal.shade50 : Colors.pink.shade50,
                          label: Text(o.channel, style: const TextStyle(fontSize: 11)),
                        ),
                      ]),
                      subtitle: Text(
                          '${fmtDate(o.date)} • ${o.paymentMethod} • ${o.units} unid.${o.isPhysical && o.cashierName.isNotEmpty ? ' • Atendió: ${o.cashierName}' : ''}'),
                      trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(usd(o.total),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16, color: NayColors.primary)),
                            Text(bs(o.total, o.exchangeRate > 0 ? o.exchangeRate : rate),
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ]),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        const Divider(),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text([
                            if ([o.customerEmail, o.customerDocument, o.customerPhone].any((s) => s.isNotEmpty))
                              [
                                if (o.customerEmail.isNotEmpty) 'Correo: ${o.customerEmail}',
                                if (o.customerDocument.isNotEmpty) 'Cédula: ${o.customerDocument}',
                                if (o.customerPhone.isNotEmpty) 'Tel: ${o.customerPhone}',
                              ].join(' • '),
                            o.isPhysical
                                ? 'Canal: Tienda física (Atendió: ${o.cashierName})'
                                : 'Envío: ${o.address}, ${o.city}, ${o.country} (CP ${o.postalCode})',
                            if (o.paymentDetails.isNotEmpty) 'Detalle de pago: ${o.paymentDetails}',
                            'Ganancia estimada en esta venta: ${usd(o.estimatedProfit)}',
                          ].join('\n')),
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
                        const SizedBox(height: 12),
                        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                          TextButton.icon(
                            icon: const Icon(Icons.download, size: 18),
                            label: const Text('Descargar recibo PDF'),
                            onPressed: () async {
                              final bytes = await PdfExporter.buildReceiptPdf(o);
                              final path = await PdfExporter.savePdf(bytes, 'Recibo_${o.id}.pdf');
                              if (path != null && context.mounted) showSnack(context, 'Recibo guardado');
                            },
                          ),
                          const SizedBox(width: 8),
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
// 7. CONFIGURACIÓN (API BCV, TASA, DESCUENTOS, SEGURIDAD)
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
  bool _syncing = false;

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

  Future<void> _syncBcv(String source) async {
    setState(() => _syncing = true);
    final state = AppScope.read(context);
    final ok = await state.syncBcvRate(source: source);
    if (!mounted) return;
    setState(() => _syncing = false);
    if (ok) {
      _rate.text = state.settings.exchangeRate.toStringAsFixed(2);
      showSnack(context, 'Tasa actualizada desde $source: ${state.settings.exchangeRate.toStringAsFixed(2)} Bs/\$');
    } else {
      showSnack(context, 'No se pudo conectar a la API ($source). Se mantiene la tasa actual.', error: true);
    }
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
    if ((state.settings.exchangeRate - rate).abs() > 0.001) {
      state.settings.rateSource = 'Manual';
      state.settings.lastRateUpdate = DateTime.now();
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
            Row(children: [
              const Text('Tasa del dólar (API BCV) y Envíos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (state.settings.lastRateUpdate != null)
                Text(
                  'Última actualización (${state.settings.rateSource}): ${fmtDate(state.settings.lastRateUpdate!)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              FilledButton.icon(
                icon: _syncing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.sync),
                label: const Text('Actualizar tasa BCV Oficial'),
                onPressed: _syncing ? null : () => _syncBcv('BCV Oficial'),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.currency_exchange),
                label: const Text('Consultar Paralelo'),
                onPressed: _syncing ? null : () => _syncBcv('Paralelo'),
              ),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Switch(
                  value: state.settings.autoSyncBcv,
                  onChanged: (v) {
                    state.settings.autoSyncBcv = v;
                    state.commit();
                  },
                ),
                const Text('Sincronizar BCV al iniciar la app'),
              ]),
            ]),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _rate,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Tasa manual (Bs por 1 \$)',
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
            Row(children: [
              const Text('Personal de Caja (Cajeros)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.person_add),
                label: const Text('Nuevo cajero'),
                onPressed: () => _createCashierDialog(context),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              'Los cajeros solo pueden cobrar en Caja / Ventas y ver sus ventas del día (no ven ganancias ni pueden borrar nada).',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 10),
            for (final u in state.users.where((u) => u.isCashier))
              ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: u.active ? Colors.teal.shade100 : Colors.grey.shade300,
                  child: Icon(Icons.badge, color: u.active ? Colors.teal : Colors.black54),
                ),
                title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${u.email}${u.phone.isNotEmpty ? ' • ${u.phone}' : ''}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Switch(
                    value: u.active,
                    onChanged: (v) {
                      u.active = v;
                      state.commit();
                    },
                  ),
                  IconButton(
                    tooltip: 'Eliminar cajero',
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () async {
                      final ok = await _confirmDialog(context, '¿Eliminar cajero "${u.name}"?', '');
                      if (ok) {
                        state.users.remove(u);
                        await state.commit();
                      }
                    },
                  ),
                ]),
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

  Future<void> _createCashierDialog(BuildContext context) async {
    final form = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Crear cuenta de Cajero'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: form,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: nameCtrl,
                inputFormatters: [nameInputFormatter],
                decoration: const InputDecoration(labelText: 'Nombre completo'),
                validator: validateFullName,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Correo para iniciar sesión'),
                validator: (v) => RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(v?.trim() ?? '') ? null : 'Correo no válido',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                inputFormatters: const [PlusDigitsPhoneFormatter()],
                decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
                validator: (v) => (v ?? '').trim().isEmpty ? null : validatePhone(v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña (mín. 8 caracteres)'),
                validator: (v) => (v ?? '').length < 8 ? 'Mínimo 8 caracteres' : null,
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Crear cajero'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final err = await AppScope.read(context).register(
        name: nameCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        password: passCtrl.text,
        role: 'cajero',
      );
      if (!context.mounted) return;
      showSnack(context, err ?? 'Cajero creado correctamente', error: err != null);
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
