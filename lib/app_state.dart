import 'package:flutter/material.dart';
import 'bcv_service.dart';
import 'data.dart';
import 'db.dart';
import 'models.dart';

/// Credenciales iniciales (se pueden cambiar desde el Panel Admin).
const kDefaultAdminEmail = 'admin@naysport.com';
const kDefaultAdminPassword = 'Admin2026!';
const kDefaultCashierEmail = 'cajero@naysport.com';
const kDefaultCashierPassword = 'Cajero2026!';

/// Estado global de la app + persistencia en la base de datos local.
class AppState extends ChangeNotifier {
  List<CategoryModel> categories = [];
  List<Product> products = [];
  List<Order> orders = [];
  List<StoredUser> users = [];
  List<Supplier> suppliers = [];
  List<SupplierPurchase> purchases = [];
  List<StockMovement> movements = [];
  Settings settings = Settings();

  final List<CartItem> _items = [];
  AppUser? _user;
  bool loaded = false;

  // ---------------------------------------------------------------- carga / guardado
  Future<void> load() async {
    final data = await LocalDb.read();
    if (data == null) {
      categories = seedCategories();
      products = seedProducts();
      settings = Settings();
      orders = [];
      users = [];
      suppliers = [];
      purchases = [];
      movements = [];
    } else {
      categories = (data['categories'] as List).map((e) => CategoryModel.fromJson(e)).toList();
      products = (data['products'] as List).map((e) => Product.fromJson(e)).toList();
      orders = (data['orders'] as List? ?? []).map((e) => Order.fromJson(e)).toList();
      users = (data['users'] as List? ?? []).map((e) => StoredUser.fromJson(e)).toList();
      suppliers = (data['suppliers'] as List? ?? []).map((e) => Supplier.fromJson(e)).toList();
      purchases = (data['purchases'] as List? ?? []).map((e) => SupplierPurchase.fromJson(e)).toList();
      movements = (data['movements'] as List? ?? []).map((e) => StockMovement.fromJson(e)).toList();
      settings = Settings.fromJson(data['settings'] ?? {});

      final dbVersion = (data['version'] as num?)?.toInt() ?? 1;
      if (dbVersion < 6) {
        products.removeWhere((p) => kLegacyDummyIds.contains(p.id));
        final newSeeds = seedProducts().where((p) => p.id.startsWith('r')).toList();
        var insertAt = 0;
        for (final sp in newSeeds) {
          if (!products.any((p) => p.id == sp.id)) {
            products.insert(insertAt.clamp(0, products.length), sp);
          }
          insertAt++;
        }
      }
      if (dbVersion < 7) {
        final seedMap = {for (final s in seedProducts()) s.id: s};
        for (final p in products) {
          if (p.costPrice == 0 && p.price > 5) {
            p.costPrice = double.parse((p.price - 5).toStringAsFixed(2));
          }
          final seed = seedMap[p.id];
          if (seed != null && seed.colorStock.isNotEmpty) {
            p.colorStock = Map<String, int>.from(seed.colorStock);
          }
        }
      }
    }

    if (!users.any((u) => u.isAdmin)) {
      users.add(StoredUser(
        name: 'Administrador NaySport',
        email: kDefaultAdminEmail,
        phone: '',
        passwordHash: LocalDb.hash(kDefaultAdminPassword),
        role: 'admin',
      ));
    }
    if (!users.any((u) => u.isCashier)) {
      users.add(StoredUser(
        name: 'Cajero NaySport',
        email: kDefaultCashierEmail,
        phone: '',
        passwordHash: LocalDb.hash(kDefaultCashierPassword),
        role: 'cajero',
      ));
    }

    loaded = true;
    await save();
  }

  Future<void> save() => LocalDb.write({
        'version': 7,
        'categories': categories.map((e) => e.toJson()).toList(),
        'products': products.map((e) => e.toJson()).toList(),
        'orders': orders.map((e) => e.toJson()).toList(),
        'users': users.map((e) => e.toJson()).toList(),
        'suppliers': suppliers.map((e) => e.toJson()).toList(),
        'purchases': purchases.map((e) => e.toJson()).toList(),
        'movements': movements.map((e) => e.toJson()).toList(),
        'settings': settings.toJson(),
      });

  Future<void> commit() async {
    notifyListeners();
    await save();
  }

  // ---------------------------------------------------------------- catálogo / colores
  List<Product> get activeProducts => products.where((p) => p.active).toList();
  List<String> get allColorNames => {...kColorPalette.keys, ...settings.customColors.keys}.toList();
  int colorHexFor(String name) => settings.customColors[name] ?? kColorPalette[name] ?? 0xFFCCCCCC;

  Future<void> addCustomColor(String name, int colorValue) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    settings.customColors[clean] = colorValue;
    await commit();
  }

  CategoryModel? categoryById(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  String categoryName(String id) => categoryById(id)?.name ?? 'Sin categoría';
  IconData categoryIcon(String id) => categoryById(id)?.icon ?? Icons.sell_outlined;

  Product? productById(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  // ---------------------------------------------------------------- BCV API
  Future<bool> syncBcvRate({String? source}) async {
    final targetSource = source ?? (settings.rateSource == 'Paralelo' ? 'Paralelo' : 'BCV Oficial');
    final rates = await BcvService.fetch(timeout: const Duration(seconds: 3));
    if (rates == null) return false;
    final val = targetSource == 'Paralelo' ? (rates.paralelo ?? rates.oficial) : (rates.oficial ?? rates.paralelo);
    if (val == null || val <= 0) return false;
    settings.exchangeRate = val;
    settings.rateSource = targetSource;
    settings.lastRateUpdate = rates.fetchedAt;
    await commit();
    return true;
  }

  // ---------------------------------------------------------------- descuentos
  double discountFor(int qty) {
    double best = 0;
    for (final r in settings.discounts) {
      if (qty >= r.minQty && r.percent > best) best = r.percent;
    }
    return best;
  }

  int qtyInCart(String productId, {String? color}) => _items
      .where((i) => i.product.id == productId && (color == null || i.color == color))
      .fold(0, (s, i) => s + i.quantity);

  double discountPercentFor(CartItem item) => discountFor(qtyInCart(item.product.id));
  double discountAmountFor(CartItem item) => item.gross * discountPercentFor(item) / 100;

  // ---------------------------------------------------------------- carrito online
  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.fold(0, (s, i) => s + i.quantity);
  double get subtotal => _items.fold(0.0, (s, i) => s + i.gross);
  double get discountTotal => _items.fold(0.0, (s, i) => s + discountAmountFor(i));
  double get afterDiscount => subtotal - discountTotal;
  double get shipping =>
      _items.isEmpty ? 0 : (afterDiscount >= settings.freeShippingFrom ? 0 : settings.shippingCost);
  double get total => afterDiscount + shipping;

  int availableFor(Product p, {String? color}) {
    if (color != null && p.colors.isNotEmpty) {
      return p.stockForColor(color) - qtyInCart(p.id, color: color);
    }
    return p.stock - qtyInCart(p.id);
  }

  bool add(Product p, {String? size, String? color, int qty = 1}) {
    if (availableFor(p, color: color) < qty) return false;
    final existing = _items.where((i) => i.product.id == p.id && i.size == size && i.color == color);
    if (existing.isNotEmpty) {
      existing.first.quantity += qty;
    } else {
      _items.add(CartItem(product: p, size: size, color: color, quantity: qty));
    }
    notifyListeners();
    return true;
  }

  bool increment(CartItem item) {
    if (availableFor(item.product, color: item.color) <= 0) return false;
    item.quantity++;
    notifyListeners();
    return true;
  }

  void decrement(CartItem item) {
    item.quantity--;
    if (item.quantity <= 0) _items.remove(item);
    notifyListeners();
  }

  void remove(CartItem item) {
    _items.remove(item);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  // ---------------------------------------------------------------- inventario / movimientos
  void _logMovement(Product p, String type, int delta, String reason) {
    if (delta == 0) return;
    movements.insert(
      0,
      StockMovement(
        id: newId('mov_'),
        date: DateTime.now(),
        productId: p.id,
        productName: p.name,
        type: type,
        delta: delta,
        stockAfter: p.stock,
        reason: reason,
      ),
    );
  }

  Future<void> adjustColorStock(Product p, String? color, int newStock, {String reason = 'Ajuste manual'}) async {
    final clean = newStock < 0 ? 0 : newStock;
    final prev = p.stockForColor(color);
    final delta = clean - prev;
    if (delta == 0) return;
    p.setStockForColor(color, clean);
    final label = color != null && p.colors.isNotEmpty ? '$reason ($color)' : reason;
    _logMovement(p, delta > 0 ? 'entrada' : 'ajuste', delta, label);
    await commit();
  }

  Future<void> adjustStock(Product p, int newStock, {String reason = 'Ajuste manual'}) async {
    if (p.colors.isNotEmpty) {
      await adjustColorStock(p, p.colors.first, newStock, reason: reason);
    } else {
      await adjustColorStock(p, null, newStock, reason: reason);
    }
  }

  Future<void> deleteProduct(Product p) async {
    movements.insert(
      0,
      StockMovement(
        id: newId('mov_'),
        date: DateTime.now(),
        productId: p.id,
        productName: p.name,
        type: 'ajuste',
        delta: -p.stock,
        stockAfter: 0,
        reason: 'Producto eliminado del catálogo',
      ),
    );
    products.remove(p);
    await commit();
  }

  /// Registra una llegada de mercancía de proveedor y suma el stock automático al color indicado.
  Future<SupplierPurchase> recordSupplierPurchase({
    required Supplier supplier,
    required String invoiceRef,
    required bool paid,
    required String notes,
    required List<PurchaseLine> lines,
  }) async {
    final totalCost = lines.fold(0.0, (s, l) => s + l.total);
    final purchase = SupplierPurchase(
      id: 'CMP-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
      date: DateTime.now(),
      supplierId: supplier.id,
      supplierName: supplier.name,
      invoiceRef: invoiceRef,
      paid: paid,
      notes: notes,
      lines: lines,
      totalCost: totalCost,
    );
    for (final line in lines) {
      final p = productById(line.productId);
      if (p != null) {
        final targetColor = line.color ?? (p.colors.isNotEmpty ? p.colors.first : null);
        p.addStockForColor(targetColor, line.qty);
        if (line.unitCost > 0) p.costPrice = line.unitCost;
        _logMovement(
          p,
          'entrada',
          line.qty,
          'Proveedor: ${supplier.name}${targetColor != null ? ' ($targetColor)' : ''}${invoiceRef.isNotEmpty ? ' [Fact. $invoiceRef]' : ''}',
        );
      }
    }
    purchases.insert(0, purchase);
    await commit();
    return purchase;
  }

  /// Venta ONLINE desde el carrito del cliente.
  Future<Order> placeOrder({
    required String customerPhone,
    required String country,
    required String city,
    required String address,
    required String postalCode,
    required String paymentMethod,
    String paymentDetails = '',
  }) async {
    final order = Order(
      id: 'NS-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
      date: DateTime.now(),
      channel: 'Online',
      cashierName: 'Tienda Online',
      customerName: _user?.name ?? 'Invitado',
      customerEmail: _user?.email ?? '',
      customerPhone: customerPhone,
      country: country,
      city: city,
      address: address,
      postalCode: postalCode,
      paymentMethod: paymentMethod,
      paymentDetails: paymentDetails,
      lines: [
        for (final i in _items)
          OrderLine(
            productId: i.product.id,
            productName: i.product.name,
            size: i.size,
            color: i.color,
            qty: i.quantity,
            unitPrice: i.product.price,
            unitCost: i.product.costPrice,
            discountPercent: discountPercentFor(i),
          ),
      ],
      subtotal: subtotal,
      discount: discountTotal,
      shipping: shipping,
      total: total,
      exchangeRate: settings.exchangeRate,
    );
    for (final i in _items) {
      i.product.addStockForColor(i.color, -i.quantity);
      _logMovement(
        i.product,
        'salida',
        -i.quantity,
        'Venta online ${order.id}${i.color != null ? ' (${i.color})' : ''} - ${order.customerName}',
      );
    }
    orders.insert(0, order);
    _items.clear();
    await commit();
    return order;
  }

  /// Venta en TIENDA FÍSICA registrada desde Caja / Ventas.
  /// El descuento por cantidad aplica sumando el total de artículos de la compra (ej. 3 zapatos distintos -> -5%).
  Future<Order> placePhysicalSale({
    required List<CartItem> saleItems,
    required String customerName,
    String customerDocument = '',
    String customerPhone = '',
    required String paymentMethod,
    String paymentDetails = '',
  }) async {
    final totalUnits = saleItems.fold(0, (s, i) => s + i.quantity);
    final pct = discountFor(totalUnits);
    final sub = saleItems.fold(0.0, (s, i) => s + i.gross);
    final disc = sub * pct / 100;
    final tot = sub - disc;

    final order = Order(
      id: 'CJ-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
      date: DateTime.now(),
      channel: 'Tienda física',
      cashierName: _user?.name ?? 'Cajero',
      customerName: customerName.trim().isEmpty ? 'Cliente de mostrador' : customerName.trim(),
      customerEmail: '',
      customerPhone: customerPhone.trim(),
      customerDocument: customerDocument.trim(),
      country: 'Tienda física',
      city: 'Mostrador',
      address: 'Retiro en tienda',
      postalCode: '-',
      paymentMethod: paymentMethod,
      paymentDetails: paymentDetails,
      lines: [
        for (final i in saleItems)
          OrderLine(
            productId: i.product.id,
            productName: i.product.name,
            size: i.size,
            color: i.color,
            qty: i.quantity,
            unitPrice: i.product.price,
            unitCost: i.product.costPrice,
            discountPercent: pct,
          ),
      ],
      subtotal: sub,
      discount: disc,
      shipping: 0,
      total: tot,
      exchangeRate: settings.exchangeRate,
    );

    for (final i in saleItems) {
      i.product.addStockForColor(i.color, -i.quantity);
      _logMovement(
        i.product,
        'salida',
        -i.quantity,
        'Venta en tienda ${order.id}${i.color != null ? ' (${i.color})' : ''} - ${order.customerName}',
      );
    }
    orders.insert(0, order);
    await commit();
    return order;
  }

  List<Order> ordersForDay(DateTime day, {String? channel, String? cashierName}) => orders.where((o) {
        final sameDay = o.date.year == day.year && o.date.month == day.month && o.date.day == day.day;
        if (!sameDay) return false;
        if (channel != null && o.channel != channel) return false;
        if (cashierName != null && o.cashierName != cashierName) return false;
        return true;
      }).toList();

  // ---------------------------------------------------------------- usuarios
  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isCashier => _user?.isCashier ?? false;
  bool get isStaff => _user?.isStaff ?? false;

  StoredUser? findUser(String email) {
    final e = email.trim().toLowerCase();
    for (final u in users) {
      if (u.email.toLowerCase() == e) return u;
    }
    return null;
  }

  String? loginWithEmail(String email, String password) {
    final u = findUser(email);
    if (u == null || u.passwordHash != LocalDb.hash(password)) return 'Correo o contraseña incorrectos';
    if (!u.active) return 'Esta cuenta fue desactivada por el administrador';
    _user = AppUser(name: u.name, email: u.email, phone: u.phone, role: u.role);
    notifyListeners();
    return null;
  }

  Future<String?> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String role = 'cliente',
  }) async {
    if (findUser(email) != null) return 'Ese correo ya está registrado';
    final u = StoredUser(
      name: name,
      email: email.trim(),
      phone: phone,
      passwordHash: LocalDb.hash(password),
      role: role,
    );
    users.add(u);
    if (role == 'cliente') {
      _user = AppUser(name: u.name, email: u.email, phone: u.phone, role: u.role);
    }
    await commit();
    return null;
  }

  void logout() {
    _user = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------- admin
  Future<int> adjustPrices(double percent, {String? categoryId}) async {
    var n = 0;
    for (final p in products) {
      if (categoryId == null || p.categoryId == categoryId) {
        p.price = double.parse((p.price * (1 + percent / 100)).toStringAsFixed(2));
        n++;
      }
    }
    await commit();
    return n;
  }

  Future<void> clearOrders() async {
    orders.clear();
    await commit();
  }

  Future<void> clearMovements() async {
    movements.clear();
    await commit();
  }

  Future<void> resetCatalog() async {
    categories = seedCategories();
    products = seedProducts();
    _items.clear();
    await commit();
  }

  Future<void> changeAdminPassword(String newPassword) async {
    final admin = users.firstWhere((u) => u.email.toLowerCase() == _user?.email.toLowerCase(),
        orElse: () => users.firstWhere((u) => u.isAdmin));
    admin.passwordHash = LocalDb.hash(newPassword);
    await commit();
  }

  String newId(String prefix) => '$prefix${DateTime.now().microsecondsSinceEpoch}';
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
