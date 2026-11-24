import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/pos/presentation/screens/pos_screen.dart';
import '../../features/products/presentation/screens/categories_screen.dart';
import '../../features/products/presentation/screens/add_product_screen.dart';
import '../../features/products/presentation/screens/products_screen.dart';
import '../../features/products/presentation/screens/edit_product_screen.dart';
import '../../features/products/presentation/screens/product_details_screen.dart';
import '../../features/products/presentation/screens/stock_management_screen.dart';
import '../../features/products/presentation/screens/product_barcodes_screen.dart';
import '../../features/products/presentation/screens/barcode_scanner_screen.dart';
import '../../features/sales/presentation/screens/sales_history_screen.dart';
import '../../features/sales/presentation/screens/sale_details_screen.dart';
import '../../features/sales/presentation/screens/queue_management_screen.dart';
import '../../features/reports/presentation/screens/sales_reports_screen.dart';
import '../../features/expenses/presentation/screens/expenses_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/printer_settings_screen.dart';
import '../../features/settings/presentation/screens/backup_settings_screen.dart';
import '../../features/reports/presentation/screens/profit_report_screen.dart';
import 'main_scaffold.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainScaffold(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const DashboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/pos',
              builder: (context, state) => const PosScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/products',
              builder: (context, state) => const ProductsScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  builder: (context, state) => const AddProductScreen(),
                ),
                GoRoute(
                  path: 'categories',
                  builder: (context, state) => const CategoriesScreen(),
                ),
                GoRoute(
                  path: ':productId',
                  builder: (context, state) => ProductDetailsScreen(
                    productId: state.pathParameters['productId']!,
                  ),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (context, state) => EditProductScreen(
                        productId: state.pathParameters['productId']!,
                      ),
                    ),
                    GoRoute(
                      path: 'stock',
                      builder: (context, state) => StockManagementScreen(
                        productId: state.pathParameters['productId']!,
                      ),
                    ),
                    GoRoute(
                      path: 'barcodes',
                      builder: (context, state) => ProductBarcodesScreen(
                        productId: state.pathParameters['productId']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/sales',
              builder: (context, state) => const SalesHistoryScreen(),
              routes: [
                GoRoute(
                  path: 'reports',
                  builder: (context, state) => const SalesReportsScreen(),
                ),
                GoRoute(
                  path: ':saleId',
                  builder: (context, state) => SaleDetailsScreen(
                    saleId: state.pathParameters['saleId']!,
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/queue',
              builder: (context, state) => const QueueManagementScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/expenses',
              builder: (context, state) => const ExpensesScreen(),
              routes: [
                GoRoute(
                  path: 'profit',
                  builder: (context, state) => const ProfitReportScreen(),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profit',
              builder: (context, state) => const ProfitReportScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
              routes: [
                GoRoute(
                  path: 'printer',
                  builder: (context, state) => const PrinterSettingsScreen(),
                ),
                GoRoute(
                  path: 'backup',
                  builder: (context, state) => const BackupSettingsScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/scanner',
      builder: (context, state) => const BarcodeScannerScreen(),
    ),
  ],
);
