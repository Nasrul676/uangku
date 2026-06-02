class ParsedReceiptItem {
  String name;
  double price;
  double quantity;

  ParsedReceiptItem({
    required this.name,
    required this.price,
    this.quantity = 1.0,
  });

  @override
  String toString() => 'ParsedReceiptItem(name: $name, price: $price, quantity: $quantity)';
}
