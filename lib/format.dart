import 'package:flutter/services.dart';

String _date2(int n) => n.toString().padLeft(2, '0');

String _thousands(double v, String sep, String dec) {
  final neg = v < 0;
  final s = v.abs().toStringAsFixed(2);
  final parts = s.split('.');
  final buf = StringBuffer();
  final intPart = parts[0];
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(sep);
    buf.write(intPart[i]);
  }
  return '${neg ? '-' : ''}$buf$dec${parts[1]}';
}

/// Dólares: $1,234.50
String usd(double v) => '\$${_thousands(v, ',', '.')}';

/// Bolívares: Bs 49.380,00
String bs(double usdValue, double rate) => 'Bs ${_thousands(usdValue * rate, '.', ',')}';

String fmtDay(DateTime d) => '${_date2(d.day)}/${_date2(d.month)}/${d.year}';
String fmtDate(DateTime d) => '${fmtDay(d)} ${_date2(d.hour)}:${_date2(d.minute)}';

/// Permite solo letras (incluyendo tildes y ñ) y espacios en nombres.
final nameInputFormatter = FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]'));

String? validateFullName(String? v) {
  final t = (v ?? '').trim();
  if (RegExp(r'\d').hasMatch(t)) return 'El nombre no puede llevar números';
  if (!RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]+$').hasMatch(t)) return 'Solo se permiten letras';
  if (t.split(RegExp(r'\s+')).length < 2) return 'Ingresa nombre y apellido';
  return null;
}

/// Permite solo números y el signo '+' únicamente al principio.
class PlusDigitsPhoneFormatter extends TextInputFormatter {
  const PlusDigitsPhoneFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    final buf = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '+' && i == 0 && buf.isEmpty) {
        buf.write(ch);
      } else if (ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57) {
        buf.write(ch);
      }
    }
    final out = buf.length > 16 ? buf.toString().substring(0, 16) : buf.toString();
    return TextEditingValue(text: out, selection: TextSelection.collapsed(offset: out.length));
  }
}

String? validatePhone(String? v) {
  final t = (v ?? '').trim();
  if (!RegExp(r'^\+?\d{7,15}$').hasMatch(t)) {
    return 'Solo números y el signo + al inicio (7 a 15 dígitos)';
  }
  return null;
}
