import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

class MainScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({super.key, required this.navigationShell});

  static const List<NavigationDestination> destinations = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.point_of_sale_outlined),
      selectedIcon: Icon(Icons.point_of_sale_rounded),
      label: 'POS',
    ),
    NavigationDestination(
      icon: Icon(Icons.inventory_2_outlined),
      selectedIcon: Icon(Icons.inventory_2_rounded),
      label: 'Products',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long_rounded),
      label: 'Sales',
    ),
    NavigationDestination(
      icon: Icon(Icons.confirmation_number_outlined),
      selectedIcon: Icon(Icons.confirmation_number),
      label: 'Queue',
    ),
    NavigationDestination(
      icon: Icon(Icons.money_off_csred_outlined),
      selectedIcon: Icon(Icons.money_off_csred),
      label: 'Expenses',
    ),
    NavigationDestination(
      icon: Icon(Icons.analytics_outlined),
      selectedIcon: Icon(Icons.analytics_rounded),
      label: 'Profit',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings_rounded),
      label: 'Settings',
    ),
  ];

  static const List<int> _primaryDestinationIndexes = [0, 1, 2, 4];
  static const List<int> _secondaryDestinationIndexes = [3, 5, 6, 7];

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  Future<void> _showMoreMenu(BuildContext context) async {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: false,
      backgroundColor: colors.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('More', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _secondaryDestinationIndexes.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 76,
                ),
                itemBuilder: (context, itemIndex) {
                  final destinationIndex =
                      _secondaryDestinationIndexes[itemIndex];
                  final destination = destinations[destinationIndex];
                  final isSelected =
                      navigationShell.currentIndex == destinationIndex;
                  final destinationIcon = isSelected
                      ? destination.selectedIcon
                      : destination.icon;
                  final icon = destinationIcon is Icon
                      ? destinationIcon.icon
                      : Icons.circle;

                  return Material(
                    color: isSelected
                        ? colors.secondaryContainer
                        : colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _onDestinationSelected(destinationIndex);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            Icon(
                              icon,
                              color: isSelected
                                  ? colors.onSecondaryContainer
                                  : colors.onSurfaceVariant,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                destination.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? colors.onSecondaryContainer
                                      : colors.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabletNavigation(BuildContext context, double height) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: 80,
      height: height,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: destinations.length,
        itemBuilder: (context, index) {
          final destination = destinations[index];
          final isSelected = navigationShell.currentIndex == index;
          final destinationIcon = isSelected
              ? destination.selectedIcon
              : destination.icon;
          final icon = destinationIcon is Icon
              ? destinationIcon.icon
              : Icons.circle;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Material(
              color: isSelected
                  ? colors.secondaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _onDestinationSelected(index),
                child: SizedBox(
                  height: 64,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 24,
                        color: isSelected
                            ? colors.onSecondaryContainer
                            : colors.onSurfaceVariant,
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 3),
                        Text(
                          destination.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colors.onSecondaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 800;
        final currentIndex = navigationShell.currentIndex;

        if (isTablet) {
          return Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTabletNavigation(context, constraints.maxHeight),
                const VerticalDivider(width: 1),
                Expanded(child: navigationShell),
              ],
            ),
          );
        }

        final selectedPrimaryIndex =
            _primaryDestinationIndexes.contains(currentIndex)
            ? _primaryDestinationIndexes.indexOf(currentIndex)
            : 4;

        final mobileDestinations = [
          for (final index in _primaryDestinationIndexes) destinations[index],
          NavigationDestination(
            icon: Icon(
              Icons.apps_rounded,
              color: _secondaryDestinationIndexes.contains(currentIndex)
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            selectedIcon: const Icon(Icons.apps_rounded),
            label: 'More',
          ),
        ];

        return Scaffold(
          body: navigationShell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedPrimaryIndex,
            onDestinationSelected: (index) {
              if (index == 4) {
                _showMoreMenu(context);
              } else {
                _onDestinationSelected(_primaryDestinationIndexes[index]);
              }
            },
            destinations: mobileDestinations,
          ),
        );
      },
    );
  }
}
