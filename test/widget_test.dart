import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xinpos/app.dart';
import 'package:xinpos/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:xinpos/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:xinpos/features/reports/domain/entities/sales_report.dart';
import 'package:xinpos/features/reports/presentation/providers/sales_report_providers.dart';

void main() {
  testWidgets('xinPOS dashboard loads successfully', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardDataProvider.overrideWith(
            (ref) => Stream.value(
              const DashboardData(
                totalSalesCentavos: 150000,
                transactionCount: 3,
                cashSalesCentavos: 100000,
                gcashSalesCentavos: 50000,
                recentSales: [],
              ),
            ),
          ),
          salesReportProvider.overrideWith(
            (ref, filter) => Stream.value(
              const SalesReport(
                totalRevenueCentavos: 250000,
                transactionCount: 5,
                totalItemsSold: 8,
                averageTransactionCentavos: 50000,
                dailySales: [],
                topProducts: [],
                paymentMethods: [],
                categorySales: [],
              ),
            ),
          ),
        ],
        child: const XinPosApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('xinPOS'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Total Sales'), findsOneWidget);
    expect(find.text('Transactions'), findsWidgets);
    expect(find.text('₱1,500.00'), findsOneWidget);
    expect(find.text('Sales Analytics'), findsOneWidget);
    expect(find.text('Best-Selling Products'), findsOneWidget);
    expect(find.text('Payment Breakdown'), findsOneWidget);
  });
}
