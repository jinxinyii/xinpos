import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../shared/providers/database_provider.dart';

final activeBusinessProvider =
    NotifierProvider<ActiveBusinessController, String>(
      ActiveBusinessController.new,
    );

class ActiveBusinessController extends Notifier<String> {
  static const _preferenceKey = 'xinpos_active_business_id';

  @override
  String build() {
    final database = ref.watch(databaseProvider);
    final preferences = SharedPreferencesAsync();
    var disposed = false;
    ref.onDispose(() => disposed = true);

    Future<void>(() async {
      final savedId = await preferences.getString(_preferenceKey);
      if (disposed || savedId == null || savedId == 'default') return;

      final business =
          await (database.select(database.businessDatasets)
                ..where((item) => item.id.equals(savedId))
                ..where((item) => item.isArchived.equals(false)))
              .getSingleOrNull();

      if (!disposed && business != null) {
        state = business.id;
      } else if (!disposed) {
        await preferences.remove(_preferenceKey);
      }
    });

    return 'default';
  }

  Future<void> setActiveBusiness(String businessId) async {
    final database = ref.read(databaseProvider);
    final business =
        await (database.select(database.businessDatasets)
              ..where((item) => item.id.equals(businessId))
              ..where((item) => item.isArchived.equals(false)))
            .getSingleOrNull();

    if (business == null) {
      throw StateError('Business is unavailable or archived.');
    }

    await SharedPreferencesAsync().setString(_preferenceKey, businessId);
    state = businessId;
  }

  Future<void> resetToDefault() async {
    await SharedPreferencesAsync().remove(_preferenceKey);
    state = 'default';
  }
}
