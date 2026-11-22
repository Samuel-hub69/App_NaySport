import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../data.dart';
import '../models.dart';
import '../theme.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  int _step = 0;
  final _shipForm = GlobalKey<FormState>();
  final _payForm = GlobalKey<FormState>();

  Country? _country;
  final _postal = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();

  PaymentMethod _method = PaymentMethod.paypal;
  final _cardNumber = TextEditingController();
  final _cardName = TextEditingController();
  final _cardExp = TextEditingController();
  final _cardCvv = TextEditingController();
  final _paypalEmail = TextEditingController();

  void _next() {
    if (_step == 0) {
      if (_shipForm.currentState!.validate()) setState(() => _step = 1);
    } else if (_step == 1) {
      if (_payForm.currentState?.validate() ?? true) setState(() => _step = 2);
    } else {
      _pay();
    }
  }

  Future<void> _pay() async {
    final state = AppScope.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Text('Procesando pago con ${_method.label}...'),
        ]),
      ),
    );
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.pop(context);
    final total = state.total;
    final order = 'NS-${DateTime.now().millisecondsSinceEpoch % 1000000}';
    state.clearCart();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        title: const Text('¡Compra realizada!'),
        content: Text(
          'Pedido $order\nTotal pagado: \$${total.toStringAsFixed(2)}\n'
          'Envío a: ${_address.text}, ${_city.text}, ${_country!.name} (CP ${_postal.text})',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Volver a la tienda')),
        ],
      ),
    );
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Finalizar compra')),
      body: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Stepper(
            currentStep: _step,
            onStepTapped: (i) {
              if (i < _step) setState(() => _step = i);
            },
            onStepContinue: _next,
            onStepCancel: _step == 0 ? null : () => setState(() => _step--),
            controlsBuilder: (_, d) => Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Row(children: [
                FilledButton(
                  onPressed: d.onStepContinue,
                  child: Text(_step == 2 ? 'Pagar \$${state.total.toStringAsFixed(2)}' : 'Continuar'),
                ),
                const SizedBox(width: 12),
                if (_step > 0) TextButton(onPressed: d.onStepCancel, child: const Text('Atrás')),
              ]),
            ),
            steps: [
              Step(
                title: const Text('Dirección de envío'),
                isActive: _step >= 0,
                state: _step > 0 ? StepState.complete : StepState.indexed,
                content: _shippingForm(),
              ),
              Step(
                title: const Text('Método de pago'),
                isActive: _step >= 1,
                state: _step > 1 ? StepState.complete : StepState.indexed,
                content: _paymentForm(),
              ),
              Step(
                title: const Text('Confirmar'),
                isActive: _step >= 2,
                content: _confirm(state),
              ),
            ],
          ),
        ),
        _summary(state),
      ]),
    );
  }

  Widget _shippingForm() {
    return Form(
      key: _shipForm,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(children: [
          DropdownButtonFormField<Country>(
            initialValue: _country,
            decoration: const InputDecoration(labelText: 'País', prefixIcon: Icon(Icons.public)),
            items: [
              for (final c in kCountries)
                DropdownMenuItem(value: c, child: Text('${c.flag}  ${c.name}')),
            ],
            onChanged: (c) => setState(() => _country = c),
            validator: (c) => c == null ? 'Selecciona tu país' : null,
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _postal,
                decoration: InputDecoration(
                  labelText: 'Código postal',
                  prefixIcon: const Icon(Icons.markunread_mailbox_outlined),
                  hintText: _country?.postalHint,
                ),
                validator: (v) {
                  if (_country == null) return 'Primero elige el país';
                  return _country!.postalPattern.hasMatch(v?.trim() ?? '')
                      ? null
                      : 'Código postal inválido (${_country!.postalHint})';
                },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextFormField(
                controller: _city,
                decoration: const InputDecoration(labelText: 'Ciudad', prefixIcon: Icon(Icons.location_city)),
                validator: (v) => (v ?? '').trim().length < 2 ? 'Ingresa la ciudad' : null,
              ),
            ),
          ]),
          const SizedBox(height: 14),
          TextFormField(
            controller: _address,
            decoration: const InputDecoration(labelText: 'Dirección (calle, número, referencia)', prefixIcon: Icon(Icons.home_outlined)),
            validator: (v) => (v ?? '').trim().length < 5 ? 'Ingresa una dirección válida' : null,
          ),
        ]),
      ),
    );
  }

  Widget _paymentForm() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 12, runSpacing: 12, children: [
          for (final m in PaymentMethod.values)
            _MethodTile(method: m, selected: _method == m, onTap: () => setState(() => _method = m)),
        ]),
        const SizedBox(height: 20),
        Form(key: _payForm, child: _methodDetails()),
      ]),
    );
  }

  Widget _methodDetails() {
    switch (_method) {
      case PaymentMethod.card:
        return Column(children: [
          TextFormField(
            controller: _cardNumber,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(16)],
            decoration: const InputDecoration(labelText: 'Número de tarjeta', prefixIcon: Icon(Icons.credit_card)),
            validator: (v) => _luhn(v ?? '') ? null : 'Número de tarjeta inválido',
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _cardName,
            decoration: const InputDecoration(labelText: 'Nombre en la tarjeta'),
            validator: (v) => (v ?? '').trim().length < 3 ? 'Requerido' : null,
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _cardExp,
                decoration: const InputDecoration(labelText: 'Vencimiento (MM/AA)'),
                inputFormatters: [LengthLimitingTextInputFormatter(5)],
                validator: _expValidator,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextFormField(
                controller: _cardCvv,
                obscureText: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                decoration: const InputDecoration(labelText: 'CVV'),
                validator: (v) => (v ?? '').length >= 3 ? null : 'CVV inválido',
              ),
            ),
          ]),
        ]);
      case PaymentMethod.paypal:
        return TextFormField(
          controller: _paypalEmail,
          decoration: const InputDecoration(labelText: 'Correo de tu cuenta PayPal', prefixIcon: Icon(Icons.email_outlined)),
          validator: (v) => RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(v?.trim() ?? '') ? null : 'Correo no válido',
        );
      case PaymentMethod.transfer:
        return const _InfoBox('Al confirmar recibirás los datos bancarios por correo. '
            'Tu pedido se enviará cuando se acredite el pago (24-48 h).');
      case PaymentMethod.cash:
        return const _InfoBox('Pagarás en efectivo al recibir tu pedido. Se aplica un cargo adicional de \$0 en esta versión de prueba.');
      default:
        return _InfoBox('Serás redirigido a ${_method.label} para autorizar el pago de forma segura.');
    }
  }

  String? _expValidator(String? v) {
    final m = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(v ?? '');
    if (m == null) return 'Formato MM/AA';
    final month = int.parse(m[1]!), year = 2000 + int.parse(m[2]!);
    if (month < 1 || month > 12) return 'Mes inválido';
    final now = DateTime.now();
    if (DateTime(year, month + 1).isBefore(DateTime(now.year, now.month + 1))) return 'Tarjeta vencida';
    return null;
  }

  /// Validación Luhn (la que usan las tarjetas reales).
  bool _luhn(String n) {
    if (n.length < 13) return false;
    var sum = 0;
    var alt = false;
    for (var i = n.length - 1; i >= 0; i--) {
      var d = int.parse(n[i]);
      if (alt) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      sum += d;
      alt = !alt;
    }
    return sum % 10 == 0;
  }

  Widget _confirm(AppState state) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Card(
        elevation: 0,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Cliente: ${state.user?.name ?? ''} (${state.user?.email ?? ''})'),
            const SizedBox(height: 8),
            if (_country != null)
              Text('Envío: ${_address.text}, ${_city.text}, ${_country!.flag} ${_country!.name} — CP ${_postal.text}'),
            const SizedBox(height: 8),
            Row(children: [
              Icon(_method.icon, color: _method.color),
              const SizedBox(width: 8),
              Text('Pago: ${_method.label}'),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _summary(AppState state) {
    return Container(
      width: 340,
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Tu pedido', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        for (final i in state.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Expanded(child: Text('${i.quantity}× ${i.product.name}${i.size != null ? ' (${i.size})' : ''}')),
              Text('\$${i.total.toStringAsFixed(2)}'),
            ]),
          ),
        const Divider(height: 24),
        Row(children: [const Text('Envío'), const Spacer(), Text(state.shipping == 0 ? 'GRATIS' : '\$${state.shipping.toStringAsFixed(2)}')]),
        const SizedBox(height: 6),
        Row(children: [
          const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const Spacer(),
          Text('\$${state.total.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: NayColors.primary)),
        ]),
      ]),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;
  const _MethodTile({required this.method, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 190,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? method.color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? method.color : Colors.grey.shade300, width: selected ? 2 : 1),
        ),
        child: Row(children: [
          Icon(method.icon, color: method.color, size: 28),
          const SizedBox(width: 10),
          Expanded(child: Text(method.label, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String text;
  const _InfoBox(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.info_outline, color: Colors.blue),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ]),
    );
  }
}
