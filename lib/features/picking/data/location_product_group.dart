import 'picking_models.dart';

/// Agrupa as tarefas de um mesmo produto e lote dentro de uma posição física
class LocationProductItem {
  final String orderItemId;
  final String orderId;
  final String orderNumber;
  final String productId;
  final String skuCode;
  final String description;
  final String baseUnit;
  final String? batch;
  final List<ConsolidatedPickingTask> tasks;

  LocationProductItem({
    required this.orderItemId,
    required this.orderId,
    required this.orderNumber,
    required this.productId,
    required this.skuCode,
    required this.description,
    required this.baseUnit,
    this.batch,
    required this.tasks,
  });

  double get totalExpected => tasks.fold(0.0, (s, t) => s + t.quantity);
  double get totalPicked =>
      tasks.where((t) => t.isPicked).fold(0.0, (s, t) => s + t.quantity);
  double get pendingQuantity =>
      (totalExpected - totalPicked).clamp(0.0, double.infinity);
  bool get isCompleted => pendingQuantity <= 0;

  List<ConsolidatedPickingTask> get suggestedTasks =>
      tasks.where((t) => !t.isPicked).toList();
  List<ConsolidatedPickingTask> get pickedTasks =>
      tasks.where((t) => t.isPicked).toList();
}
