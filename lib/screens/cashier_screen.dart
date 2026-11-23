import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../pdf_export.dart';
import '../theme.dart';
import 'login_screen.dart';

class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key});

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final user = state.user;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Row(children: [
          const BrandHeader(logoSize: 46),
          const SizedBox(width: 20),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, icon: Icon(Icons.point_of_sale), label: Text('Caja / Ventas')),
              ButtonSegment(value: 1, icon: Icon(Icons.today_outlined), label: Text('Mis ventas de hoy')),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
        ]),
        actions: [
          Chip(
            avatar: const Icon(Icons.currency_exchange, size: 16, color: NayColors.primary),
            backgroundColor: NayColors.logoBg,
            label: Text('${state.settings.exchangeRate.toStringAsFixed(2)} Bs/\$',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          Chip(
            avatar: const Icon(Icons.badge_outlined, size: 16, color: NayColors.accent),
            label: Text('Cajero: ${user?.name ?? ''}'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
            onPressed: () {
              state.logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen(isEntryGate: true)),
                (_) => false,
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _tab == 0 ? const CashierPosView() : const _CashierTodayView(),
    );
  }
}

/// Vista reutilizable de Caja / Ventas (usada por el Cajero y también disponible en el Panel Admin).
class CashierPosView extends StatefulWidget {
  const CashierPosView({super.key});

  @override
  State<CashierPosView> createState() => _CashierPosViewState();
}

class _CashierPosViewState extends State<CashierPosView> {
  String _query = '';
  String? _catId;
  final List<CartItem> _saleItems = [];
  final _scanCtrl = TextEditingController();
  final _scanFocus = FocusNode();

  final _custForm = GlobalKey<FormState>();
  final _custName = TextEditingController();
  final _custDoc = TextEditingController();
  final _custPhone = TextEditingController();
  final _custAddress = TextEditingController();

  PhysicalPaymentMethod _method = PhysicalPaymentMethod.pagoMovil;
  final _payForm = GlobalKey<FormState>();
  final _refCtrl = TextEditingController();
  final _zelleCtrl = TextEditingController();

  @override
  void dispose() {
    _scanCtrl.dispose();
    _scanFocus.dispose();
    _custName.dispose();
    _custDoc.dispose();
    _custPhone.dispose();
    _custAddress.dispose();
    _refCtrl.dispose();
    _zelleCtrl.dispose();
    super.dispose();
  }

  int _qtyInSale(String productId, {String? color}) => _saleItems
      .where((i) => i.product.id == productId && (color == null || i.color == color))
      .fold(0, (s, i) => s + i.quantity);

  int _availableInSale(Product p, {String? color}) =>
      p.stockForColor(color) - _qtyInSale(p.id, color: color);

  void _addToSale(Product p, {String? color, String? size, int qty = 1}) {
    if (_availableInSale(p, color: color) < qty) {
      showSnack(context, 'Stock insuficiente en ${color ?? p.name}', error: true);
      return;
    }
    setState(() {
      final idx = _saleItems.indexWhere((i) => i.product.id == p.id && i.color == color && i.size == size);
      if (idx >= 0) {
        _saleItems[idx].quantity += qty;
      } else {
        _saleItems.add(CartItem(product: p, color: color, size: size, quantity: qty));
      }
    });
  }

  Future<void> _openPicker(Product p) async {
    final res = await showAnimatedDialog<List<({String? color, String? size, int qty})>>(
      context: context,
      builder: (_) => _PosProductPicker(
        product: p,
        alreadyInSaleForColor: (c) => _qtyInSale(p.id, color: c),
      ),
    );
    if (res == null || res.isEmpty) return;
    for (final line in res) {
      _addToSale(p, color: line.color, size: line.size, qty: line.qty);
    }
  }

  /// Procesa un código escaneado (pistola de barras o teclado + Enter) y agrega automáticamente
  /// el producto con su color y talla exactos si corresponde a un código de variante.
  Future<void> _handleBarcodeScan(AppState state, String raw) async {
    final code = raw.trim();
    if (code.isEmpty) return;
    final match = state.resolveBarcode(code);
    if (match == null) {
      showSnack(context, 'Código "$code" no encontrado en el catálogo', error: true);
      _scanCtrl.clear();
      _scanFocus.requestFocus();
      return;
    }
    _scanCtrl.clear();
    if (match.exactVariant) {
      if (_availableInSale(match.product, color: match.color) <= 0) {
        showSnack(context, 'Sin stock disponible en ${match.color ?? match.product.name}', error: true);
      } else {
        _addToSale(match.product, color: match.color, size: match.size, qty: 1);
        final variantLabel = [
          if (match.color != null) match.color!,
          if (match.size != null) 'Talla ${match.size}',
        ].join(' / ');
        showSnack(
          context,
          'Agregado: ${match.product.name}${variantLabel.isNotEmpty ? ' ($variantLabel)' : ''}',
        );
      }
      _scanFocus.requestFocus();
    } else {
      await _openPicker(match.product);
      if (mounted) _scanFocus.requestFocus();
    }
  }

  String get _paymentDetail {
    switch (_method) {
      case PhysicalPaymentMethod.pos:
        return 'Cobrado por punto de venta';
      case PhysicalPaymentMethod.pagoMovil:
        return 'Ref: ${_refCtrl.text.trim()}';
      case PhysicalPaymentMethod.zelle:
        return 'Zelle: ${_zelleCtrl.text.trim()}';
      case PhysicalPaymentMethod.cashUsd:
        return 'Recibido en dólares físicos';
      case PhysicalPaymentMethod.cashBs:
        return 'Recibido en bolívares físicos';
    }
  }

  Future<void> _checkout(AppState state) async {
    if (_saleItems.isEmpty) return;
    final custOk = _custForm.currentState?.validate() ?? false;
    final payOk = _payForm.currentState?.validate() ?? true;
    if (!custOk) {
      showSnack(context, 'Completa los datos del cliente (Nombre, Cédula, Teléfono y Dirección)', error: true);
      return;
    }
    if (!payOk) {
      showSnack(context, 'Completa los datos del método de pago', error: true);
      return;
    }

    // Verifica stock por color antes de cobrar
    for (final item in _saleItems) {
      final needed = _qtyInSale(item.product.id, color: item.color);
      if (needed > item.product.stockForColor(item.color)) {
        showSnack(context, 'Stock insuficiente de ${item.product.name} (${item.color ?? ''})', error: true);
        return;
      }
    }

    final order = await state.placePhysicalSale(
      saleItems: _saleItems,
      customerName: _custName.text.trim(),
      customerDocument: _custDoc.text.trim(),
      customerPhone: _custPhone.text.trim(),
      customerAddress: _custAddress.text.trim(),
      paymentMethod: _method.label,
      paymentDetails: _paymentDetail,
    );
    if (!mounted) return;

    setState(() {
      _saleItems.clear();
      _custName.clear();
      _custDoc.clear();
      _custPhone.clear();
      _custAddress.clear();
      _refCtrl.clear();
      _zelleCtrl.clear();
    });

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        title: const Text('¡Venta registrada!'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Chip(
            backgroundColor: NayColors.logoBg,
            label: Text('Comprobante ${order.id}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: NayColors.accent)),
          ),
          const SizedBox(height: 10),
          Text('Total cobrado: ${usd(order.total)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: NayColors.primary)),
          Text(bs(order.total, order.exchangeRate), style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Text('Pago: ${order.paymentMethod}'),
          Text('Cliente: ${order.customerName}'),
        ]),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('Imprimir comprobante'),
            onPressed: () async {
              final bytes = await PdfExporter.buildReceiptPdf(order);
              await PdfExporter.openToPrint(bytes, 'Venta_${order.id}.pdf');
            },
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Siguiente cliente')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final rate = state.settings.exchangeRate;
    final filtered = state.activeProducts.where((p) {
      if (_catId != null && p.categoryId != _catId) return false;
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        if (!p.name.toLowerCase().contains(q) && !p.sku.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();

    final totalUnits = _saleItems.fold(0, (s, i) => s + i.quantity);
    final pct = state.discountFor(totalUnits);
    final subtotal = _saleItems.fold(0.0, (s, i) => s + i.gross);
    final discount = subtotal * pct / 100;
    final total = subtotal - discount;

    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Izquierda: catálogo rápido para agregar prendas
      Expanded(
        child: Column(children: [
          Container(
            color: NayColors.surface,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _scanCtrl,
                    focusNode: _scanFocus,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (v) => _handleBarcodeScan(state, v),
                    decoration: InputDecoration(
                      hintText: 'Escanear código de barras o SKU (ej. CAL-001-NEG-39) + Enter...',
                      prefixIcon: const Icon(Icons.qr_code_scanner, color: NayColors.primary),
                      suffixIcon: IconButton(
                        tooltip: 'Agregar por código',
                        icon: const Icon(Icons.add_circle, color: NayColors.primary),
                        onPressed: () => _handleBarcodeScan(state, _scanCtrl.text),
                      ),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o SKU...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${filtered.length} disponibles', style: const TextStyle(color: NayColors.textMuted)),
              ]),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  ChoiceChip(
                    label: const Text('Todo'),
                    selected: _catId == null,
                    onSelected: (_) => setState(() => _catId = null),
                  ),
                  const SizedBox(width: 8),
                  for (final c in state.categories) ...[
                    ChoiceChip(
                      avatar: Icon(c.icon, size: 16),
                      label: Text(c.name),
                      selected: _catId == c.id,
                      onSelected: (_) => setState(() => _catId = c.id),
                    ),
                    const SizedBox(width: 8),
                  ],
                ]),
              ),
            ]),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No hay productos con ese filtro'))
                : GridView.builder(
                    cacheExtent: 200,
                    padding: const EdgeInsets.all(20),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 230,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final p = filtered[i];
                      final avail = _availableInSale(p);
                      return RepaintBoundary(
                        child: Card(
                          elevation: 0,
                          color: NayColors.surface,
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: NayColors.border),
                          ),
                          child: InkWell(
                            onTap: avail <= 0 ? null : () => _openPicker(p),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(
                                child: Stack(fit: StackFit.expand, children: [
                                  ProductImage(
                                    p.image,
                                    cacheWidth: 260,
                                    fallbackIcon: state.categoryIcon(p.categoryId),
                                  ),
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: Chip(
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: avail <= 0
                                          ? Colors.red.shade900.withValues(alpha: 0.92)
                                          : (avail <= 5
                                              ? Colors.orange.shade900.withValues(alpha: 0.92)
                                              : Colors.black.withValues(alpha: 0.72)),
                                      label: Text(avail <= 0 ? 'Agotado' : 'Stock: $avail',
                                          style: const TextStyle(
                                              fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                    ),
                                  ),
                                ]),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(
                                    p.sku,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontFamily: 'monospace',
                                      color: NayColors.accent,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(p.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white)),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    Expanded(child: PriceText(p.price, fontSize: 14.5, rateOverride: rate)),
                                    Icon(Icons.add_circle, color: avail > 0 ? NayColors.primary : Colors.grey, size: 26),
                                  ]),
                                ]),
                              ),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
      // Derecha: ticket de venta actual + cliente + métodos de pago físicos
      Container(
        width: 440,
        decoration: const BoxDecoration(
          color: NayColors.surface,
          border: Border(left: BorderSide(color: NayColors.border)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.shopping_cart_checkout, color: NayColors.primary),
              const SizedBox(width: 8),
              Text('Venta actual ($totalUnits)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_saleItems.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _saleItems.clear()),
                  child: const Text('Vaciar', style: TextStyle(color: Colors.red)),
                ),
            ]),
            const Divider(),
            // Datos del cliente físico (obligatorios para registro de la compra)
            const Text('Datos del cliente', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Form(
              key: _custForm,
              child: Column(children: [
                TextFormField(
                  controller: _custName,
                  inputFormatters: [nameInputFormatter],
                  decoration: const InputDecoration(labelText: 'Nombre completo y apellido', isDense: true),
                  validator: validateFullName,
                ),
                const SizedBox(height: 8),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: TextFormField(
                      controller: _custDoc,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                      decoration: const InputDecoration(
                        labelText: 'Cédula',
                        hintText: 'Hasta 10 dígitos',
                        isDense: true,
                      ),
                      validator: validateCedula,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _custPhone,
                      keyboardType: TextInputType.phone,
                      inputFormatters: const [PlusDigitsPhoneFormatter()],
                      decoration: const InputDecoration(labelText: 'Teléfono', isDense: true),
                      validator: validatePhone,
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _custAddress,
                  decoration: const InputDecoration(labelText: 'Dirección', isDense: true),
                  validator: (v) => (v ?? '').trim().length >= 5 ? null : 'Ingresa la dirección',
                ),
              ]),
            ),
            const SizedBox(height: 12),
            if (_saleItems.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(color: NayColors.bg, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Text('Toca una prenda a la izquierda para agregarla',
                    style: TextStyle(color: Colors.grey.shade600)),
              )
            else
              for (final item in _saleItems)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: NayColors.bg, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        Row(children: [
                          if (item.color != null) ...[
                            ColorDot(item.color!, size: 12),
                            const SizedBox(width: 4),
                            Text(item.color!, style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 8),
                          ],
                          if (item.size != null) Text('Talla ${item.size}', style: const TextStyle(fontSize: 12)),
                        ]),
                        Text('${usd(item.product.price)} c/u (${bs(item.product.price, rate)})',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                      ]),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                      onPressed: () {
                        setState(() {
                          item.quantity--;
                          if (item.quantity <= 0) _saleItems.remove(item);
                        });
                      },
                    ),
                    Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      onPressed: () => _addToSale(item.product, color: item.color, size: item.size, qty: 1),
                    ),
                    SizedBox(
                      width: 68,
                      child: Text(usd(item.gross), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ),
            const Divider(height: 22),
            Row(children: [const Text('Subtotal'), const Spacer(), Text(usd(subtotal))]),
            if (pct > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  Text('Descuento (${pct.toStringAsFixed(0)}% por $totalUnits unid.)',
                      style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('-${usd(discount)}',
                      style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                ]),
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: NayColors.logoBg.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                const Text('TOTAL A COBRAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                PriceText(total, fontSize: 20, color: NayColors.primary, align: CrossAxisAlignment.end),
              ]),
            ),
            const SizedBox(height: 14),
            const Text('Método de pago (Tienda física)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final m in PhysicalPaymentMethod.values)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _method = m),
                  child: Container(
                    width: 196,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _method == m ? m.color.withValues(alpha: 0.2) : NayColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _method == m ? m.color : NayColors.border, width: _method == m ? 2 : 1),
                    ),
                    child: Row(children: [
                      Icon(m.icon, color: m.color, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(m.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            Form(key: _payForm, child: _physicalPaymentField(total, rate)),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: Text('Cobrar y registrar venta (${usd(total)})'),
              onPressed: _saleItems.isEmpty ? null : () => _checkout(state),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _physicalPaymentField(double total, double rate) {
    switch (_method) {
      case PhysicalPaymentMethod.pos:
        return Text('Cobrar ${bs(total, rate)} por punto de venta en tienda.',
            style: TextStyle(color: Colors.purple.shade800, fontWeight: FontWeight.w600));
      case PhysicalPaymentMethod.pagoMovil:
        return TextFormField(
          controller: _refCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
          decoration: InputDecoration(
            labelText: 'N° de referencia',
            helperText: 'Monto en Bs: ${bs(total, rate)}',
            isDense: true,
          ),
          validator: (v) => (v ?? '').trim().length >= 4 ? null : 'Ingresa la referencia',
        );
      case PhysicalPaymentMethod.zelle:
        return TextFormField(
          controller: _zelleCtrl,
          decoration: InputDecoration(
            labelText: 'Titular o confirmación Zelle',
            helperText: 'Monto en dólares: ${usd(total)}',
            isDense: true,
          ),
          validator: (v) => (v ?? '').trim().length >= 3 ? null : 'Requerido',
        );
      case PhysicalPaymentMethod.cashUsd:
        return Text('Cobrar ${usd(total)} en dólares físicos.',
            style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600));
      case PhysicalPaymentMethod.cashBs:
        return Text('Cobrar ${bs(total, rate)} en bolívares físicos.',
            style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w600));
    }
  }
}

class _PosProductPicker extends StatefulWidget {
  final Product product;
  final int Function(String? color) alreadyInSaleForColor;
  const _PosProductPicker({required this.product, required this.alreadyInSaleForColor});

  @override
  State<_PosProductPicker> createState() => _PosProductPickerState();
}

class _PosProductPickerState extends State<_PosProductPicker> {
  String? _color;
  String? _size;
  int _qty = 1;
  bool _tried = false;
  final List<({String? color, String? size, int qty})> _bundle = [];

  @override
  void initState() {
    super.initState();
    if (widget.product.colors.length == 1) _color = widget.product.colors.first;
    if (widget.product.sizes.length == 1) _size = widget.product.sizes.first;
  }

  int _availForColor(String? c) {
    final p = widget.product;
    final inBundle = _bundle.where((e) => e.color == c).fold(0, (s, e) => s + e.qty);
    return p.stockForColor(c) - widget.alreadyInSaleForColor(c) - inBundle;
  }

  String? get _missing {
    final p = widget.product;
    if (p.colors.isNotEmpty && _color == null) return 'Elige un color';
    if (p.sizes.isNotEmpty && _size == null) return 'Elige una talla';
    return null;
  }

  void _addAndPickAnother(int avail) {
    if (_missing != null) {
      setState(() => _tried = true);
      return;
    }
    if (avail <= 0) return;
    final q = _qty.clamp(1, avail);
    final p = widget.product;
    setState(() {
      final idx = _bundle.indexWhere((e) => e.color == _color && e.size == _size);
      if (idx >= 0) {
        final prev = _bundle[idx];
        _bundle[idx] = (color: prev.color, size: prev.size, qty: prev.qty + q);
      } else {
        _bundle.add((color: _color, size: _size, qty: q));
      }
      _color = p.colors.length == 1 ? p.colors.first : null;
      _size = p.sizes.length == 1 ? p.sizes.first : null;
      _qty = 1;
      _tried = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final currentAvail = _availForColor(_color);
    final safeQty = currentAvail <= 0 ? 0 : _qty.clamp(1, currentAvail);
    final hasReady = _missing == null && safeQty > 0;
    final totalSelected = _bundle.fold(0, (s, e) => s + e.qty) + (hasReady ? safeQty : 0);

    return AlertDialog(
      title: Text(p.name),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            PriceText(p.price, fontSize: 18, color: NayColors.primary),
            const SizedBox(height: 12),
            if (p.colors.isNotEmpty) ...[
              Row(children: [
                Text('Color (${_color ?? 'elige uno'}):', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (_tried && _color == null)
                  const Text('  ← Requerido', style: TextStyle(color: Colors.red, fontSize: 12)),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in p.colors)
                  Builder(builder: (_) {
                    final av = _availForColor(c);
                    return ChoiceChip(
                      avatar: ColorDot(c, size: 16),
                      label: Text('$c ($av)'),
                      selected: _color == c,
                      onSelected: av <= 0 ? null : (_) => setState(() => _color = c),
                    );
                  }),
              ]),
              const SizedBox(height: 14),
            ],
            if (p.sizes.isNotEmpty) ...[
              Row(children: [
                Text('Talla (${_size ?? 'elige una'}):', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (_tried && _size == null)
                  const Text('  ← Requerido', style: TextStyle(color: Colors.red, fontSize: 12)),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in p.sizes)
                  ChoiceChip(label: Text(s), selected: _size == s, onSelected: (_) => setState(() => _size = s)),
              ]),
              const SizedBox(height: 14),
            ],
            Row(children: [
              const Text('Cantidad:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              IconButton.outlined(
                icon: const Icon(Icons.remove),
                onPressed: safeQty > 1 ? () => setState(() => _qty = safeQty - 1) : null,
              ),
              SizedBox(width: 36, child: Text('$safeQty', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16))),
              IconButton.outlined(
                icon: const Icon(Icons.add),
                onPressed: safeQty < currentAvail ? () => setState(() => _qty = safeQty + 1) : null,
              ),
              if ((p.colors.length > 1 || p.sizes.length > 1) && currentAvail > 0) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add_circle_outline, size: 17),
                    label: const Text('Añadir y otro color'),
                    onPressed: () => _addAndPickAnother(currentAvail),
                  ),
                ),
              ],
            ]),
            if (_bundle.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (var i = 0; i < _bundle.length; i++)
                  Chip(
                    avatar: _bundle[i].color != null ? ColorDot(_bundle[i].color!, size: 14) : null,
                    label: Text('${_bundle[i].qty}× ${[?_bundle[i].color, ?_bundle[i].size].join(' / ')}'),
                    onDeleted: () => setState(() => _bundle.removeAt(i)),
                  ),
              ]),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (_bundle.isEmpty && _missing != null) {
              setState(() => _tried = true);
              return;
            }
            final out = [..._bundle, if (hasReady) (color: _color, size: _size, qty: safeQty)];
            Navigator.pop(context, out);
          },
          child: Text('Agregar ($totalSelected)'),
        ),
      ],
    );
  }
}

/// Vista del Cajero: solo ve las ventas que realizó HOY y el total cobrado (sin ganancias ni opción de borrar).
class _CashierTodayView extends StatelessWidget {
  const _CashierTodayView();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final rate = state.settings.exchangeRate;
    final myToday = state.ordersForDay(
      DateTime.now(),
      channel: 'Tienda física',
      cashierName: state.user?.name,
    );
    final totalUsd = myToday.fold(0.0, (s, o) => s + o.total);
    final totalUnits = myToday.fold(0, (s, o) => s + o.units);

    final byMethod = <String, double>{};
    for (final o in myToday) {
      byMethod[o.paymentMethod] = (byMethod[o.paymentMethod] ?? 0) + o.total;
    }

    return ListView(padding: const EdgeInsets.all(24), children: [
      Text('Resumen de hoy — ${fmtDay(DateTime.now())}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      Wrap(spacing: 16, runSpacing: 16, children: [
        _CashierStatCard(title: 'Total cobrado hoy', value: usd(totalUsd), sub: bs(totalUsd, rate), color: Colors.green),
        _CashierStatCard(
            title: 'Ventas realizadas', value: '${myToday.length}', sub: '$totalUnits prendas vendidas', color: NayColors.primary),
      ]),
      if (byMethod.isNotEmpty) ...[
        const SizedBox(height: 20),
        Card(
          elevation: 0,
          color: NayColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Desglose por método de pago (hoy)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Divider(),
              for (final e in byMethod.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Text(e.key, style: const TextStyle(fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text('${usd(e.value)}  (${bs(e.value, rate)})',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                ),
            ]),
          ),
        ),
      ],
      const SizedBox(height: 20),
      const Text('Detalle de ventas de hoy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      if (myToday.isEmpty)
        const Card(
          elevation: 0,
          color: NayColors.surface,
          child: Padding(padding: EdgeInsets.all(28), child: Center(child: Text('Aún no registras ventas hoy.'))),
        )
      else
        for (final o in myToday) ...[
          Card(
            elevation: 0,
            color: NayColors.surface,
            child: ExpansionTile(
              title: Text('${o.id} — ${o.customerName}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${fmtDate(o.date)} • ${o.paymentMethod} • ${o.units} unid.'),
              trailing: PriceText(o.total, fontSize: 15, color: NayColors.primary, align: CrossAxisAlignment.end),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              children: [
                const Divider(),
                if ([o.customerDocument, o.customerPhone, o.address].any((s) => s.isNotEmpty && s != 'Retiro en tienda'))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        [
                          if (o.customerDocument.isNotEmpty) 'CI: ${o.customerDocument}',
                          if (o.customerPhone.isNotEmpty) 'Tel: ${o.customerPhone}',
                          if (o.address.isNotEmpty && o.address != 'Retiro en tienda') 'Dir: ${o.address}',
                        ].join(' • '),
                        style: const TextStyle(fontSize: 12.5, color: NayColors.textMuted),
                      ),
                    ),
                  ),
                for (final l in o.lines)
                  Row(children: [
                    Expanded(child: Text('${l.qty}× ${l.productName}${l.variant.isNotEmpty ? ' (${l.variant})' : ''}')),
                    Text(usd(l.total)),
                  ]),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
    ]);
  }
}

class _CashierStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String sub;
  final Color color;
  const _CashierStatCard({required this.title, required this.value, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NayColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NayColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: NayColors.textMuted)),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(sub, style: const TextStyle(color: NayColors.textMuted, fontSize: 13)),
      ]),
    );
  }
}
