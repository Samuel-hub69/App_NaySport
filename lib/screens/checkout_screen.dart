import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../data.dart';
import '../format.dart';
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
  final _phone = TextEditingController();
  final _postal = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();

  PaymentMethod _method = PaymentMethod.paypal;
  String _cashCurrency = 'Dólares en efectivo (\$)';
  final _cashChangeFor = TextEditingController();

  final _cardNumber = TextEditingController();
  final _cardName = TextEditingController();
  final _cardExp = TextEditingController();
  final _cardCvv = TextEditingController();
  final _paypalEmail = TextEditingController();
  final _pagoMovilPhone = TextEditingController();
  final _pagoMovilBank = TextEditingController();
  final _pagoMovilRef = TextEditingController();
  final _zelleAccount = TextEditingController();
  final _zelleRef = TextEditingController();
  final _transferBank = TextEditingController();
  final _transferRef = TextEditingController();

  Order? _completedOrder;
  bool _prefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_prefilled) {
      _prefilled = true;
      final u = AppScope.read(context).user;
      if (u != null && u.phone.isNotEmpty) _phone.text = u.phone;
      if (u != null && u.email.isNotEmpty) _paypalEmail.text = u.email;
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _postal.dispose();
    _city.dispose();
    _address.dispose();
    _cashChangeFor.dispose();
    _cardNumber.dispose();
    _cardName.dispose();
    _cardExp.dispose();
    _cardCvv.dispose();
    _paypalEmail.dispose();
    _pagoMovilPhone.dispose();
    _pagoMovilBank.dispose();
    _pagoMovilRef.dispose();
    _zelleAccount.dispose();
    _zelleRef.dispose();
    _transferBank.dispose();
    _transferRef.dispose();
    super.dispose();
  }

  String get _paymentDescription =>
      _method == PaymentMethod.cash ? 'Efectivo ($_cashCurrency)' : _method.label;

  String get _paymentSummaryDetail {
    switch (_method) {
      case PaymentMethod.card:
        final n = _cardNumber.text.trim();
        final last4 = n.length >= 4 ? n.substring(n.length - 4) : n;
        final brand = n.startsWith('4') ? 'Visa' : (n.startsWith('5') ? 'Mastercard' : 'Tarjeta');
        return '$brand terminada en •••• $last4 (${_cardName.text.trim()})';
      case PaymentMethod.paypal:
        return 'Cuenta: ${_paypalEmail.text.trim()}';
      case PaymentMethod.pagoMovil:
        return '${_pagoMovilBank.text.trim()} • Tel: ${_pagoMovilPhone.text.trim()} • Ref: ${_pagoMovilRef.text.trim()}';
      case PaymentMethod.zelle:
        return 'De: ${_zelleAccount.text.trim()} • Conf: ${_zelleRef.text.trim()}';
      case PaymentMethod.transfer:
        return '${_transferBank.text.trim()} • Ref: ${_transferRef.text.trim()}';
      case PaymentMethod.cash:
        final extra = _cashChangeFor.text.trim();
        return extra.isNotEmpty ? '$_cashCurrency (paga con $extra)' : _cashCurrency;
      default:
        return 'Autorización digital vía ${_method.label}';
    }
  }

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
      customerPhone: _phone.text.trim(),
      country: _country!.name,
      city: _city.text.trim(),
      address: _address.text.trim(),
      postalCode: _postal.text.trim(),
      paymentMethod: _paymentDescription,
      paymentDetails: _paymentSummaryDetail,
    );
    if (!mounted) return;
    setState(() => _completedOrder = order);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 68),
        title: const Text('¡Compra realizada!'),
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Chip(
              backgroundColor: NayColors.logoBg,
              label: Text('Pedido ${order.id}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: NayColors.dark)),
            ),
            const SizedBox(height: 12),
            Text(
              'Total pagado: ${usd(order.total)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: NayColors.primary),
            ),
            Text(
              bs(order.total, order.exchangeRate),
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Text(
              'Envío a: ${order.address}, ${order.city}, ${order.country} (CP ${order.postalCode})',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              'Gracias por tu compra en NaySport 💕',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ]),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.storefront),
            onPressed: () => Navigator.pop(ctx),
            label: const Text('Volver a la tienda'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final total = _completedOrder?.total ?? state.total;
    final rate = _completedOrder?.exchangeRate ?? state.settings.exchangeRate;

    return Scaffold(
      appBar: AppBar(title: const Text('Finalizar compra')),
      body: Column(children: [
        // Barra horizontal de pasos arriba
        _HorizontalStepperBar(
          currentStep: _step,
          onTapStep: (i) {
            if (i < _step) setState(() => _step = i);
          },
        ),
        const Divider(height: 1),
        // Contenido: formulario en el centro-izquierda y "Tu pedido" inferior a la derecha
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Zona izquierda/central para el formulario
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 28, 16, 32),
                child: Align(
                  alignment: const Alignment(-0.08, -1),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: Colors.pink.shade100),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _stepHeader(),
                            const Divider(height: 28),
                            if (_step == 0)
                              _shippingForm()
                            else if (_step == 1)
                              _paymentForm(state)
                            else
                              _confirm(state),
                            const SizedBox(height: 28),
                            Row(children: [
                              if (_step > 0)
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.arrow_back),
                                  label: const Text('Atrás'),
                                  onPressed: () => setState(() => _step--),
                                ),
                              const Spacer(),
                              FilledButton.icon(
                                icon: Icon(_step == 2 ? Icons.lock_outline : Icons.arrow_forward),
                                onPressed: _next,
                                label: Text(
                                  _step == 2
                                      ? 'Confirmar y pagar ${usd(total)} (${bs(total, rate)})'
                                      : 'Continuar',
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Columna derecha: tarjeta "Tu pedido" abajo a la derecha (inferior a la derecha)
            SizedBox(
              width: 390,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 24, 28, 24),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: SingleChildScrollView(child: _summary(state)),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _stepHeader() {
    final (icon, title, sub) = switch (_step) {
      0 => (Icons.local_shipping_outlined, 'Dirección de envío', 'Indica dónde y quién recibirá tu pedido'),
      1 => (Icons.payment_outlined, 'Método de pago', 'Elige cómo prefieres pagar tu compra'),
      _ => (Icons.verified_outlined, 'Confirmar pedido', 'Revisa todos los detalles antes de finalizar'),
    };
    return Row(children: [
      CircleAvatar(
        radius: 22,
        backgroundColor: NayColors.logoBg,
        child: Icon(icon, color: NayColors.primary),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(sub, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ]),
      ),
    ]);
  }

  Widget _shippingForm() {
    return Form(
      key: _shipForm,
      child: Column(children: [
        Row(children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<Country>(
              initialValue: _country,
              decoration: const InputDecoration(labelText: 'País', prefixIcon: Icon(Icons.public)),
              items: [
                for (final c in kCountries) DropdownMenuItem(value: c, child: Text('${c.flag}  ${c.name}')),
              ],
              onChanged: (c) => setState(() => _country = c),
              validator: (c) => c == null ? 'Selecciona tu país' : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: _phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono de contacto',
                prefixIcon: Icon(Icons.phone_outlined),
                hintText: '+58 414 0000000',
              ),
              validator: (v) =>
                  RegExp(r'^\+?[\d\s\-]{7,18}$').hasMatch(v?.trim() ?? '') ? null : 'Teléfono no válido',
            ),
          ),
        ]),
        const SizedBox(height: 16),
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
              decoration: const InputDecoration(labelText: 'Ciudad / Estado', prefixIcon: Icon(Icons.location_city)),
              validator: (v) => (v ?? '').trim().length < 2 ? 'Ingresa la ciudad' : null,
            ),
          ),
        ]),
        const SizedBox(height: 16),
        TextFormField(
          controller: _address,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Dirección exacta (calle, edificio/casa, punto de referencia)',
            prefixIcon: Icon(Icons.home_outlined),
          ),
          validator: (v) => (v ?? '').trim().length < 5 ? 'Ingresa una dirección válida' : null,
        ),
      ]),
    );
  }

  Widget _paymentForm(AppState state) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 12, runSpacing: 12, children: [
        for (final m in PaymentMethod.values)
          _MethodTile(method: m, selected: _method == m, onTap: () => setState(() => _method = m)),
      ]),
      const SizedBox(height: 22),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: NayColors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _method.color.withValues(alpha: 0.3)),
        ),
        child: Form(key: _payForm, child: _methodDetails(state)),
      ),
    ]);
  }

  Widget _methodDetails(AppState state) {
    final rate = state.settings.exchangeRate;
    final total = state.total;
    switch (_method) {
      case PaymentMethod.card:
        final numText = _cardNumber.text;
        final brand = numText.startsWith('4')
            ? 'VISA'
            : (numText.startsWith('5') ? 'MASTERCARD' : 'TARJETA');
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.credit_card, color: _method.color),
            const SizedBox(width: 8),
            Text('Datos de la tarjeta ($brand)', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            const Icon(Icons.lock, size: 16, color: Colors.green),
            const SizedBox(width: 4),
            const Text('Pago protegido', style: TextStyle(fontSize: 12, color: Colors.green)),
          ]),
          const SizedBox(height: 14),
          TextFormField(
            controller: _cardNumber,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(16)],
            decoration: InputDecoration(
              labelText: 'Número de tarjeta',
              prefixIcon: const Icon(Icons.credit_card),
              suffixText: brand,
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) => _luhn(v ?? '') ? null : 'Número de tarjeta inválido',
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _cardName,
            decoration: const InputDecoration(labelText: 'Nombre impreso en la tarjeta', prefixIcon: Icon(Icons.person_outline)),
            validator: (v) => (v ?? '').trim().length < 3 ? 'Requerido' : null,
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _cardExp,
                decoration: const InputDecoration(labelText: 'Vencimiento (MM/AA)', hintText: '12/28'),
                inputFormatters: [_ExpiryFormatter()],
                validator: _expValidator,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextFormField(
                controller: _cardCvv,
                obscureText: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                decoration: const InputDecoration(labelText: 'Código CVV'),
                validator: (v) => (v ?? '').length >= 3 ? null : 'CVV inválido',
              ),
            ),
          ]),
        ]);
      case PaymentMethod.paypal:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _InfoBox(
            'Total a autorizar en PayPal: ${usd(total)}. Al confirmar se simulará la autorización con tu cuenta.',
            color: _method.color,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _paypalEmail,
            decoration: const InputDecoration(
                labelText: 'Correo de tu cuenta PayPal', prefixIcon: Icon(Icons.email_outlined)),
            validator: (v) =>
                RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(v?.trim() ?? '') ? null : 'Correo no válido',
          ),
        ]);
      case PaymentMethod.pagoMovil:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _InfoBox(
            'Datos Pago Móvil NaySport (ejemplo):\n'
            '• Banco: Mercantil (0105)   • Teléfono: 0414-0000000   • RIF: J-00000000-0\n'
            '• Monto exacto a transferir: ${bs(total, rate)} (tasa ${rate.toStringAsFixed(2)} Bs/\$)',
            color: _method.color,
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _pagoMovilPhone,
                decoration: const InputDecoration(
                    labelText: 'Teléfono desde donde pagas',
                    prefixIcon: Icon(Icons.phone_android),
                    hintText: '04141234567'),
                validator: (v) => RegExp(r'^\d{10,13}$').hasMatch(v?.replaceAll(RegExp(r'\D'), '') ?? '')
                    ? null
                    : 'Ingresa un teléfono válido',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _pagoMovilBank,
                decoration: const InputDecoration(labelText: 'Tu banco emisor', prefixIcon: Icon(Icons.account_balance)),
                validator: (v) => (v ?? '').trim().length < 3 ? 'Ingresa tu banco' : null,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextFormField(
            controller: _pagoMovilRef,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
            decoration: const InputDecoration(
                labelText: 'Número de referencia (últimos 4 a 8 dígitos)', prefixIcon: Icon(Icons.tag)),
            validator: (v) => (v ?? '').trim().length >= 4 ? null : 'Ingresa la referencia del pago',
          ),
        ]);
      case PaymentMethod.zelle:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _InfoBox(
            'Datos Zelle NaySport (ejemplo):\n'
            '• Correo destino: pagos@naysport.com   • Monto exacto: ${usd(total)}',
            color: _method.color,
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _zelleAccount,
                decoration: const InputDecoration(
                    labelText: 'Correo o titular de tu Zelle', prefixIcon: Icon(Icons.flash_on)),
                validator: (v) => (v ?? '').trim().length < 4 ? 'Ingresa los datos de tu Zelle' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _zelleRef,
                decoration: const InputDecoration(
                    labelText: 'Código de confirmación Zelle', prefixIcon: Icon(Icons.confirmation_number_outlined)),
                validator: (v) => (v ?? '').trim().length < 4 ? 'Ingresa el código de confirmación' : null,
              ),
            ),
          ]),
        ]);
      case PaymentMethod.transfer:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _InfoBox(
            'Cuenta Bancaria NaySport (ejemplo):\n'
            '• Banco: Banesco Cuenta Corriente 0134-0000-00-0000000000\n'
            '• Monto: ${usd(total)} / ${bs(total, rate)}',
            color: _method.color,
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _transferBank,
                decoration: const InputDecoration(labelText: 'Banco origen', prefixIcon: Icon(Icons.account_balance)),
                validator: (v) => (v ?? '').trim().length < 3 ? 'Ingresa tu banco' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _transferRef,
                decoration: const InputDecoration(labelText: 'Número de referencia', prefixIcon: Icon(Icons.tag)),
                validator: (v) => (v ?? '').trim().length < 4 ? 'Ingresa la referencia' : null,
              ),
            ),
          ]),
        ]);
      case PaymentMethod.cash:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Elige en qué moneda física pagarás:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: [
            ChoiceChip(
              avatar: const Icon(Icons.attach_money, size: 18),
              label: Text('Dólares en efectivo (${usd(total)})'),
              selected: _cashCurrency.startsWith('Dólares'),
              onSelected: (_) => setState(() => _cashCurrency = 'Dólares en efectivo (\$)'),
            ),
            ChoiceChip(
              avatar: const Icon(Icons.payments_outlined, size: 18),
              label: Text('Bolívares en efectivo (${bs(total, rate)})'),
              selected: _cashCurrency.startsWith('Bolívares'),
              onSelected: (_) => setState(() => _cashCurrency = 'Bolívares en efectivo (Bs)'),
            ),
          ]),
          const SizedBox(height: 14),
          TextFormField(
            controller: _cashChangeFor,
            decoration: const InputDecoration(
              labelText: '¿Con cuánto pagas? (opcional, para llevar vuelto)',
              prefixIcon: Icon(Icons.money),
              hintText: 'Ej: Billete de \$100 o monto exacto',
            ),
          ),
          const SizedBox(height: 12),
          _InfoBox('Pagarás en efectivo al momento de recibir o retirar tu pedido.', color: _method.color),
        ]);
      default:
        return _InfoBox(
          'Al confirmar se abrirá la autorización segura de ${_method.label} por ${usd(total)}.',
          color: _method.color,
        );
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
    final items = _completedOrder?.lines
            .map((l) => '${l.qty}× ${l.productName}${l.variant.isNotEmpty ? ' (${l.variant})' : ''}')
            .toList() ??
        [
          for (final i in state.items)
            '${i.quantity}× ${i.product.name}${[
                  if (i.color != null) i.color!,
                  if (i.size != null) 'Talla ${i.size!}'
                ].isNotEmpty ? ' (${[if (i.color != null) i.color!, if (i.size != null) 'Talla ${i.size!}'].join(', ')})' : ''}',
        ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _ConfirmBlock(
        icon: Icons.person_outline,
        title: 'Contacto y envío',
        onEdit: () => setState(() => _step = 0),
        lines: [
          '${state.user?.name ?? ''} • ${state.user?.email ?? ''}',
          'Teléfono: ${_phone.text.trim()}',
          if (_country != null)
            '${_address.text.trim()}, ${_city.text.trim()}, ${_country!.flag} ${_country!.name} (CP ${_postal.text.trim()})',
        ],
      ),
      const SizedBox(height: 12),
      _ConfirmBlock(
        icon: _method.icon,
        iconColor: _method.color,
        title: 'Método de pago',
        onEdit: () => setState(() => _step = 1),
        lines: [
          _paymentDescription,
          _paymentSummaryDetail,
        ],
      ),
      const SizedBox(height: 12),
      _ConfirmBlock(
        icon: Icons.shopping_bag_outlined,
        title: 'Artículos (${items.length})',
        lines: items,
      ),
    ]);
  }

  Widget _summary(AppState state) {
    // Si la compra ya terminó, conserva los totales del pedido recién creado para que no baje a $0.00 atrás del diálogo.
    final done = _completedOrder;
    final rate = done?.exchangeRate ?? state.settings.exchangeRate;
    final sub = done?.subtotal ?? state.subtotal;
    final disc = done?.discount ?? state.discountTotal;
    final ship = done?.shipping ?? state.shipping;
    final tot = done?.total ?? state.total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.pink.shade100),
        boxShadow: [
          BoxShadow(color: Colors.pink.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.receipt_outlined, color: NayColors.primary),
          SizedBox(width: 8),
          Text('Tu pedido', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        if (done != null)
          for (final l in done.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text('${l.qty}× ${l.productName}${l.variant.isNotEmpty ? ' (${l.variant})' : ''}')),
                const SizedBox(width: 8),
                Text(usd(l.total)),
              ]),
            )
        else
          for (final i in state.items)
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
        const Divider(height: 24),
        Row(children: [const Text('Subtotal'), const Spacer(), Text(usd(sub))]),
        if (disc > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: [
              const Text('Descuentos', style: TextStyle(color: Colors.green)),
              const Spacer(),
              Text('-${usd(disc)}', style: const TextStyle(color: Colors.green)),
            ]),
          ),
        const SizedBox(height: 4),
        Row(children: [
          const Text('Envío'),
          const Spacer(),
          Text(ship == 0 ? 'GRATIS' : usd(ship), style: TextStyle(color: ship == 0 ? Colors.green : null)),
        ]),
        const Divider(height: 20),
        Row(children: [
          const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const Spacer(),
          PriceText(tot, fontSize: 18, color: NayColors.primary, align: CrossAxisAlignment.end),
        ]),
        const SizedBox(height: 6),
        Text('Tasa aplicada: ${rate.toStringAsFixed(2)} Bs/\$',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ]),
    );
  }
}

class _HorizontalStepperBar extends StatelessWidget {
  final int currentStep;
  final ValueChanged<int> onTapStep;
  const _HorizontalStepperBar({required this.currentStep, required this.onTapStep});

  @override
  Widget build(BuildContext context) {
    const labels = ['Dirección de envío', 'Método de pago', 'Confirmar'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Row(children: [
            for (var i = 0; i < labels.length; i++) ...[
              InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: i < currentStep ? () => onTapStep(i) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: i <= currentStep ? NayColors.primary : Colors.grey.shade300,
                      child: i < currentStep
                          ? const Icon(Icons.check, size: 17, color: Colors.white)
                          : Text('${i + 1}',
                              style: TextStyle(
                                color: i == currentStep ? Colors.white : Colors.black54,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              )),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontWeight: i == currentStep ? FontWeight.bold : FontWeight.w500,
                        color: i <= currentStep ? NayColors.dark : Colors.grey,
                      ),
                    ),
                  ]),
                ),
              ),
              if (i < labels.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: i < currentStep ? NayColors.primary : Colors.grey.shade300,
                  ),
                ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _ConfirmBlock extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<String> lines;
  final VoidCallback? onEdit;
  const _ConfirmBlock({
    required this.icon,
    this.iconColor = NayColors.primary,
    required this.title,
    required this.lines,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NayColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.pink.shade100),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Spacer(),
          if (onEdit != null) TextButton(onPressed: onEdit, child: const Text('Editar')),
        ]),
        const SizedBox(height: 6),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(line, style: TextStyle(color: Colors.grey.shade800)),
          ),
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
        duration: const Duration(milliseconds: 180),
        width: 295,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? method.color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? method.color : Colors.grey.shade300, width: selected ? 2 : 1),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: method.color.withValues(alpha: 0.12),
            child: Icon(method.icon, color: method.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(method.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              Text(method.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
            ]),
          ),
          if (selected) Icon(Icons.check_circle, color: method.color, size: 20),
        ]),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String text;
  final Color color;
  const _InfoBox(this.text, {this.color = Colors.blue});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
      ]),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final clipped = digits.length > 4 ? digits.substring(0, 4) : digits;
    final formatted = clipped.length > 2 ? '${clipped.substring(0, 2)}/${clipped.substring(2)}' : clipped;
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}
