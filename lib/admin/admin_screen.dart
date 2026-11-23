import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../db.dart';
import '../excel_export.dart';
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
          backgroundColor: const Color(0xFF140D12),
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
          child: switch (_tab) {
            0 => _DashboardTab(onGoTab: (i) => setState(() => _tab = i)),
            1 => const CashierPosView(),
            2 => const _InventoryTab(),
            3 => const _SuppliersTab(),
            4 => const _CategoriesTab(),
            5 => const _CustomersTab(),
            6 => const _OrdersTab(),
            _ => const _SettingsTab(),
          },
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
        color: NayColors.surface,
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
                  style: TextStyle(color: NayColors.textMuted)),
            ]),
            if (todayByMethod.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: NayColors.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final e in todayByMethod.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                          const SizedBox(width: 12),
                          Text('${usd(e.value)} (${bs(e.value, rate)})',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ]),
                      ),
                  ],
                ),
              ),
            ],
          ]),
        ),
      ),
      const SizedBox(height: 24),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Card(
            elevation: 0,
            color: NayColors.surface,
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
                          backgroundColor: p.stock == 0 ? Colors.red.shade900 : Colors.orange.shade900,
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
            color: NayColors.surface,
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
        color: NayColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NayColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: TextStyle(color: NayColors.textMuted, fontSize: 13))),
        ]),
        const SizedBox(height: 12),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: NayColors.textMuted)),
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
        color: NayColors.surface,
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
              onPressed: () => showAnimatedDialog(context: context, builder: (_) => const _ProductEditorDialog()),
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
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.greenAccent.shade200,
                side: BorderSide(color: Colors.green.shade400.withValues(alpha: 0.65)),
              ),
              icon: const Icon(Icons.table_chart_outlined),
              label: const Text('Exportar Excel'),
              onPressed: () async {
                final bytes = ExcelExporter.buildInventoryAndKardexXlsx(state);
                final path = await ExcelExporter.saveXlsx(bytes, 'Inventario_Kardex_NaySport.xlsx');
                if (path != null && context.mounted) {
                  showSnack(context, 'Excel detallado guardado (Inventario + Kardex)');
                  WinUtils.open(path);
                }
              },
            ),
          ] else ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.greenAccent.shade200,
                side: BorderSide(color: Colors.green.shade400.withValues(alpha: 0.65)),
              ),
              icon: const Icon(Icons.table_chart_outlined),
              label: const Text('Exportar Excel'),
              onPressed: () async {
                final bytes = ExcelExporter.buildInventoryAndKardexXlsx(state);
                final path = await ExcelExporter.saveXlsx(bytes, 'Inventario_Kardex_NaySport.xlsx');
                if (path != null && context.mounted) {
                  showSnack(context, 'Excel detallado guardado (Inventario + Kardex)');
                  WinUtils.open(path);
                }
              },
            ),
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
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final matchesName = p.name.toLowerCase().contains(q);
        final matchesSku = p.sku.toLowerCase().contains(q);
        if (!matchesName && !matchesSku) return false;
      }
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
      cacheExtent: 220,
      padding: const EdgeInsets.all(20),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p = list[i];
        return RepaintBoundary(
          child: Card(
            elevation: 0,
            color: NayColors.surface,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => showAnimatedDialog(
                context: context,
                builder: (_) => _AdminProductDetailDialog(
                  product: p,
                  onEdit: () => showAnimatedDialog(context: context, builder: (_) => _ProductEditorDialog(product: p)),
                  onBarcodes: () =>
                      showAnimatedDialog(context: context, builder: (_) => _ProductBarcodesDialog(product: p)),
                  onAdjustStock: () => _editStockQuick(context, p),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: ProductImage(
                        p.image,
                        cacheWidth: 140,
                        fallbackIcon: state.categoryIcon(p.categoryId),
                      ),
                    ),
                  ),
              const SizedBox(width: 14),
              Expanded(
                flex: 3,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: NayColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: NayColors.border),
                      ),
                      child: Text(
                        p.sku,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: NayColors.accent,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ]),
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
                      style: TextStyle(fontSize: 12, color: NayColors.textMuted),
                    ),
                ]),
              ),
              SizedBox(width: 140, child: PriceText(p.price, fontSize: 15, rateOverride: state.settings.exchangeRate)),
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
                          ? Colors.red.shade900
                          : (p.stock <= 5 ? Colors.orange.shade900 : Colors.green.shade900),
                      label: Text('${p.stock} unid.',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ),
                if (p.colors.isEmpty)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => state.adjustStock(p, p.stock + 1),
                  ),
              ]),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Ver códigos de barras (SKU y variantes)',
                icon: const Icon(Icons.qr_code_2, color: NayColors.accent),
                onPressed: () => showAnimatedDialog(context: context, builder: (_) => _ProductBarcodesDialog(product: p)),
              ),
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
                onPressed: () => showAnimatedDialog(context: context, builder: (_) => _ProductEditorDialog(product: p)),
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
          ),
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
        final prod = state.productById(m.productId);
        return Card(
          elevation: 0,
          color: NayColors.surface,
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            onTap: prod == null
                ? () => showSnack(context, 'Este producto ya fue eliminado del catálogo')
                : () => showAnimatedDialog(
                      context: context,
                      builder: (_) => _AdminProductDetailDialog(
                        product: prod,
                        onEdit: () =>
                            showAnimatedDialog(context: context, builder: (_) => _ProductEditorDialog(product: prod)),
                        onBarcodes: () =>
                            showAnimatedDialog(context: context, builder: (_) => _ProductBarcodesDialog(product: prod)),
                        onAdjustStock: () => _editStockQuick(context, prod),
                      ),
                    ),
            leading: prod != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: ProductImage(prod.image, cacheWidth: 100, fallbackIcon: state.categoryIcon(prod.categoryId)),
                    ),
                  )
                : CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.12),
                    child: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 20),
                  ),
            title: Row(children: [
              if (prod != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: NayColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: NayColors.border),
                  ),
                  child: Text(
                    prod.sku,
                    style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: NayColors.accent),
                  ),
                ),
              ],
              Expanded(
                child: Text(m.productName,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ]),
            subtitle: Text('${fmtDate(m.date)} • ${m.reason}'),
            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(m.delta == 0 ? 'Eliminado (0 unid.)' : '${isIn ? '+' : ''}${m.delta} unid.',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
              Text('Stock quedó en ${m.stockAfter}', style: TextStyle(fontSize: 12, color: NayColors.textMuted)),
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
  late final TextEditingController _sku;
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late final TextEditingController _cost;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _image;
  late String _catId;
  late List<String> _selectedSizes;
  late List<String> _colors;
  late Map<String, TextEditingController> _colorCtrls;
  late bool _active;
  bool _costTouched = false;
  bool _skuTouched = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    final state = AppScope.read(context);
    _catId = p?.categoryId ?? (state.categories.isNotEmpty ? state.categories.first.id : 'casual');
    _sku = TextEditingController(text: p?.sku ?? state.suggestNextSku(_catId));
    _name = TextEditingController(text: p?.name ?? '');
    _desc = TextEditingController(text: p?.description ?? '');
    _cost = TextEditingController(text: p != null && p.costPrice > 0 ? p.costPrice.toStringAsFixed(2) : '');
    _price = TextEditingController(text: p != null ? p.price.toStringAsFixed(2) : '');
    _stock = TextEditingController(text: '${p?.stock ?? 10}');
    _image = TextEditingController(text: p?.image ?? '');
    _selectedSizes = List<String>.from(p?.sizes ?? []);
    _colors = List<String>.from(p?.colors ?? []);
    _colorCtrls = {
      for (final c in _colors) c: TextEditingController(text: '${p?.stockForColor(c) ?? 5}'),
    };
    _active = p?.active ?? true;
    _costTouched = p != null && p.costPrice > 0;
    _skuTouched = p != null;
  }

  @override
  void dispose() {
    _sku.dispose();
    _name.dispose();
    _desc.dispose();
    _cost.dispose();
    _price.dispose();
    _stock.dispose();
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

  Future<void> _addCustomSizeDialog() async {
    final sizeCtrl = TextEditingController();
    final isShoes = AppState.sizeGroupForCategory(_catId) == 'calzado';
    final ok = await showAnimatedDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva talla'),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: sizeCtrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: isShoes ? 'Talla de calzado (ej. 33, 46)' : 'Talla de prenda (ej. 2XL, 3XL, 28)',
            ),
            onSubmitted: (_) => Navigator.pop(ctx, true),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Agregar talla')),
        ],
      ),
    );
    if (ok == true && sizeCtrl.text.trim().isNotEmpty && mounted) {
      final size = sizeCtrl.text.trim();
      await AppScope.read(context).addCustomSize(_catId, size);
      if (mounted && !_selectedSizes.contains(size)) {
        setState(() => _selectedSizes.add(size));
      }
    }
  }

  Future<void> _addCustomColorDialog() async {
    final nameCtrl = TextEditingController();
    const swatches = [
      0xFFE91E63, 0xFF9C27B0, 0xFF3F51B5, 0xFF009688,
      0xFF4CAF50, 0xFFFF9800, 0xFF795548, 0xFF607D8B,
      0xFFFFCDD2, 0xFFE1BEE7, 0xFFB2DFDB, 0xFFFFECB3,
    ];
    var pickedHex = swatches.first;
    final ok = await showAnimatedDialog<bool>(
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
                          color: pickedHex == hex ? NayColors.primary : Colors.white38,
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
                    Row(children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(labelText: 'Nombre del producto'),
                          validator: (v) => (v ?? '').trim().isEmpty ? 'Requerido' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _sku,
                          decoration: const InputDecoration(
                            labelText: 'Código propio / SKU',
                            helperText: 'Editable o reciclado de etiqueta (sin precio)',
                            prefixIcon: Icon(Icons.qr_code_2, size: 18),
                          ),
                          onChanged: (_) {
                            _skuTouched = true;
                            setState(() {});
                          },
                          validator: (v) => (v ?? '').trim().isEmpty ? 'Requerido' : null,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _desc,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Descripción'),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: state.categories.any((c) => c.id == _catId) ? _catId : null,
                          decoration: const InputDecoration(labelText: 'Categoría'),
                          items: [for (final c in state.categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _catId = v;
                                if (!_skuTouched) _sku.text = state.suggestNextSku(v);
                              });
                            }
                          },
                          validator: (v) => v == null ? 'Elige una categoría' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_sku.text.trim().isNotEmpty)
                        BarcodeDisplay(code: _sku.text.trim().toUpperCase(), height: 32, width: 175),
                    ]),
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
                Text(
                  'Tallas disponibles (${AppState.sizeGroupForCategory(_catId) == 'calzado' ? 'Calzado' : 'Ropa'}):',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() {
                    final isShoes = AppState.sizeGroupForCategory(_catId) == 'calzado';
                    _selectedSizes = isShoes
                        ? ['36', '37', '38', '39', '40', '41', '42']
                        : ['XS', 'S', 'M', 'L', 'XL'];
                  }),
                  child: const Text('Comunes'),
                ),
                TextButton(
                  onPressed: () => setState(() => _selectedSizes.clear()),
                  child: const Text('Sin tallas'),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.straighten, size: 17),
                  label: const Text('Agregar talla nueva'),
                  onPressed: _addCustomSizeDialog,
                ),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in {...state.availableSizesForCategory(_catId), ..._selectedSizes})
                  InputChip(
                    label: Text(s, style: const TextStyle(fontSize: 12)),
                    selected: _selectedSizes.contains(s),
                    onSelected: (sel) => setState(() {
                      if (sel) {
                        if (!_selectedSizes.contains(s)) _selectedSizes.add(s);
                      } else {
                        _selectedSizes.remove(s);
                      }
                    }),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    deleteButtonTooltipMessage: 'Eliminar talla $s',
                    onDeleted: () async {
                      await AppScope.read(context).removeSize(_catId, s);
                      if (mounted) setState(() => _selectedSizes.remove(s));
                    },
                  ),
              ]),
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
                for (final c in {...state.allColorNames, ..._colors})
                  InputChip(
                    avatar: ColorDot(c, size: 16),
                    label: Text(c, style: const TextStyle(fontSize: 12)),
                    selected: _colors.contains(c),
                    onSelected: (sel) => setState(() {
                      if (sel) {
                        if (!_colors.contains(c)) _colors.add(c);
                        _colorCtrls.putIfAbsent(c, () => TextEditingController(text: '5'));
                      } else {
                        _colors.remove(c);
                      }
                    }),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    deleteButtonTooltipMessage: 'Eliminar color $c',
                    onDeleted: () async {
                      await AppScope.read(context).removeColor(c);
                      if (mounted) {
                        setState(() {
                          _colors.remove(c);
                          _colorCtrls.remove(c)?.dispose();
                        });
                      }
                    },
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
            final sizes = List<String>.from(_selectedSizes);
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
                sku: _sku.text.trim().toUpperCase(),
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
              p.sku = _sku.text.trim().toUpperCase();
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
            if (context.mounted) Navigator.pop(context, widget.product ?? state.products.firstOrNull);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Ficha completa del producto al tocarlo desde Stock o desde Movimientos (Kardex).
class _AdminProductDetailDialog extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onBarcodes;
  final VoidCallback onAdjustStock;
  const _AdminProductDetailDialog({
    required this.product,
    required this.onEdit,
    required this.onBarcodes,
    required this.onAdjustStock,
  });

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final rate = state.settings.exchangeRate;
    final profit = product.costPrice > 0 ? product.price - product.costPrice : 0.0;
    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 820,
        height: 560,
        child: Row(children: [
          Container(
            width: 300,
            height: double.infinity,
            color: const Color(0xFF130B10),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ProductImage(
                      product.image,
                      cacheWidth: 640,
                      fit: BoxFit.contain,
                      fallbackIcon: state.categoryIcon(product.categoryId),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                BarcodeDisplay(code: product.sku, height: 36, width: 210),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(26, 14, 26, 22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(state.categoryName(product.categoryId),
                        style: const TextStyle(fontSize: 11.5, color: NayColors.accent)),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: product.active ? Colors.green.shade900 : Colors.grey.shade800,
                    label: Text(product.active ? 'Visible en tienda' : 'Oculto',
                        style: const TextStyle(fontSize: 11.5, color: Colors.white)),
                  ),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ]),
                const SizedBox(height: 6),
                Text(product.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                if (product.description.isNotEmpty)
                  Text(product.description, style: const TextStyle(color: NayColors.textMuted)),
                const SizedBox(height: 14),
                Wrap(spacing: 14, runSpacing: 10, children: [
                  _DetailMetric(
                    label: 'Precio venta',
                    value: usd(product.price),
                    sub: bs(product.price, rate),
                    color: NayColors.primary,
                  ),
                  _DetailMetric(
                    label: 'Costo compra',
                    value: usd(product.costPrice),
                    sub: profit > 0 ? 'Ganancia: +${usd(profit)}' : 'Solo admin',
                    color: Colors.tealAccent.shade200,
                  ),
                  _DetailMetric(
                    label: 'Stock total',
                    value: '${product.stock} unid.',
                    sub: product.stock <= 5 ? 'Stock bajo' : 'Disponible',
                    color: product.stock == 0
                        ? Colors.redAccent
                        : (product.stock <= 5 ? Colors.orangeAccent : Colors.greenAccent.shade200),
                  ),
                ]),
                if (product.colors.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Stock por color:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final c in product.colors)
                      Chip(
                        avatar: ColorDot(c, size: 16),
                        label: Text('$c: ${product.stockForColor(c)} unid.'),
                      ),
                  ]),
                ],
                if (product.sizes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Tallas disponibles:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final s in product.sizes) Chip(label: Text(s)),
                  ]),
                ],
                const SizedBox(height: 22),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Editar producto / código'),
                    onPressed: () {
                      Navigator.pop(context);
                      onEdit();
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.qr_code_2, size: 18),
                    label: const Text('Códigos de barras'),
                    onPressed: () {
                      Navigator.pop(context);
                      onBarcodes();
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.inventory_2_outlined, size: 18),
                    label: const Text('Ajustar stock'),
                    onPressed: () {
                      Navigator.pop(context);
                      onAdjustStock();
                    },
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;
  const _DetailMetric({required this.label, required this.value, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: NayColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NayColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11.5, color: NayColors.textMuted)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(sub, style: const TextStyle(fontSize: 11.5, color: NayColors.textMuted)),
      ]),
    );
  }
}

/// Diálogo con el código de barras base y los códigos por variante (color + talla) estilo supermercado.
class _ProductBarcodesDialog extends StatelessWidget {
  final Product product;
  const _ProductBarcodesDialog({required this.product});

  @override
  Widget build(BuildContext context) {
    final variants = product.allVariantCodes();
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.qr_code_2, color: NayColors.primary),
        const SizedBox(width: 8),
        Expanded(child: Text('Códigos de barras — ${product.name}', overflow: TextOverflow.ellipsis)),
      ]),
      content: SizedBox(
        width: 680,
        height: 460,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: NayColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: NayColors.border),
            ),
            child: Row(children: [
              BarcodeDisplay(code: product.sku, height: 42, width: 185),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Código general del producto (SKU)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  const Text(
                    'Escanea el código de una variante abajo en Caja / Ventas para agregar automáticamente el producto con su color y talla exactos.',
                    style: TextStyle(fontSize: 12, color: NayColors.textMuted),
                  ),
                ]),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copiar SKU'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: product.sku));
                  showSnack(context, 'Código ${product.sku} copiado');
                },
              ),
            ]),
          ),
          const SizedBox(height: 14),
          Text('Códigos por variante (${variants.length}):', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: variants.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final v = variants[i];
                final stock = product.stockForColor(v.color);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: NayColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NayColors.border),
                  ),
                  child: Row(children: [
                    BarcodeDisplay(code: v.code, height: 34, width: 205),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          if (v.color != null) ...[
                            ColorDot(v.color!, size: 14),
                            const SizedBox(width: 6),
                            Text(v.color!, style: const TextStyle(fontWeight: FontWeight.w600)),
                          ] else
                            const Text('General', style: TextStyle(fontWeight: FontWeight.w600)),
                          if (v.size != null) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: NayColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('Talla ${v.size}', style: const TextStyle(fontSize: 11.5)),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 4),
                        Text('Stock en este color: $stock unid.',
                            style: const TextStyle(fontSize: 12, color: NayColors.textMuted)),
                      ]),
                    ),
                    IconButton(
                      tooltip: 'Copiar código ${v.code}',
                      icon: const Icon(Icons.copy_outlined, size: 20, color: NayColors.accent),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: v.code));
                        showSnack(context, 'Código ${v.code} copiado — listo para pegar o escanear en Caja');
                      },
                    ),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    );
  }
}

// ============================================================================
// 3. PROVEEDORES E INGRESO DE MERCANCÍA (ESTILO ADMINISTRATIVO AMPLIO)
// ============================================================================
class _SuppliersTab extends StatefulWidget {
  const _SuppliersTab();

  @override
  State<_SuppliersTab> createState() => _SuppliersTabState();
}

class _SuppliersTabState extends State<_SuppliersTab> {
  int _section = 0; // 0 = Ingreso de mercancía, 1 = Historial de llegadas, 2 = Proveedores

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final rate = state.settings.exchangeRate;

    return Column(children: [
      Container(
        color: NayColors.surface,
        padding: const EdgeInsets.all(16),
        child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, icon: Icon(Icons.add_box_outlined, size: 18), label: Text('Ingreso de mercancía')),
              ButtonSegment(value: 1, icon: Icon(Icons.history, size: 18), label: Text('Historial de llegadas')),
              ButtonSegment(value: 2, icon: Icon(Icons.store_outlined, size: 18), label: Text('Proveedores')),
            ],
            selected: {_section},
            onSelectionChanged: (s) => setState(() => _section = s.first),
          ),
          if (_section == 2)
            FilledButton.icon(
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Nuevo proveedor'),
              onPressed: () => _openSupplierDialog(context),
            ),
          if (_section == 1 && state.purchases.isNotEmpty) ...[
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
        child: switch (_section) {
          0 => _GoodsEntryView(
              onNewSupplier: () => _openSupplierDialog(context),
              onSaved: () => setState(() => _section = 1),
            ),
          1 => _purchasesList(state, rate),
          _ => _suppliersList(state),
        },
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
          color: NayColors.surface,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: NayColors.logoBg,
              child: const Icon(Icons.store, color: NayColors.primary),
            ),
            title: Row(children: [
              Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (s.rif.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: NayColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: NayColors.border),
                  ),
                  child: Text('RIF: ${s.rif}', style: const TextStyle(fontSize: 11, color: NayColors.accent)),
                ),
              ],
            ]),
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
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Aún no has registrado llegadas de mercancía'),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('Ir a Ingreso de mercancía'),
            onPressed: () => setState(() => _section = 0),
          ),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: state.purchases.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final c = state.purchases[i];
        return Card(
          elevation: 0,
          color: NayColors.surface,
          child: ExpansionTile(
            title: Text('${c.id} — ${c.supplierName}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${fmtDate(c.date)} • ${c.totalUnits} unid.${c.invoiceRef.isNotEmpty ? ' • Fact. ${c.invoiceRef}' : ''}'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              ChoiceChip(
                label: Text(c.paid ? 'Pagada' : 'Pendiente'),
                selected: c.paid,
                selectedColor: Colors.green.shade900,
                backgroundColor: Colors.orange.shade900,
                onSelected: (v) {
                  c.paid = !c.paid;
                  state.commit();
                },
              ),
              const SizedBox(width: 12),
              PriceText(c.totalCost, fontSize: 15, align: CrossAxisAlignment.end, rateOverride: rate),
            ]),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const Divider(),
              for (final l in c.lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        '${l.qty}× ${l.sku != null && l.sku!.isNotEmpty ? '[${l.sku}] ' : ''}${l.productName}'
                        '${[if (l.color != null) l.color!, if (l.size != null) 'Talla ${l.size}', if (l.note != null && l.note!.isNotEmpty) l.note!].isNotEmpty ? ' (${[if (l.color != null) l.color!, if (l.size != null) 'Talla ${l.size}', if (l.note != null && l.note!.isNotEmpty) l.note!].join(' • ')})' : ''}',
                      ),
                    ),
                    Text('${usd(l.unitCost)} c/u  →  ${usd(l.total)}'),
                  ]),
                ),
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

  Future<Supplier?> _openSupplierDialog(BuildContext context, {Supplier? supplier}) async {
    final nameCtrl = TextEditingController(text: supplier?.name ?? '');
    final rifCtrl = TextEditingController(text: supplier?.rif ?? '');
    final phoneCtrl = TextEditingController(text: supplier?.phone ?? '');
    final emailCtrl = TextEditingController(text: supplier?.email ?? '');
    final cityCtrl = TextEditingController(text: supplier?.city ?? '');
    final specCtrl = TextEditingController(text: supplier?.specialty ?? '');
    final notesCtrl = TextEditingController(text: supplier?.notes ?? '');
    final formKey = GlobalKey<FormState>();

    final ok = await showAnimatedDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(supplier == null ? 'Nuevo proveedor' : 'Editar proveedor'),
        content: SizedBox(
          width: 480,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre o razón social'),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: rifCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'RIF', hintText: 'J-12345678-9'),
                      validator: (v) => (v ?? '').trim().length >= 6 ? null : 'Ingresa el RIF',
                    ),
                  ),
                ]),
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
      Supplier result;
      if (supplier == null) {
        result = Supplier(
          id: state.newId('sup_'),
          name: nameCtrl.text.trim(),
          rif: rifCtrl.text.trim().toUpperCase(),
          phone: phoneCtrl.text.trim(),
          email: emailCtrl.text.trim(),
          city: cityCtrl.text.trim(),
          specialty: specCtrl.text.trim(),
          notes: notesCtrl.text.trim(),
        );
        state.suppliers.add(result);
      } else {
        supplier.name = nameCtrl.text.trim();
        supplier.rif = rifCtrl.text.trim().toUpperCase();
        supplier.phone = phoneCtrl.text.trim();
        supplier.email = emailCtrl.text.trim();
        supplier.city = cityCtrl.text.trim();
        supplier.specialty = specCtrl.text.trim();
        supplier.notes = notesCtrl.text.trim();
        result = supplier;
      }
      await state.commit();
      return result;
    }
    return null;
  }
}

/// Pantalla amplia tipo sistema administrativo para ingresar mercancía, crear/editar
/// productos, reciclar códigos de etiqueta, crear colores/tallas y registrar factura.
class _GoodsEntryView extends StatefulWidget {
  final Future<Supplier?> Function() onNewSupplier;
  final VoidCallback onSaved;
  const _GoodsEntryView({required this.onNewSupplier, required this.onSaved});

  @override
  State<_GoodsEntryView> createState() => _GoodsEntryViewState();
}

class _GoodsEntryViewState extends State<_GoodsEntryView> {
  String? _supplierId;
  final _invoice = TextEditingController();
  final _notes = TextEditingController();
  bool _paid = true;

  String? _productId;
  final _skuCtrl = TextEditingController();
  String? _selectedColor;
  String? _selectedSize;
  final _qtyCtrl = TextEditingController(text: '10');
  final _costCtrl = TextEditingController();
  final _lineNoteCtrl = TextEditingController();
  final List<PurchaseLine> _lines = [];

  @override
  void initState() {
    super.initState();
    final state = AppScope.read(context);
    if (state.suppliers.isNotEmpty) _supplierId = state.suppliers.first.id;
    if (state.products.isNotEmpty) _selectProduct(state.products.first);
  }

  @override
  void dispose() {
    _invoice.dispose();
    _notes.dispose();
    _skuCtrl.dispose();
    _qtyCtrl.dispose();
    _costCtrl.dispose();
    _lineNoteCtrl.dispose();
    super.dispose();
  }

  void _selectProduct(Product p) {
    _productId = p.id;
    _skuCtrl.text = p.sku;
    _selectedColor = p.colors.isNotEmpty ? p.colors.first : null;
    _selectedSize = p.sizes.isNotEmpty ? p.sizes.first : null;
    _costCtrl.text = p.costPrice > 0 ? p.costPrice.toStringAsFixed(2) : '';
  }

  Future<void> _createNewColorInline() async {
    final nameCtrl = TextEditingController();
    const swatches = [
      0xFFE91E63, 0xFF9C27B0, 0xFF3F51B5, 0xFF009688,
      0xFF4CAF50, 0xFFFF9800, 0xFF795548, 0xFF607D8B,
      0xFFFFCDD2, 0xFFE1BEE7, 0xFFB2DFDB, 0xFFFFECB3,
    ];
    var pickedHex = swatches.first;
    final ok = await showAnimatedDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Crear color nuevo'),
          content: SizedBox(
            width: 340,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nombre del color (ej. Coral, Mostaza)'),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final hex in swatches)
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setLocal(() => pickedHex = hex),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(hex),
                        border: Border.all(
                          color: pickedHex == hex ? NayColors.primary : Colors.white38,
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
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crear color')),
          ],
        ),
      ),
    );
    if (ok == true && nameCtrl.text.trim().isNotEmpty && mounted) {
      final name = nameCtrl.text.trim();
      await AppScope.read(context).addCustomColor(name, pickedHex);
      if (mounted) setState(() => _selectedColor = name);
    }
  }

  Future<void> _createNewSizeInline(String categoryId) async {
    final sizeCtrl = TextEditingController();
    final ok = await showAnimatedDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Crear talla nueva'),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: sizeCtrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Talla (ej. 33, 46, 2XL, 28)'),
            onSubmitted: (_) => Navigator.pop(ctx, true),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crear talla')),
        ],
      ),
    );
    if (ok == true && sizeCtrl.text.trim().isNotEmpty && mounted) {
      final size = sizeCtrl.text.trim();
      await AppScope.read(context).addCustomSize(categoryId, size);
      if (mounted) setState(() => _selectedSize = size);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final rate = state.settings.exchangeRate;
    final selectedProduct = _productId != null ? state.productById(_productId!) : state.products.firstOrNull;
    final totalUnits = _lines.fold(0, (s, l) => s + l.qty);
    final totalCost = _lines.fold(0.0, (s, l) => s + l.total);
    final allColors = state.allColorNames;
    final allSizes = selectedProduct != null
        ? {...state.availableSizesForCategory(selectedProduct.categoryId), ...selectedProduct.sizes}.toList()
        : const <String>[];

    return ListView(padding: const EdgeInsets.all(24), children: [
      // 1. DATOS DEL DOCUMENTO Y PROVEEDOR
      Card(
        elevation: 0,
        color: NayColors.surface,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.assignment_outlined, color: NayColors.primary),
              SizedBox(width: 8),
              Text('1. Datos del Documento y Proveedor', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: state.suppliers.any((s) => s.id == _supplierId) ? _supplierId : null,
                  decoration: const InputDecoration(labelText: 'Proveedor'),
                  items: [
                    for (final s in state.suppliers)
                      DropdownMenuItem(
                        value: s.id,
                        child: Text(s.rif.isNotEmpty ? '${s.name} • RIF: ${s.rif}' : s.name),
                      ),
                  ],
                  onChanged: (v) => setState(() => _supplierId = v),
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('Nuevo proveedor'),
                  onPressed: () async {
                    final created = await widget.onNewSupplier();
                    if (created != null && mounted) setState(() => _supplierId = created.id);
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _invoice,
                  decoration: const InputDecoration(labelText: 'N° Factura / Guía'),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: FilterChip(
                  label: Text(_paid ? 'Pagada' : 'Por pagar'),
                  selected: _paid,
                  onSelected: (v) => setState(() => _paid = v),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Observaciones de la entrada (opcional)'),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 16),

      // 2. CARGA AMPLIA DE ARTÍCULO (CREAR / EDITAR PRODUCTO, CÓDIGO PROPIO, COLOR NUEVO, TALLA NUEVA)
      Card(
        elevation: 0,
        color: NayColors.surface,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.inventory_2_outlined, color: NayColors.primary),
              const SizedBox(width: 8),
              const Text('2. Seleccionar o Crear Mercancía a Ingresar',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const Spacer(),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Crear producto nuevo'),
                onPressed: () async {
                  final created = await showAnimatedDialog<Product>(
                    context: context,
                    builder: (_) => const _ProductEditorDialog(),
                  );
                  if (created != null && mounted) setState(() => _selectProduct(created));
                },
              ),
              if (selectedProduct != null) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Modificar producto'),
                  onPressed: () async {
                    final edited = await showAnimatedDialog<Product>(
                      context: context,
                      builder: (_) => _ProductEditorDialog(product: selectedProduct),
                    );
                    if (edited != null && mounted) setState(() => _selectProduct(edited));
                  },
                ),
              ],
            ]),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: selectedProduct?.id,
                  decoration: const InputDecoration(labelText: 'Producto del catálogo'),
                  items: [
                    for (final p in state.products)
                      DropdownMenuItem(value: p.id, child: Text('[${p.sku}] ${p.name}', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (id) {
                    if (id == null) return;
                    final p = state.productById(id);
                    if (p != null) setState(() => _selectProduct(p));
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _skuCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Código / SKU (propio o etiqueta)',
                    helperText: 'Sin precio • Puedes reciclar el código de la etiqueta',
                    prefixIcon: Icon(Icons.qr_code_2, size: 18),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String?>(
                  initialValue: allColors.contains(_selectedColor) ? _selectedColor : null,
                  decoration: const InputDecoration(labelText: 'Color que ingresa'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('General / Sin color')),
                    for (final c in allColors)
                      DropdownMenuItem<String?>(
                        value: c,
                        child: Row(children: [ColorDot(c, size: 14), const SizedBox(width: 8), Text(c)]),
                      ),
                  ],
                  onChanged: (c) => setState(() => _selectedColor = c),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.palette_outlined, size: 17),
                  label: const Text('+ Color'),
                  onPressed: _createNewColorInline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String?>(
                  initialValue: allSizes.contains(_selectedSize) ? _selectedSize : null,
                  decoration: const InputDecoration(labelText: 'Talla que ingresa'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Sin talla / Única')),
                    for (final s in allSizes) DropdownMenuItem<String?>(value: s, child: Text(s)),
                  ],
                  onChanged: (s) => setState(() => _selectedSize = s),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.straighten, size: 17),
                  label: const Text('+ Talla'),
                  onPressed: selectedProduct == null
                      ? null
                      : () => _createNewSizeInline(selectedProduct.categoryId),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              SizedBox(
                width: 150,
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _costCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Costo unitario (USD)', prefixText: '\$ '),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _lineNoteCtrl,
                  decoration: const InputDecoration(labelText: 'Detalle del lote (opcional)'),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Agregar a la entrada'),
                onPressed: selectedProduct == null
                    ? null
                    : () {
                        final qty = int.tryParse(_qtyCtrl.text) ?? 0;
                        final cost = double.tryParse(_costCtrl.text.replaceAll(',', '.')) ?? 0;
                        if (qty <= 0) {
                          showSnack(context, 'Ingresa una cantidad mayor a 0', error: true);
                          return;
                        }
                        final customSku = _skuCtrl.text.trim().toUpperCase();
                        setState(() {
                          _lines.add(PurchaseLine(
                            productId: selectedProduct.id,
                            productName: selectedProduct.name,
                            sku: customSku.isNotEmpty ? customSku : selectedProduct.sku,
                            color: _selectedColor,
                            size: _selectedSize,
                            qty: qty,
                            unitCost: cost,
                            note: _lineNoteCtrl.text.trim().isEmpty ? null : _lineNoteCtrl.text.trim(),
                          ));
                          _lineNoteCtrl.clear();
                        });
                      },
              ),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 16),

      // 3. TABLA DE RENGLONES Y CONFIRMACIÓN
      Card(
        elevation: 0,
        color: NayColors.surface,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.list_alt_outlined, color: NayColors.primary),
              const SizedBox(width: 8),
              Text('3. Detalle del Ingreso (${_lines.length} renglones • $totalUnits unid.)',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_lines.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _lines.clear()),
                  child: const Text('Limpiar renglones', style: TextStyle(color: Colors.redAccent)),
                ),
            ]),
            const Divider(height: 24),
            if (_lines.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Agrega uno o varios artículos arriba para cargar el ingreso al inventario.',
                    style: TextStyle(color: NayColors.textMuted),
                  ),
                ),
              )
            else
              for (var i = 0; i < _lines.length; i++)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: NayColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NayColors.border),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: NayColors.bg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: NayColors.border),
                      ),
                      child: Text(
                        _lines[i].sku ?? '-',
                        style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: NayColors.accent),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_lines[i].productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Row(children: [
                          if (_lines[i].color != null) ...[
                            ColorDot(_lines[i].color!, size: 12),
                            const SizedBox(width: 5),
                            Text(_lines[i].color!, style: const TextStyle(fontSize: 12, color: NayColors.textMuted)),
                            const SizedBox(width: 10),
                          ],
                          if (_lines[i].size != null)
                            Text('Talla ${_lines[i].size}',
                                style: const TextStyle(fontSize: 12, color: NayColors.textMuted)),
                          if (_lines[i].note != null && _lines[i].note!.isNotEmpty)
                            Text('  •  ${_lines[i].note}',
                                style: const TextStyle(fontSize: 12, color: NayColors.textMuted)),
                        ]),
                      ]),
                    ),
                    Text('${_lines[i].qty} unid. × ${usd(_lines[i].unitCost)}',
                        style: const TextStyle(color: NayColors.textMuted)),
                    const SizedBox(width: 16),
                    Text(usd(_lines[i].total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Quitar renglón',
                      icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                      onPressed: () => setState(() => _lines.removeAt(i)),
                    ),
                  ]),
                ),
            const Divider(height: 24),
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total inversión de esta entrada', style: TextStyle(color: NayColors.textMuted, fontSize: 12)),
                PriceText(totalCost, fontSize: 22, color: NayColors.primary, rateOverride: rate),
              ]),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: Text('Confirmar ingreso al inventario ($totalUnits unid.)'),
                onPressed: _lines.isEmpty || _supplierId == null
                    ? null
                    : () async {
                        final sup = state.suppliers.firstWhere((s) => s.id == _supplierId);
                        await state.recordSupplierPurchase(
                          supplier: sup,
                          invoiceRef: _invoice.text.trim(),
                          paid: _paid,
                          notes: _notes.text.trim(),
                          lines: List<PurchaseLine>.from(_lines),
                        );
                        if (!context.mounted) return;
                        setState(() {
                          _lines.clear();
                          _invoice.clear();
                          _notes.clear();
                        });
                        showSnack(context, 'Mercancía ingresada al inventario y registrada en el Kardex');
                        widget.onSaved();
                      },
              ),
            ]),
          ]),
        ),
      ),
    ]);
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
          color: NayColors.surface,
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
        color: NayColors.surface,
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
          Text('Total: ${filtered.length} usuario(s)', style: TextStyle(color: NayColors.textMuted)),
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
              color: NayColors.surface,
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
        color: NayColors.surface,
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
        color: NayColors.wine.withValues(alpha: 0.55),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Text(
          '$_filterLabel • ${orders.length} pedidos • Total: ${usd(totalUsd)} (${bs(totalUsd, rate)})',
          style: const TextStyle(fontWeight: FontWeight.w600, color: NayColors.accent),
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
                    color: NayColors.surface,
                    child: ExpansionTile(
                      title: Row(children: [
                        Text('${o.id} — ${o.customerName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: o.isPhysical
                              ? Colors.teal.shade900.withValues(alpha: 0.85)
                              : NayColors.wine,
                          side: BorderSide(
                            color: o.isPhysical
                                ? Colors.tealAccent.withValues(alpha: 0.5)
                                : NayColors.primary.withValues(alpha: 0.6),
                          ),
                          label: Text(
                            o.channel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: o.isPhysical ? Colors.tealAccent.shade100 : NayColors.accent,
                            ),
                          ),
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
                                style: TextStyle(fontSize: 12, color: NayColors.textMuted)),
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
                                ? 'Canal: Tienda física (Atendió: ${o.cashierName})${o.address.isNotEmpty && o.address != 'Retiro en tienda' ? '\nDirección: ${o.address}' : ''}'
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
        color: NayColors.surface,
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
                  style: TextStyle(color: NayColors.textMuted, fontSize: 12),
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
        color: NayColors.surface,
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
        color: NayColors.surface,
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
              style: TextStyle(color: NayColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 10),
            for (final u in state.users.where((u) => u.isCashier))
              ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: u.active ? Colors.teal.shade900 : NayColors.surfaceElevated,
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
        color: NayColors.surface,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Seguridad y Base de Datos local', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SelectableText('Archivo de base de datos: ${LocalDb.file.path}',
                style: TextStyle(color: NayColors.textMuted, fontSize: 13)),
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
