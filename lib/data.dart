import 'models.dart';

String _img(String tags, int lock) =>
    'https://loremflickr.com/600/700/$tags?lock=$lock';

const _clothSizes = ['XS', 'S', 'M', 'L', 'XL'];
const _shoeSizes = ['35', '36', '37', '38', '39', '40'];

final List<Product> kProducts = [
  // Casual
  Product(id: 'c1', name: 'Blusa Casual Lino', description: 'Blusa fresca de lino, ideal para el día a día.', price: 29.90, category: Category.casual, imageUrl: _img('blouse,woman', 11), sizes: _clothSizes),
  Product(id: 'c2', name: 'Jean Mom Fit', description: 'Jean tiro alto de mezclilla suave.', price: 44.50, category: Category.casual, imageUrl: _img('jeans,woman', 12), sizes: _clothSizes),
  Product(id: 'c3', name: 'Vestido Floral', description: 'Vestido ligero con estampado floral.', price: 39.99, category: Category.casual, imageUrl: _img('dress,woman', 13), sizes: _clothSizes),
  Product(id: 'c4', name: 'Camiseta Oversize', description: 'Algodón 100% con corte oversize.', price: 19.90, category: Category.casual, imageUrl: _img('tshirt,woman', 14), sizes: _clothSizes),
  // Deportiva
  Product(id: 'd1', name: 'Leggings Pro Fit', description: 'Leggings de compresión con tela transpirable.', price: 34.90, category: Category.deportiva, imageUrl: _img('leggings,fitness', 21), sizes: _clothSizes),
  Product(id: 'd2', name: 'Top Deportivo', description: 'Top de alto soporte para entrenamiento.', price: 24.90, category: Category.deportiva, imageUrl: _img('sportsbra,fitness', 22), sizes: _clothSizes),
  Product(id: 'd3', name: 'Conjunto Running', description: 'Conjunto ligero para correr con secado rápido.', price: 59.90, category: Category.deportiva, imageUrl: _img('running,woman', 23), sizes: _clothSizes),
  Product(id: 'd4', name: 'Chaqueta Training', description: 'Chaqueta cortavientos para exteriores.', price: 49.90, category: Category.deportiva, imageUrl: _img('jacket,sport', 24), sizes: _clothSizes),
  // Calzado
  Product(id: 'z1', name: 'Zapatillas Air Run', description: 'Zapatillas con amortiguación para running.', price: 89.90, category: Category.calzado, imageUrl: _img('sneakers,women', 31), sizes: _shoeSizes),
  Product(id: 'z2', name: 'Tacones Elegance', description: 'Tacón de 8 cm, ideal para eventos.', price: 69.90, category: Category.calzado, imageUrl: _img('heels,shoes', 32), sizes: _shoeSizes),
  Product(id: 'z3', name: 'Botines Urbanos', description: 'Botines de cuero sintético.', price: 79.90, category: Category.calzado, imageUrl: _img('boots,women', 33), sizes: _shoeSizes),
  Product(id: 'z4', name: 'Sandalias Summer', description: 'Sandalias cómodas para verano.', price: 29.90, category: Category.calzado, imageUrl: _img('sandals,women', 34), sizes: _shoeSizes),
  // Prendas
  Product(id: 'p1', name: 'Abrigo Largo', description: 'Abrigo de paño, elegante y abrigador.', price: 119.90, category: Category.prendas, imageUrl: _img('coat,woman', 41), sizes: _clothSizes),
  Product(id: 'p2', name: 'Falda Plisada', description: 'Falda midi plisada.', price: 34.90, category: Category.prendas, imageUrl: _img('skirt,woman', 42), sizes: _clothSizes),
  Product(id: 'p3', name: 'Suéter de Punto', description: 'Suéter tejido de punto suave.', price: 42.90, category: Category.prendas, imageUrl: _img('sweater,woman', 43), sizes: _clothSizes),
  Product(id: 'p4', name: 'Blazer Ejecutivo', description: 'Blazer entallado para oficina.', price: 74.90, category: Category.prendas, imageUrl: _img('blazer,woman', 44), sizes: _clothSizes),
  // Perfumes
  Product(id: 'f1', name: 'Perfume Rose Gold', description: 'Fragancia floral 100 ml.', price: 64.90, category: Category.perfumes, imageUrl: _img('perfume', 51)),
  Product(id: 'f2', name: 'Eau de Parfum Noir', description: 'Notas amaderadas y vainilla 80 ml.', price: 79.90, category: Category.perfumes, imageUrl: _img('perfume,bottle', 52)),
  Product(id: 'f3', name: 'Body Mist Fresh', description: 'Bruma corporal cítrica 250 ml.', price: 22.90, category: Category.perfumes, imageUrl: _img('fragrance', 53)),
  // Accesorios
  Product(id: 'a1', name: 'Bolso de Mano', description: 'Bolso de cuero sintético con correa.', price: 54.90, category: Category.accesorios, imageUrl: _img('handbag', 61)),
  Product(id: 'a2', name: 'Gafas de Sol', description: 'Protección UV400.', price: 27.90, category: Category.accesorios, imageUrl: _img('sunglasses', 62)),
  Product(id: 'a3', name: 'Collar Dorado', description: 'Collar con baño de oro.', price: 32.90, category: Category.accesorios, imageUrl: _img('necklace,jewelry', 63)),
  Product(id: 'a4', name: 'Reloj Minimal', description: 'Reloj análogo de diseño minimalista.', price: 89.90, category: Category.accesorios, imageUrl: _img('watch,women', 64)),
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
