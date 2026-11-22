import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';
import 'checkout_screen.dart';
import 'login_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
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
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final item = state.items[i];
                      return Card(
                        elevation: 0,
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 90,
                                height: 100,
                                child: NetImage(item.product.imageUrl, fallbackIcon: item.product.category.icon),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(item.product.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                if (item.size != null) Text('Talla: ${item.size}'),
                                Text('\$${item.product.price.toStringAsFixed(2)} c/u',
                                    style: TextStyle(color: Colors.grey.shade600)),
                              ]),
                            ),
                            IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => state.decrement(item)),
                            Text('${item.quantity}', style: const TextStyle(fontSize: 16)),
                            IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => state.increment(item)),
                            SizedBox(
                              width: 100,
                              child: Text('\$${item.total.toStringAsFixed(2)}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                  width: 340,
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Resumen del pedido', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    _row('Subtotal', state.subtotal),
                    _row('Envío', state.shipping, freeLabel: state.shipping == 0),
                    const Divider(height: 32),
                    _row('Total', state.total, bold: true),
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

  Widget _row(String label, double value, {bool bold = false, bool freeLabel = false}) {
    final style = TextStyle(fontSize: bold ? 18 : 15, fontWeight: bold ? FontWeight.bold : FontWeight.normal);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(label, style: style),
        const Spacer(),
        Text(freeLabel ? 'GRATIS' : '\$${value.toStringAsFixed(2)}',
            style: style.copyWith(color: freeLabel ? Colors.green : (bold ? NayColors.primary : null))),
      ]),
    );
  }
}
