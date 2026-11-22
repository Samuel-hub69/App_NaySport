import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:naysport/app_state.dart';
import 'package:naysport/db.dart';
import 'package:naysport/format.dart';
import 'package:naysport/main.dart';
import 'package:naysport/models.dart';
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

  test('Lógica v3: descuentos, proveedores, kardex, colores, BD local y PDFs', () async {
    final state = AppState();
    await state.load();
    expect(state.loginWithEmail(kDefaultAdminEmail, kDefaultAdminPassword), isNull);
    expect(state.isAdmin, isTrue);

    final shirt = state.products.firstWhere((p) => p.id == 'r2');
    final initialStock = shirt.stock;
    final initialPrice = shirt.price;

    // Color personalizado
    await state.addCustomColor('Turquesa', 0xFF009688);
    expect(state.allColorNames, contains('Turquesa'));

    // Proveedor y llegada de mercancía -> suma stock, actualiza costo y registra entrada en kardex
    final sup = Supplier(id: 'sup1', name: 'Textiles Caracas', phone: '0414-1234567');
    state.suppliers.add(sup);
    await state.recordSupplierPurchase(
      supplier: sup,
      invoiceRef: 'F-001',
      paid: true,
      notes: 'Lote nuevo',
      lines: [PurchaseLine(productId: shirt.id, productName: shirt.name, qty: 10, unitCost: 9.50)],
    );
    expect(shirt.stock, initialStock + 10);
    expect(shirt.costPrice, 9.50);
    expect(state.movements.first.type, 'entrada');

    // Agregar 5 camisas con color y talla -> aplica 10% de descuento
    expect(state.add(shirt, size: 'M', color: 'Rosado', qty: 5), isTrue);
    expect(state.discountTotal, closeTo(shirt.price * 5 * 0.10, 0.01));

    // Formato en dólares y bolívares + validaciones de nombre y teléfono
    expect(usd(10), '\$10.00');
    expect(bs(10, 40), 'Bs 400,00');
    expect(validateFullName('María Pérez'), isNull);
    expect(validateFullName('María 123'), isNotNull);
    expect(validatePhone('+584141234567'), isNull);
    expect(validatePhone('0414-abc'), isNotNull);

    // Ajuste masivo de precios (+10%)
    final casualCount = state.products.where((p) => p.categoryId == 'casual').length;
    final updated = await state.adjustPrices(10, categoryId: 'casual');
    expect(updated, casualCount);
    expect(shirt.price, closeTo(initialPrice * 1.10, 0.01));

    // No permitir agregar más del stock disponible
    expect(state.add(shirt, size: 'M', color: 'Negro', qty: shirt.stock + 1), isFalse);

    // Registrar pedido -> descuenta stock, guarda teléfono y movimiento salida, vacía carrito
    final order = await state.placeOrder(
      customerPhone: '+58 414 9998877',
      country: 'Venezuela',
      city: 'Caracas',
      address: 'Av. Principal',
      postalCode: '1010',
      paymentMethod: 'Pago Móvil',
      paymentDetails: 'Mercantil • Ref: 123456',
    );
    expect(shirt.stock, initialStock + 10 - 5);
    expect(state.items, isEmpty);
    expect(state.orders.length, 1);
    expect(state.movements.first.type, 'salida');

    // Recargar desde BD local y verificar persistencia completa
    final reloaded = AppState();
    await reloaded.load();
    expect(reloaded.orders.length, 1);
    expect(reloaded.orders.first.customerPhone, '+58 414 9998877');
    expect(reloaded.suppliers.length, 1);
    expect(reloaded.purchases.length, 1);
    expect(reloaded.movements.length, 2);
    expect(reloaded.settings.customColors['Turquesa'], 0xFF009688);

    // Generar los 4 PDFs y verificar cabecera %PDF-
    final salesPdf = await PdfExporter.buildSalesPdf(reloaded.orders, reloaded.settings.exchangeRate);
    final stockPdf = await PdfExporter.buildStockPdf(reloaded);
    final purchasesPdf = await PdfExporter.buildPurchasesPdf(reloaded.purchases, reloaded.settings.exchangeRate);
    final receiptPdf = await PdfExporter.buildReceiptPdf(order);
    expect(String.fromCharCodes(salesPdf.take(5)), '%PDF-');
    expect(String.fromCharCodes(stockPdf.take(5)), '%PDF-');
    expect(String.fromCharCodes(purchasesPdf.take(5)), '%PDF-');
    expect(String.fromCharCodes(receiptPdf.take(5)), '%PDF-');
  });
}
