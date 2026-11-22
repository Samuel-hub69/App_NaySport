import 'models.dart';

String _img(String tags, int lock) => 'https://loremflickr.com/600/700/$tags?lock=$lock';

const _clothSizes = ['XS', 'S', 'M', 'L', 'XL'];
const _shoeSizes = ['35', '36', '37', '38', '39', '40'];

/// Categorías iniciales (el admin puede agregar más).
List<CategoryModel> seedCategories() => [
      CategoryModel(id: 'casual', name: 'Casual', iconKey: 'casual'),
      CategoryModel(id: 'deportiva', name: 'Deportiva', iconKey: 'deportiva'),
      CategoryModel(id: 'calzado', name: 'Calzado', iconKey: 'calzado'),
      CategoryModel(id: 'prendas', name: 'Prendas', iconKey: 'prendas'),
      CategoryModel(id: 'perfumes', name: 'Perfumes', iconKey: 'perfumes'),
      CategoryModel(id: 'accesorios', name: 'Accesorios', iconKey: 'accesorios'),
    ];

/// Catálogo inicial de prueba (luego se reemplaza por las fotos reales).
List<Product> seedProducts() => [
      Product(id: 'c1', name: 'Blusa Casual Lino', description: 'Blusa fresca de lino, ideal para el día a día.', price: 29.90, categoryId: 'casual', image: _img('blouse,woman', 11), sizes: _clothSizes, colors: ['Blanco', 'Beige', 'Rosado'], stock: 25),
      Product(id: 'c2', name: 'Jean Mom Fit', description: 'Jean tiro alto de mezclilla suave.', price: 44.50, categoryId: 'casual', image: _img('jeans,woman', 12), sizes: _clothSizes, colors: ['Azul', 'Celeste', 'Negro'], stock: 18),
      Product(id: 'c3', name: 'Vestido Floral', description: 'Vestido ligero con estampado floral.', price: 39.99, categoryId: 'casual', image: _img('dress,woman', 13), sizes: _clothSizes, colors: ['Estampado', 'Lila'], stock: 12),
      Product(id: 'c4', name: 'Camiseta Oversize', description: 'Algodón 100% con corte oversize.', price: 19.90, categoryId: 'casual', image: _img('tshirt,woman', 14), sizes: _clothSizes, colors: ['Blanco', 'Negro', 'Rosado', 'Gris'], stock: 40),
      Product(id: 'd1', name: 'Leggings Pro Fit', description: 'Leggings de compresión con tela transpirable.', price: 34.90, categoryId: 'deportiva', image: _img('leggings,fitness', 21), sizes: _clothSizes, colors: ['Negro', 'Fucsia', 'Azul marino'], stock: 30),
      Product(id: 'd2', name: 'Top Deportivo', description: 'Top de alto soporte para entrenamiento.', price: 24.90, categoryId: 'deportiva', image: _img('sportsbra,fitness', 22), sizes: _clothSizes, colors: ['Negro', 'Rosado', 'Blanco'], stock: 30),
      Product(id: 'd3', name: 'Conjunto Running', description: 'Conjunto ligero para correr con secado rápido.', price: 59.90, categoryId: 'deportiva', image: _img('running,woman', 23), sizes: _clothSizes, colors: ['Lila', 'Gris'], stock: 10),
      Product(id: 'd4', name: 'Chaqueta Training', description: 'Chaqueta cortavientos para exteriores.', price: 49.90, categoryId: 'deportiva', image: _img('jacket,sport', 24), sizes: _clothSizes, colors: ['Negro', 'Verde oliva'], stock: 8),
      Product(id: 'z1', name: 'Zapatillas Air Run', description: 'Zapatillas con amortiguación para running.', price: 89.90, categoryId: 'calzado', image: _img('sneakers,women', 31), sizes: _shoeSizes, colors: ['Blanco', 'Rosado', 'Negro'], stock: 15),
      Product(id: 'z2', name: 'Tacones Elegance', description: 'Tacón de 8 cm, ideal para eventos.', price: 69.90, categoryId: 'calzado', image: _img('heels,shoes', 32), sizes: _shoeSizes, colors: ['Negro', 'Nude', 'Rojo'], stock: 9),
      Product(id: 'z3', name: 'Botines Urbanos', description: 'Botines de cuero sintético.', price: 79.90, categoryId: 'calzado', image: _img('boots,women', 33), sizes: _shoeSizes, colors: ['Negro', 'Marrón'], stock: 6),
      Product(id: 'z4', name: 'Sandalias Summer', description: 'Sandalias cómodas para verano.', price: 29.90, categoryId: 'calzado', image: _img('sandals,women', 34), sizes: _shoeSizes, colors: ['Beige', 'Dorado'], stock: 20),
      Product(id: 'p1', name: 'Abrigo Largo', description: 'Abrigo de paño, elegante y abrigador.', price: 119.90, categoryId: 'prendas', image: _img('coat,woman', 41), sizes: _clothSizes, colors: ['Beige', 'Negro', 'Gris'], stock: 5),
      Product(id: 'p2', name: 'Falda Plisada', description: 'Falda midi plisada.', price: 34.90, categoryId: 'prendas', image: _img('skirt,woman', 42), sizes: _clothSizes, colors: ['Negro', 'Vino', 'Beige'], stock: 14),
      Product(id: 'p3', name: 'Suéter de Punto', description: 'Suéter tejido de punto suave.', price: 42.90, categoryId: 'prendas', image: _img('sweater,woman', 43), sizes: _clothSizes, colors: ['Rosado', 'Blanco', 'Gris'], stock: 16),
      Product(id: 'p4', name: 'Blazer Ejecutivo', description: 'Blazer entallado para oficina.', price: 74.90, categoryId: 'prendas', image: _img('blazer,woman', 44), sizes: _clothSizes, colors: ['Negro', 'Azul marino', 'Beige'], stock: 7),
      Product(id: 'f1', name: 'Perfume Rose Gold', description: 'Fragancia floral 100 ml.', price: 64.90, categoryId: 'perfumes', image: _img('perfume', 51), stock: 12),
      Product(id: 'f2', name: 'Eau de Parfum Noir', description: 'Notas amaderadas y vainilla 80 ml.', price: 79.90, categoryId: 'perfumes', image: _img('perfume,bottle', 52), stock: 10),
      Product(id: 'f3', name: 'Body Mist Fresh', description: 'Bruma corporal cítrica 250 ml.', price: 22.90, categoryId: 'perfumes', image: _img('fragrance', 53), stock: 35),
      Product(id: 'a1', name: 'Bolso de Mano', description: 'Bolso de cuero sintético con correa.', price: 54.90, categoryId: 'accesorios', image: _img('handbag', 61), colors: ['Negro', 'Rosado', 'Beige'], stock: 11),
      Product(id: 'a2', name: 'Gafas de Sol', description: 'Protección UV400.', price: 27.90, categoryId: 'accesorios', image: _img('sunglasses', 62), colors: ['Negro', 'Marrón'], stock: 22),
      Product(id: 'a3', name: 'Collar Dorado', description: 'Collar con baño de oro.', price: 32.90, categoryId: 'accesorios', image: _img('necklace,jewelry', 63), colors: ['Dorado', 'Plateado'], stock: 4),
      Product(id: 'a4', name: 'Reloj Minimal', description: 'Reloj análogo de diseño minimalista.', price: 89.90, categoryId: 'accesorios', image: _img('watch,women', 64), colors: ['Dorado', 'Plateado', 'Negro'], stock: 9),
    ];

final List<Country> kCountries = [
  Country('Argentina', 'AR', '🇦🇷', 'Ej: C1425', RegExp(r'^[A-Za-z]?\d{4}[A-Za-z]{0,3}$')),
  Country('Bolivia', 'BO', '🇧🇴', 'Ej: 0000', RegExp(r'^\d{4,5}$')),
  Country('Chile', 'CL', '🇨🇱', 'Ej: 8320000', RegExp(r'^\d{7}$')),
  Country('Colombia', 'CO', '🇨🇴', 'Ej: 110111', RegExp(r'^\d{6}$')),
  Country('Ecuador', 'EC', '🇪🇨', 'Ej: 170150', RegExp(r'^\d{6}$')),
  Country('España', 'ES', '🇪🇸', 'Ej: 28001', RegExp(r'^\d{5}$')),
  Country('Estados Unidos', 'US', '🇺🇸', 'Ej: 90210', RegExp(r'^\d{5}(-\d{4})?$')),
  Country('México', 'MX', '🇲🇽', 'Ej: 06600', RegExp(r'^\d{5}$')),
  Country('Paraguay', 'PY', '🇵🇾', 'Ej: 001001', RegExp(r'^\d{4,6}$')),
  Country('Perú', 'PE', '🇵🇪', 'Ej: 15001', RegExp(r'^\d{5}$')),
  Country('República Dominicana', 'DO', '🇩🇴', 'Ej: 10101', RegExp(r'^\d{5}$')),
  Country('Uruguay', 'UY', '🇺🇾', 'Ej: 11000', RegExp(r'^\d{5}$')),
  Country('Venezuela', 'VE', '🇻🇪', 'Ej: 1010', RegExp(r'^\d{4}$')),
];
