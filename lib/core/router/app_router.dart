import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../shared/widgets/feature_placeholder.dart';
import 'main_scaffold.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainScaffold(
          navigationShell: navigationShell,
        );
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
              builder: (context, state) => const FeaturePlaceholder(
                title: 'Products',
                description: 'Manage your products, prices and barcodes.',
                icon: Icons.inventory_2_rounded,
              ),
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
