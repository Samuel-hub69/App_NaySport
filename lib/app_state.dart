import 'package:flutter/material.dart';
import 'models.dart';

/// Estado global simple (carrito + usuario) sin paquetes externos.
class AppState extends ChangeNotifier {
  final List<CartItem> _items = [];
  AppUser? _user;

  List<CartItem> get items => List.unmodifiable(_items);
  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;

  int get itemCount => _items.fold(0, (s, i) => s + i.quantity);
  double get subtotal => _items.fold(0.0, (s, i) => s + i.total);
  double get shipping => _items.isEmpty ? 0 : (subtotal >= 150 ? 0 : 9.90);
  double get total => subtotal + shipping;

  void add(Product p, {String? size}) {
    final existing = _items.where((i) => i.product.id == p.id && i.size == size);
    if (existing.isNotEmpty) {
      existing.first.quantity++;
    } else {
      _items.add(CartItem(product: p, size: size));
    }
    notifyListeners();
  }

  void increment(CartItem item) {
    item.quantity++;
    notifyListeners();
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

  void login(AppUser u) {
    _user = u;
    notifyListeners();
  }

  void logout() {
    _user = null;
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
