import '../entities/queue_entry.dart';
import '../entities/queue_summary.dart';
import '../entities/sale_checkout_item.dart';
import '../entities/sale_checkout_result.dart';
import '../entities/sale_detail.dart';
import '../entities/sale_summary.dart';

abstract class SaleRepository {
  Future<SaleCheckoutResult> checkout({
    required List<SaleCheckoutItem> items,
    required String paymentMethod,
    required int amountTenderedCentavos,
    String? referenceNumber,
  });

  Future<List<SaleSummary>> getSales({String search = ''});

  Future<SaleDetail?> getSaleDetails(String saleId);

  Future<List<QueueEntry>> getTodayQueue();

  Future<QueueSummary> getTodayQueueSummary();

  Future<QueueEntry?> callNextQueueEntry();

  Future<QueueEntry?> callNextReadyQueueEntry();

  Future<void> markQueueEntryReady(String queueEntryId);

  Future<void> markQueueEntryPreparing(String queueEntryId);

  Future<void> completeQueueEntry(String queueEntryId);

  Future<void> skipQueueEntry(String queueEntryId);
}
