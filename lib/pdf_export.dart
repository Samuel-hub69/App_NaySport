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
          decoration: pw.BoxDecoration(
            color: _pdfLightPink,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
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
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFFF9FC)),
            headers: ['Pedido', 'Fecha', 'Cliente', 'Destino', 'Productos', 'Pago', 'Total USD', 'Total Bs'],
            data: [
              for (final o in orders)
                [
                  o.id,
                  fmtDate(o.date),
                  '${o.customerName}\n${o.customerEmail}',
                  '${o.city}, ${o.country}\nCP ${o.postalCode}',
                  o.lines
                      .map((l) => '${l.qty}x ${l.productName}${l.variant.isNotEmpty ? ' (${l.variant})' : ''}')
                      .join('\n'),
                  o.paymentMethod,
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

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
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
          decoration: pw.BoxDecoration(
            color: _pdfLightPink,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
            _kpi('Productos', '${state.products.length}'),
            _kpi('Unidades en stock', '$totalUnits'),
            _kpi('Valor inventario (USD)', usd(totalValue)),
            _kpi('Valor (Bs)', bs(totalValue, rate)),
          ]),
        ),
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: _pdfPink),
          cellStyle: const pw.TextStyle(fontSize: 8.5),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          headers: ['Producto', 'Categoría', 'Colores', 'Tallas', 'Precio \$', 'Precio Bs', 'Stock', 'Estado'],
          data: [
            for (final p in state.products)
              [
                p.name,
                state.categoryName(p.categoryId),
                p.colors.isEmpty ? '-' : p.colors.join(', '),
                p.sizes.isEmpty ? '-' : p.sizes.join(', '),
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

  /// Genera el recibo PDF de un pedido puntual.
  static Future<Uint8List> buildReceiptPdf(Order o) async {
    final doc = await _createDoc();
    final logo = await _loadLogo();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _header(logo, 'Comprobante de Pedido ${o.id}', fmtDate(o.date)),
        pw.SizedBox(height: 16),
        pw.Text('Cliente: ${o.customerName} (${o.customerEmail})'),
        pw.Text('Dirección: ${o.address}, ${o.city}, ${o.country} - CP ${o.postalCode}'),
        pw.Text('Método de pago: ${o.paymentMethod}'),
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
