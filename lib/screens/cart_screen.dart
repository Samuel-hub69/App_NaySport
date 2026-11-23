import 'package:flutter/material.dart';
import '../app_state.dart';
import '../format.dart';
import '../theme.dart';
import 'checkout_screen.dart';
import 'login_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final rate = state.settings.exchangeRate;
    return Scaffold(
      appBar: AppBar(title: Text('Mi carrito (${state.itemCount})')),
      body: state.items.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.shopping_bag_outlined, size: 96, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text('Tu carrito está vacío', style: TextStyle(fontSize: 20)),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Seguir comprando')),
              ]),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: state.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final item = state.items[i];
                      final pct = state.discountPercentFor(item);
                      return Card(
                        elevation: 0,
                        color: NayColors.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 90,
                                height: 100,
                                child: ProductImage(item.product.image,
                                    cacheWidth: 220,
                                    fallbackIcon: state.categoryIcon(item.product.categoryId)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(item.product.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Row(children: [
                                  if (item.color != null) ...[
                                    ColorDot(item.color!, size: 14),
                                    const SizedBox(width: 6),
                                    Text(item.color!),
                                    const SizedBox(width: 12),
                                  ],
                                  if (item.size != null) Text('Talla: ${item.size}'),
                                ]),
                                Text('${usd(item.product.price)} c/u',
                                    style: const TextStyle(color: NayColors.textMuted)),
                                if (pct > 0)
                                  Text('Descuento por cantidad: -${pct.toStringAsFixed(0)}%',
                                      style: TextStyle(color: Colors.greenAccent.shade200, fontSize: 12)),
                              ]),
                            ),
                            IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => state.decrement(item)),
                            Text('${item.quantity}', style: const TextStyle(fontSize: 16)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () {
                                if (!state.increment(item)) showSnack(context, 'No hay más stock', error: true);
                              },
                            ),
                            SizedBox(
                              width: 120,
                              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                if (pct > 0)
                                  Text(usd(item.gross),
                                      style: const TextStyle(
                                          decoration: TextDecoration.lineThrough, color: Colors.grey, fontSize: 12)),
                                PriceText(item.gross - state.discountAmountFor(item),
                                    fontSize: 16, align: CrossAxisAlignment.end),
                              ]),
                            ),
                            IconButton(
                              tooltip: 'Eliminar',
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => state.remove(item),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  width: 360,
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: NayColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: NayColors.border),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Resumen del pedido', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    _row('Subtotal', usd(state.subtotal)),
                    if (state.discountTotal > 0)
                      _row('Descuentos', '-${usd(state.discountTotal)}', color: Colors.greenAccent.shade200),
                    _row('Envío', state.shipping == 0 ? 'GRATIS' : usd(state.shipping),
                        color: state.shipping == 0 ? Colors.greenAccent.shade200 : null),
                    const Divider(height: 32),
                    _row('Total', usd(state.total), bold: true, color: NayColors.primary),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(bs(state.total, rate), style: const TextStyle(color: NayColors.textMuted)),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        child: const Text('Proceder al pago'),
                        onPressed: () async {
                          if (!state.isLoggedIn) {
                            final ok = await Navigator.push<bool>(
                                context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                            if (ok != true || !context.mounted) return;
                          }
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()));
                        },
                      ),
                    ),
                    if (!state.isLoggedIn)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('Necesitas iniciar sesión para comprar',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ),
                  ]),
                ),
              ],
            ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    final style = TextStyle(fontSize: bold ? 18 : 15, fontWeight: bold ? FontWeight.bold : FontWeight.normal);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(label, style: style),
        const Spacer(),
        Text(value, style: style.copyWith(color: color)),
      ]),
    );
  }
}
