import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'app_state.dart';
import 'format.dart';
import 'models.dart';
import 'win_utils.dart';

const _pdfPink = PdfColor.fromInt(0xFFF0609E);
const _pdfDark = PdfColor.fromInt(0xFF4A2338);
const _pdfLightPink = PdfColor.fromInt(0xFFFFF0F6);

class PdfExporter {
  static Future<pw.Document> _createDoc() async {
    try {
      final reg = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
      final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
      return pw.Document(theme: pw.ThemeData.withFont(base: reg, bold: bold));
    } catch (_) {
      return pw.Document();
    }
  }

  static Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final bytes = await rootBundle.load('assets/logo.png');
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _header(pw.MemoryImage? logo, String title, String subtitle) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _pdfPink, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(children: [
            if (logo != null) ...[
              pw.ClipOval(child: pw.Image(logo, width: 46, height: 46)),
              pw.SizedBox(width: 12),
            ],
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('NaySport Colecciones',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _pdfPink)),
              pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _pdfDark)),
            ]),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Emitido: ${fmtDate(DateTime.now())}', style: const pw.TextStyle(fontSize: 9)),
            if (subtitle.isNotEmpty) pw.Text(subtitle, style: const pw.TextStyle(fontSize: 9)),
          ]),
        ],
      ),
    );
  }

  /// Genera el PDF del historial de ventas.
  static Future<Uint8List> buildSalesPdf(List<Order> orders, double currentRate, {String filterLabel = ''}) async {
    final doc = await _createDoc();
    final logo = await _loadLogo();

    final totalUsd = orders.fold(0.0, (s, o) => s + o.total);
    final totalDiscount = orders.fold(0.0, (s, o) => s + o.discount);
    final totalUnits = orders.fold(0, (s, o) => s + o.units);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      header: (_) => _header(logo, 'Historial de Ventas', filterLabel),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      ),
      build: (_) => [
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: const pw.BoxDecoration(
            color: _pdfLightPink,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
            _kpi('Pedidos', '${orders.length}'),
            _kpi('Unidades vendidas', '$totalUnits'),
            _kpi('Descuentos', usd(totalDiscount)),
            _kpi('Total vendido (USD)', usd(totalUsd)),
            _kpi('Total aprox. (Bs)', bs(totalUsd, currentRate)),
          ]),
        ),
        pw.SizedBox(height: 14),
        if (orders.isEmpty)
          pw.Center(child: pw.Text('No hay ventas registradas para este filtro.'))
        else
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: _pdfPink),
            cellStyle: const pw.TextStyle(fontSize: 8.2),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFFF9FC)),
            headers: ['N°', 'Fecha / Canal', 'Cliente', 'Productos', 'Pago', 'Total USD', 'Total Bs'],
            data: [
              for (final o in orders)
                [
                  o.id,
                  '${fmtDate(o.date)}\n${o.channel}${o.cashierName.isNotEmpty && o.isPhysical ? ' (${o.cashierName})' : ''}',
                  '${o.customerName}'
                  '${o.customerDocument.isNotEmpty ? '\nCI: ${o.customerDocument}' : ''}'
                  '${o.customerEmail.isNotEmpty ? '\n${o.customerEmail}' : ''}'
                  '${o.customerPhone.isNotEmpty ? '\n${o.customerPhone}' : ''}',
                  o.lines
                      .map((l) => '${l.qty}x ${l.productName}${l.variant.isNotEmpty ? ' (${l.variant})' : ''}')
                      .join('\n'),
                  o.paymentDetails.isNotEmpty ? '${o.paymentMethod}\n${o.paymentDetails}' : o.paymentMethod,
                  usd(o.total),
                  bs(o.total, o.exchangeRate > 0 ? o.exchangeRate : currentRate),
                ],
            ],
          ),
      ],
    ));
    return doc.save();
  }

  /// Genera el PDF del inventario / stock actual.
  static Future<Uint8List> buildStockPdf(AppState state) async {
    final doc = await _createDoc();
    final logo = await _loadLogo();
    final rate = state.settings.exchangeRate;
    final totalUnits = state.products.fold(0, (s, p) => s + p.stock);
    final totalValue = state.products.fold(0.0, (s, p) => s + p.stock * p.price);
    final totalCost = state.products.fold(0.0, (s, p) => s + p.stock * p.costPrice);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      header: (_) => _header(logo, 'Reporte de Inventario y Precios', 'Tasa: ${rate.toStringAsFixed(2)} Bs/\$'),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      ),
      build: (_) => [
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: const pw.BoxDecoration(
            color: _pdfLightPink,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
            _kpi('Productos', '${state.products.length}'),
            _kpi('Unidades en stock', '$totalUnits'),
            _kpi('Costo invertido', usd(totalCost)),
            _kpi('Valor venta (USD)', usd(totalValue)),
            _kpi('Valor venta (Bs)', bs(totalValue, rate)),
          ]),
        ),
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: _pdfPink),
          cellStyle: const pw.TextStyle(fontSize: 8.5),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          headers: ['Producto', 'Categoría', 'Stock por color', 'Tallas', 'Costo \$', 'Venta \$', 'Venta Bs', 'Total', 'Estado'],
          data: [
            for (final p in state.products)
              [
                p.name,
                state.categoryName(p.categoryId),
                p.colors.isEmpty ? 'General' : p.colorStockSummary,
                p.sizes.isEmpty ? '-' : p.sizes.join(', '),
                p.costPrice > 0 ? usd(p.costPrice) : '-',
                usd(p.price),
                bs(p.price, rate),
                '${p.stock}',
                !p.active ? 'Oculto' : (p.stock <= 0 ? 'Agotado' : (p.stock <= 5 ? 'Bajo' : 'OK')),
              ],
          ],
        ),
      ],
    ));
    return doc.save();
  }

  /// Genera el PDF de compras a proveedores / entradas de mercancía.
  static Future<Uint8List> buildPurchasesPdf(List<SupplierPurchase> purchases, double rate) async {
    final doc = await _createDoc();
    final logo = await _loadLogo();
    final totalUsd = purchases.fold(0.0, (s, p) => s + p.totalCost);
    final totalUnits = purchases.fold(0, (s, p) => s + p.totalUnits);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      header: (_) => _header(logo, 'Compras y Entradas de Proveedores', 'Tasa ref: ${rate.toStringAsFixed(2)} Bs/\$'),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      ),
      build: (_) => [
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: const pw.BoxDecoration(
            color: _pdfLightPink,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
            _kpi('Entradas registradas', '${purchases.length}'),
            _kpi('Unidades ingresadas', '$totalUnits'),
            _kpi('Inversión total (USD)', usd(totalUsd)),
            _kpi('Equivalente (Bs)', bs(totalUsd, rate)),
          ]),
        ),
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: _pdfPink),
          cellStyle: const pw.TextStyle(fontSize: 8.5),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          headers: ['Compra', 'Fecha', 'Proveedor', 'Factura / Guía', 'Mercancía recibida', 'Estado', 'Total USD'],
          data: [
            for (final c in purchases)
              [
                c.id,
                fmtDate(c.date),
                c.supplierName,
                c.invoiceRef.isEmpty ? '-' : c.invoiceRef,
                c.lines
                    .map((l) => '${l.qty}x ${l.productName} (${usd(l.unitCost)} c/u)${l.note != null && l.note!.isNotEmpty ? ' [${l.note}]' : ''}')
                    .join('\n'),
                c.paid ? 'Pagada' : 'Pendiente',
                usd(c.totalCost),
              ],
          ],
        ),
      ],
    ));
    return doc.save();
  }

  /// Genera el recibo PDF de un pedido puntual (solo uso del Admin).
  static Future<Uint8List> buildReceiptPdf(Order o) async {
    final doc = await _createDoc();
    final logo = await _loadLogo();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _header(logo, 'Comprobante ${o.id} (${o.channel})', fmtDate(o.date)),
        pw.SizedBox(height: 16),
        pw.Text('Cliente: ${o.customerName}${o.customerEmail.isNotEmpty ? ' (${o.customerEmail})' : ''}'),
        if (o.customerDocument.isNotEmpty) pw.Text('Cédula: ${o.customerDocument}'),
        if (o.customerPhone.isNotEmpty) pw.Text('Teléfono: ${o.customerPhone}'),
        if (!o.isPhysical)
          pw.Text('Dirección: ${o.address}, ${o.city}, ${o.country} - CP ${o.postalCode}')
        else if (o.address.isNotEmpty && o.address != 'Retiro en tienda')
          pw.Text('Dirección: ${o.address}'),
        if (o.cashierName.isNotEmpty && o.isPhysical) pw.Text('Atendido por: ${o.cashierName}'),
        pw.Text('Método de pago: ${o.paymentMethod}${o.paymentDetails.isNotEmpty ? ' (${o.paymentDetails})' : ''}'),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
          headerDecoration: const pw.BoxDecoration(color: _pdfPink),
          cellStyle: const pw.TextStyle(fontSize: 9.5),
          headers: ['Producto', 'Variante', 'Cant.', 'Precio', 'Desc.', 'Total'],
          data: [
            for (final l in o.lines)
              [
                l.productName,
                l.variant.isEmpty ? '-' : l.variant,
                '${l.qty}',
                usd(l.unitPrice),
                l.discountPercent > 0 ? '-${l.discountPercent.toStringAsFixed(0)}%' : '-',
                usd(l.total),
              ],
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Subtotal: ${usd(o.subtotal)}'),
            if (o.discount > 0) pw.Text('Descuento: -${usd(o.discount)}'),
            pw.Text('Envío: ${o.shipping == 0 ? 'GRATIS' : usd(o.shipping)}'),
            pw.Divider(),
            pw.Text('Total USD: ${usd(o.total)}',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _pdfPink)),
            pw.Text('Total Bs: ${bs(o.total, o.exchangeRate)}',
                style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          ]),
        ),
      ]),
    ));
    return doc.save();
  }

  /// Genera el PDF de Cierre del Día (solo Admin).
  static Future<Uint8List> buildDailyClosingPdf(List<Order> dayOrders, DateTime day, double currentRate) async {
    final doc = await _createDoc();
    final logo = await _loadLogo();
    final totalUsd = dayOrders.fold(0.0, (s, o) => s + o.total);
    final totalProfit = dayOrders.fold(0.0, (s, o) => s + o.estimatedProfit);
    final physicalUsd = dayOrders.where((o) => o.isPhysical).fold(0.0, (s, o) => s + o.total);
    final onlineUsd = dayOrders.where((o) => !o.isPhysical).fold(0.0, (s, o) => s + o.total);

    final byMethod = <String, ({int count, double usdTotal})>{};
    for (final o in dayOrders) {
      final prev = byMethod[o.paymentMethod] ?? (count: 0, usdTotal: 0.0);
      byMethod[o.paymentMethod] = (count: prev.count + 1, usdTotal: prev.usdTotal + o.total);
    }

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(26),
      header: (_) => _header(logo, 'Cierre del Día — ${fmtDay(day)}', 'Tasa: ${currentRate.toStringAsFixed(2)} Bs/\$'),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      ),
      build: (_) => [
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: const pw.BoxDecoration(
            color: _pdfLightPink,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
            _kpi('Ventas del día', '${dayOrders.length}'),
            _kpi('Total USD', usd(totalUsd)),
            _kpi('Total Bs', bs(totalUsd, currentRate)),
            _kpi('Ganancia estimada', usd(totalProfit)),
          ]),
        ),
        pw.SizedBox(height: 10),
        pw.Text('Tienda Física: ${usd(physicalUsd)} (${bs(physicalUsd, currentRate)})   |   '
            'Tienda Online: ${usd(onlineUsd)} (${bs(onlineUsd, currentRate)})',
            style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 14),
        pw.Text('Desglose por método de pago', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        pw.SizedBox(height: 6),
        if (byMethod.isEmpty)
          pw.Text('Sin ventas registradas este día.')
        else
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9.5),
            headerDecoration: const pw.BoxDecoration(color: _pdfPink),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headers: ['Método de pago', 'Operaciones', 'Total USD', 'Total Bs'],
            data: [
              for (final e in byMethod.entries)
                [e.key, '${e.value.count}', usd(e.value.usdTotal), bs(e.value.usdTotal, currentRate)],
            ],
          ),
        if (dayOrders.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text('Detalle de operaciones', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
            headerDecoration: const pw.BoxDecoration(color: _pdfPink),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headers: ['N°', 'Hora', 'Canal', 'Cliente', 'Pago', 'Total \$', 'Ganancia'],
            data: [
              for (final o in dayOrders)
                [
                  o.id,
                  fmtDate(o.date).split(' ').last,
                  o.channel,
                  o.customerName,
                  o.paymentMethod,
                  usd(o.total),
                  usd(o.estimatedProfit),
                ],
            ],
          ),
        ],
      ],
    ));
    return doc.save();
  }

  static pw.Widget _kpi(String label, String value) => pw.Column(children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _pdfDark)),
      ]);

  /// Abre el diálogo "Guardar como" de Windows y guarda el PDF.
  static Future<String?> savePdf(Uint8List bytes, String defaultName) async {
    final path = await WinUtils.saveFile(defaultName, 'Documento PDF (*.pdf)|*.pdf');
    if (path == null) return null;
    await File(path).writeAsBytes(bytes);
    return path;
  }

  /// Guarda un PDF temporal y lo abre en el visor de Windows para imprimirlo.
  static Future<String> openToPrint(Uint8List bytes, String fileName) async {
    final tmp = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}NaySport');
    await tmp.create(recursive: true);
    final file = File('${tmp.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes);
    await WinUtils.open(file.path);
    return file.path;
  }
}
