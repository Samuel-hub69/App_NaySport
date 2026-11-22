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
