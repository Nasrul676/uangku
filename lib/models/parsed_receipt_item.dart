class ParsedReceiptItem {
  String name;
  double price;
  double quantity;
  String category;

  ParsedReceiptItem({
    required this.name,
    required this.price,
    this.quantity = 1.0,
    this.category = 'Lain-lain',
  });

  @override
  String toString() => 'ParsedReceiptItem(name: $name, price: $price, quantity: $quantity, category: $category)';
}
