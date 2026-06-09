class ParsedReceiptItem {
  String name;
  double price;
  double quantity;
  String unit;
  String category;
  int? pocketId;
  int? financialPlanId;

  ParsedReceiptItem({
    required this.name,
    required this.price,
    this.quantity = 1.0,
    this.unit = 'pcs',
    this.category = 'Lain-lain',
    this.pocketId,
    this.financialPlanId,
  });

  @override
  String toString() => 'ParsedReceiptItem(name: $name, price: $price, quantity: $quantity, unit: $unit, category: $category, pocketId: $pocketId, financialPlanId: $financialPlanId)';
}
