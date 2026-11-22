import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../data.dart';
import '../format.dart';
import '../models.dart';
import '../pdf_export.dart';
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
  String _cashCurrency = 'Dólares en efectivo (\$)';
  final _cardNumber = TextEditingController();
  final _cardName = TextEditingController();
  final _cardExp = TextEditingController();
  final _cardCvv = TextEditingController();
  final _paypalEmail = TextEditingController();
  final _pagoMovilPhone = TextEditingController();
  final _pagoMovilBank = TextEditingController();
  final _zelleAccount = TextEditingController();

  @override
  void dispose() {
    _postal.dispose();
    _city.dispose();
    _address.dispose();
    _cardNumber.dispose();
    _cardName.dispose();
    _cardExp.dispose();
    _cardCvv.dispose();
    _paypalEmail.dispose();
    _pagoMovilPhone.dispose();
    _pagoMovilBank.dispose();
    _zelleAccount.dispose();
    super.dispose();
  }

  String get _paymentDescription =>
      _method == PaymentMethod.cash ? 'Efectivo ($_cashCurrency)' : _method.label;

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
    final state = AppScope.read(context);
    for (final item in state.items) {
      if (state.qtyInCart(item.product.id) > item.product.stock) {
        showSnack(context, 'Stock insuficiente para ${item.product.name}', error: true);
        return;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Flexible(child: Text('Procesando pago con $_paymentDescription...')),
        ]),
      ),
    );
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.pop(context);

    final order = await state.placeOrder(
      country: _country!.name,
      city: _city.text.trim(),
      address: _address.text.trim(),
      postalCode: _postal.text.trim(),
      paymentMethod: _paymentDescription,
    );
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        title: const Text('¡Compra realizada!'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Pedido ${order.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Total pagado: ${usd(order.total)} (${bs(order.total, order.exchangeRate)})'),
          const SizedBox(height: 6),
          Text(
            'Envío a: ${order.address}, ${order.city}, ${order.country} (CP ${order.postalCode})',
            textAlign: TextAlign.center,
          ),
        ]),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Descargar recibo'),
            onPressed: () async {
              final bytes = await PdfExporter.buildReceiptPdf(order);
              final path = await PdfExporter.savePdf(bytes, 'Recibo_${order.id}.pdf');
              if (path != null && ctx.mounted) showSnack(ctx, 'Recibo guardado');
            },
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('Imprimir PDF'),
            onPressed: () async {
              final bytes = await PdfExporter.buildReceiptPdf(order);
              await PdfExporter.openToPrint(bytes, 'Recibo_${order.id}.pdf');
            },
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Volver a la tienda')),
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
                  child: Text(_step == 2 ? 'Pagar ${usd(state.total)}' : 'Continuar'),
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
                content: _paymentForm(state),
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
              for (final c in kCountries) DropdownMenuItem(value: c, child: Text('${c.flag}  ${c.name}')),
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
            decoration: const InputDecoration(
                labelText: 'Dirección (calle, número, referencia)', prefixIcon: Icon(Icons.home_outlined)),
            validator: (v) => (v ?? '').trim().length < 5 ? 'Ingresa una dirección válida' : null,
          ),
        ]),
      ),
    );
  }

  Widget _paymentForm(AppState state) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 12, runSpacing: 12, children: [
          for (final m in PaymentMethod.values)
            _MethodTile(method: m, selected: _method == m, onTap: () => setState(() => _method = m)),
        ]),
        const SizedBox(height: 20),
        Form(key: _payForm, child: _methodDetails(state)),
      ]),
    );
  }

  Widget _methodDetails(AppState state) {
    final rate = state.settings.exchangeRate;
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
          decoration:
              const InputDecoration(labelText: 'Correo de tu cuenta PayPal', prefixIcon: Icon(Icons.email_outlined)),
          validator: (v) => RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(v?.trim() ?? '') ? null : 'Correo no válido',
        );
      case PaymentMethod.pagoMovil:
        return Column(children: [
          _InfoBox('Monto a transferir por Pago Móvil: ${bs(state.total, rate)} (tasa ${rate.toStringAsFixed(2)} Bs/\$).'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _pagoMovilPhone,
                decoration: const InputDecoration(
                    labelText: 'Tu teléfono (Pago Móvil)', prefixIcon: Icon(Icons.phone_android), hintText: '04141234567'),
                validator: (v) => RegExp(r'^\d{10,13}$').hasMatch(v?.replaceAll(RegExp(r'\D'), '') ?? '')
                    ? null
                    : 'Ingresa un teléfono válido',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _pagoMovilBank,
                decoration: const InputDecoration(labelText: 'Banco emisor', prefixIcon: Icon(Icons.account_balance)),
                validator: (v) => (v ?? '').trim().length < 3 ? 'Ingresa tu banco' : null,
              ),
            ),
          ]),
        ]);
      case PaymentMethod.zelle:
        return Column(children: [
          _InfoBox('Total a enviar por Zelle: ${usd(state.total)}.'),
          const SizedBox(height: 12),
          TextFormField(
            controller: _zelleAccount,
            decoration: const InputDecoration(
                labelText: 'Correo o titular de tu cuenta Zelle', prefixIcon: Icon(Icons.flash_on)),
            validator: (v) => (v ?? '').trim().length < 4 ? 'Ingresa los datos de tu Zelle' : null,
          ),
        ]);
      case PaymentMethod.transfer:
        return _InfoBox(
            'Al confirmar recibirás los datos bancarios. Monto: ${usd(state.total)} / ${bs(state.total, rate)}.');
      case PaymentMethod.cash:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Elige en qué moneda física pagarás:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, children: [
            ChoiceChip(
              label: Text('Dólares en efectivo (${usd(state.total)})'),
              selected: _cashCurrency.startsWith('Dólares'),
              onSelected: (_) => setState(() => _cashCurrency = 'Dólares en efectivo (\$)'),
            ),
            ChoiceChip(
              label: Text('Bolívares en efectivo (${bs(state.total, rate)})'),
              selected: _cashCurrency.startsWith('Bolívares'),
              onSelected: (_) => setState(() => _cashCurrency = 'Bolívares en efectivo (Bs)'),
            ),
          ]),
          const SizedBox(height: 12),
          const _InfoBox('Pagarás en efectivo al momento de recibir o retirar tu pedido.'),
        ]);
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
              Text('Pago: $_paymentDescription'),
            ]),
            const SizedBox(height: 8),
            Text('Total: ${usd(state.total)} (${bs(state.total, state.settings.exchangeRate)})',
                style: const TextStyle(fontWeight: FontWeight.bold, color: NayColors.primary)),
          ]),
        ),
      ),
    );
  }

  Widget _summary(AppState state) {
    final rate = state.settings.exchangeRate;
    return Container(
      width: 360,
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Tu pedido', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        for (final i in state.items) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(
                  '${i.quantity}× ${i.product.name}'
                  '${[if (i.color != null) i.color!, if (i.size != null) i.size!].isNotEmpty ? ' (${[
                        if (i.color != null) i.color!,
                        if (i.size != null) i.size!
                      ].join(', ')})' : ''}',
                ),
              ),
              const SizedBox(width: 8),
              Text(usd(i.gross - state.discountAmountFor(i))),
            ]),
          ),
        ],
        const Divider(height: 24),
        Row(children: [const Text('Subtotal'), const Spacer(), Text(usd(state.subtotal))]),
        if (state.discountTotal > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: [
              const Text('Descuentos', style: TextStyle(color: Colors.green)),
              const Spacer(),
              Text('-${usd(state.discountTotal)}', style: const TextStyle(color: Colors.green)),
            ]),
          ),
        const SizedBox(height: 4),
        Row(children: [
          const Text('Envío'),
          const Spacer(),
          Text(state.shipping == 0 ? 'GRATIS' : usd(state.shipping)),
        ]),
        const Divider(height: 20),
        Row(children: [
          const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const Spacer(),
          PriceText(state.total, fontSize: 17, color: NayColors.primary, align: CrossAxisAlignment.end),
        ]),
        const SizedBox(height: 4),
        Text('Tasa aplicada: ${rate.toStringAsFixed(2)} Bs/\$',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
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
        width: 195,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? method.color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? method.color : Colors.grey.shade300, width: selected ? 2 : 1),
        ),
        child: Row(children: [
          Icon(method.icon, color: method.color, size: 26),
          const SizedBox(width: 10),
          Expanded(child: Text(method.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
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
