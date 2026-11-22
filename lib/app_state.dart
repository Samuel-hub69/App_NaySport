import 'package:flutter/material.dart';
import 'data.dart';
import 'db.dart';
import 'models.dart';

/// Credenciales del administrador inicial (se pueden cambiar en el panel).
const kDefaultAdminEmail = 'admin@naysport.com';
const kDefaultAdminPassword = 'Admin2026!';

/// Estado global de la app + persistencia en la base de datos local.
class AppState extends ChangeNotifier {
  List<CategoryModel> categories = [];
  List<Product> products = [];
  List<Order> orders = [];
  List<StoredUser> users = [];
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
    } else {
      categories = (data['categories'] as List).map((e) => CategoryModel.fromJson(e)).toList();
      products = (data['products'] as List).map((e) => Product.fromJson(e)).toList();
      orders = (data['orders'] as List? ?? []).map((e) => Order.fromJson(e)).toList();
      users = (data['users'] as List? ?? []).map((e) => StoredUser.fromJson(e)).toList();
      settings = Settings.fromJson(data['settings'] ?? {});
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
    loaded = true;
    await save();
  }

  Future<void> save() => LocalDb.write({
        'version': 2,
        'categories': categories.map((e) => e.toJson()).toList(),
        'products': products.map((e) => e.toJson()).toList(),
        'orders': orders.map((e) => e.toJson()).toList(),
        'users': users.map((e) => e.toJson()).toList(),
        'settings': settings.toJson(),
      });

  /// Guarda y refresca la interfaz.
  Future<void> commit() async {
    notifyListeners();
    await save();
  }

  // ---------------------------------------------------------------- catálogo
  List<Product> get activeProducts => products.where((p) => p.active).toList();

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

  // ---------------------------------------------------------------- descuentos
  /// Descuento (%) que corresponde a una cantidad.
  double discountFor(int qty) {
    double best = 0;
    for (final r in settings.discounts) {
      if (qty >= r.minQty && r.percent > best) best = r.percent;
    }
    return best;
  }

  /// Unidades de un producto en el carrito (sumando todos sus colores/tallas).
  int qtyInCart(String productId) =>
      _items.where((i) => i.product.id == productId).fold(0, (s, i) => s + i.quantity);

  double discountPercentFor(CartItem item) => discountFor(qtyInCart(item.product.id));
  double discountAmountFor(CartItem item) => item.gross * discountPercentFor(item) / 100;

  // ---------------------------------------------------------------- carrito
  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.fold(0, (s, i) => s + i.quantity);
  double get subtotal => _items.fold(0.0, (s, i) => s + i.gross);
  double get discountTotal => _items.fold(0.0, (s, i) => s + discountAmountFor(i));
  double get afterDiscount => subtotal - discountTotal;
  double get shipping =>
      _items.isEmpty ? 0 : (afterDiscount >= settings.freeShippingFrom ? 0 : settings.shippingCost);
  double get total => afterDiscount + shipping;

  int availableFor(Product p) => p.stock - qtyInCart(p.id);

  /// Agrega al carrito. Devuelve false si no hay stock suficiente.
  bool add(Product p, {String? size, String? color, int qty = 1}) {
    if (availableFor(p) < qty) return false;
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
    if (availableFor(item.product) <= 0) return false;
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

  /// Registra la venta, descuenta el stock y vacía el carrito.
  Future<Order> placeOrder({
    required String country,
    required String city,
    required String address,
    required String postalCode,
    required String paymentMethod,
  }) async {
    final order = Order(
      id: 'NS-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
      date: DateTime.now(),
      customerName: _user?.name ?? 'Invitado',
      customerEmail: _user?.email ?? '',
      country: country,
      city: city,
      address: address,
      postalCode: postalCode,
      paymentMethod: paymentMethod,
      lines: [
        for (final i in _items)
          OrderLine(
            productId: i.product.id,
            productName: i.product.name,
            size: i.size,
            color: i.color,
            qty: i.quantity,
            unitPrice: i.product.price,
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
      i.product.stock = (i.product.stock - i.quantity).clamp(0, 1 << 30);
    }
    orders.insert(0, order);
    _items.clear();
    await commit();
    return order;
  }

  // ---------------------------------------------------------------- usuarios
  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;

  StoredUser? findUser(String email) {
    final e = email.trim().toLowerCase();
    for (final u in users) {
      if (u.email.toLowerCase() == e) return u;
    }
    return null;
  }

  /// Inicia sesión con correo. Devuelve un mensaje de error o null si todo bien.
  String? loginWithEmail(String email, String password) {
    final u = findUser(email);
    if (u == null || u.passwordHash != LocalDb.hash(password)) return 'Correo o contraseña incorrectos';
    _user = AppUser(name: u.name, email: u.email, provider: 'email', isAdmin: u.isAdmin);
    notifyListeners();
    return null;
  }

  Future<String?> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    if (findUser(email) != null) return 'Ese correo ya está registrado';
    final u = StoredUser(name: name, email: email.trim(), phone: phone, passwordHash: LocalDb.hash(password));
    users.add(u);
    _user = AppUser(name: u.name, email: u.email, provider: 'email');
    await commit();
    return null;
  }

  void loginFacebook() {
    _user = const AppUser(name: 'Usuaria Facebook', email: 'usuario@facebook.com', provider: 'facebook');
    notifyListeners();
  }

  void logout() {
    _user = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------- admin
  /// Cambia precios en [percent]% (ej. 10 = +10%, -5 = -5%). Si [categoryId] es null, a todos.
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

  /// Para usar dentro de callbacks (sin suscribirse a cambios).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
