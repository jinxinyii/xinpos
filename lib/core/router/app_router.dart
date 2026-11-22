import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/products/presentation/screens/categories_screen.dart';
import '../../features/products/presentation/screens/add_product_screen.dart';
import '../../features/products/presentation/screens/products_screen.dart';
import '../../features/products/presentation/screens/edit_product_screen.dart';
import '../../features/products/presentation/screens/product_details_screen.dart';
import '../../features/products/presentation/screens/stock_management_screen.dart';
import '../../features/products/presentation/screens/product_barcodes_screen.dart';
import '../../shared/widgets/feature_placeholder.dart';
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
              builder: (context, state) => const FeaturePlaceholder(
                title: 'Point of Sale',
                description: 'Process customer purchases and payments.',
                icon: Icons.point_of_sale_rounded,
              ),
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
              builder: (context, state) => const FeaturePlaceholder(
                title: 'Sales History',
                description: 'Review your transactions and sales records.',
                icon: Icons.receipt_long_rounded,
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const FeaturePlaceholder(
                title: 'Settings',
                description: 'Manage your business and application settings.',
                icon: Icons.settings_rounded,
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);
