import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:naysport/app_state.dart';
import 'package:naysport/db.dart';
import 'package:naysport/format.dart';
import 'package:naysport/main.dart';
import 'package:naysport/pdf_export.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('naysport_test_');
    LocalDb.testDir = tmpDir;
  });

  tearDown(() {
    LocalDb.testDir = null;
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  testWidgets('La app arranca con el splash', (tester) async {
    await tester.pumpWidget(NaySportApp(state: AppState()));
    expect(find.text('Iniciando...'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 350));
  });

  test('Lógica de negocio: descuentos por cantidad, stock, admin, BD local y PDF', () async {
    final state = AppState();
    await state.load();
    expect(state.loginWithEmail(kDefaultAdminEmail, kDefaultAdminPassword), isNull);
    expect(state.isAdmin, isTrue);

    final shirt = state.products.firstWhere((p) => p.id == 'c4');
    final initialStock = shirt.stock;
    final initialPrice = shirt.price;

    // Agregar 5 camisas con color y talla -> aplica 10% de descuento.
    final added = state.add(shirt, size: 'M', color: 'Rosado', qty: 5);
    expect(added, isTrue);
    expect(state.discountTotal, closeTo(shirt.price * 5 * 0.10, 0.01));

    // Formato en dólares y bolívares
    expect(usd(10), '\$10.00');
    expect(bs(10, 40), 'Bs 400,00');

    // Ajuste masivo de precios (+10%)
    final updated = await state.adjustPrices(10, categoryId: 'casual');
    expect(updated, 4);
    expect(shirt.price, closeTo(initialPrice * 1.10, 0.01));

    // No permitir agregar más del stock disponible
    expect(state.add(shirt, size: 'M', color: 'Negro', qty: initialStock), isFalse);

    // Registrar pedido -> descuenta stock, guarda en BD y vacía carrito
    final order = await state.placeOrder(
      country: 'Venezuela',
      city: 'Caracas',
      address: 'Av. Principal',
      postalCode: '1010',
      paymentMethod: 'PayPal',
    );
    expect(shirt.stock, initialStock - 5);
    expect(state.items, isEmpty);
    expect(state.orders.length, 1);

    // Recargar desde BD local y verificar persistencia
    final reloaded = AppState();
    await reloaded.load();
    expect(reloaded.orders.length, 1);
    expect(reloaded.orders.first.id, order.id);
    expect(reloaded.products.firstWhere((p) => p.id == 'c4').stock, initialStock - 5);

    // Generar los 3 tipos de PDF y verificar cabecera %PDF-
    final salesPdf = await PdfExporter.buildSalesPdf(reloaded.orders, reloaded.settings.exchangeRate);
    final stockPdf = await PdfExporter.buildStockPdf(reloaded);
    final receiptPdf = await PdfExporter.buildReceiptPdf(order);
    expect(String.fromCharCodes(salesPdf.take(5)), '%PDF-');
    expect(String.fromCharCodes(stockPdf.take(5)), '%PDF-');
    expect(String.fromCharCodes(receiptPdf.take(5)), '%PDF-');
  });
}
