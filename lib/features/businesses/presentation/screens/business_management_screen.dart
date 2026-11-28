import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_notification.dart';
import '../../domain/entities/business_dataset_summary.dart';
import '../providers/active_business_provider.dart';
import '../providers/business_dataset_providers.dart';

class BusinessManagementScreen extends ConsumerWidget {
  const BusinessManagementScreen({super.key});

  Future<String?> _askName(BuildContext context, {String initial = ''}) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => _BusinessNameDialog(initial: initial),
    );
  }

  void _message(BuildContext context, String value) {
    ScaffoldMessenger.of(context)
        .showSnackBar(AppSnackBar(context: context, content: Text(value)));
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await _askName(context);
    if (name == null || !context.mounted) return;
    try {
      await ref.read(businessDatasetRepositoryProvider).create(name);
    } catch (error) {
      if (context.mounted) {
        _message(context, 'Could not create business: $error');
      }
    }
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    BusinessDatasetSummary item,
  ) async {
    if (item.isArchived) return;
    try {
      await ref
          .read(activeBusinessProvider.notifier)
          .setActiveBusiness(item.id);
      if (!context.mounted) return;
      _message(context, 'Opened "${item.name}".');
      context.go('/');
    } catch (error) {
      if (context.mounted) {
        _message(context, 'Could not open business: $error');
      }
    }
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    BusinessDatasetSummary item,
  ) async {
    final name = await _askName(context, initial: item.name);
    if (name == null || !context.mounted) return;
    try {
      await ref.read(businessDatasetRepositoryProvider).rename(item.id, name);
    } catch (error) {
      if (context.mounted) {
        _message(context, 'Could not rename business: $error');
      }
    }
  }

  Future<void> _archive(
    BuildContext context,
    WidgetRef ref,
    BusinessDatasetSummary item,
  ) async {
    final archived = !item.isArchived;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(archived ? 'Archive business?' : 'Restore business?'),
        content: Text(
          archived
              ? 'Archive "${item.name}"? Its records will be kept and you can restore it later.'
              : 'Restore "${item.name}" to the active business list?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(archived ? 'Archive' : 'Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final activeId = ref.read(activeBusinessProvider);
      if (archived && activeId == item.id) {
        await ref.read(activeBusinessProvider.notifier).resetToDefault();
      }
      await ref
          .read(businessDatasetRepositoryProvider)
          .setArchived(item.id, archived);
    } catch (error) {
      if (context.mounted) {
        _message(context, 'Could not update business: $error');
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    BusinessDatasetSummary item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) =>
          _DeleteBusinessDialog(businessName: item.name),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      if (ref.read(activeBusinessProvider) == item.id) {
        await ref.read(activeBusinessProvider.notifier).resetToDefault();
      }
      await ref.read(businessDatasetRepositoryProvider).deleteBusiness(item.id);
      if (context.mounted) {
        _message(
          context,
          '"${item.name}" and its data were permanently deleted.',
        );
      }
    } catch (error) {
      if (context.mounted) {
        _message(context, 'Could not delete business: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businesses = ref.watch(businessDatasetsProvider);
    final activeBusinessId = ref.watch(activeBusinessProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Business Management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('New business'),
      ),
      body: businesses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Could not load businesses: $error')),
        data: (items) {
          final activeItems = items.where((item) => !item.isArchived).toList();
          final archivedItems = items.where((item) => item.isArchived).toList();
          final selectedBusiness = items
              .where((item) => item.id == activeBusinessId)
              .toList();
          final activeBusinessName = selectedBusiness.isEmpty
              ? 'Default Business'
              : selectedBusiness.first.name;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Business workspace',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text('Current workspace: $activeBusinessName'),
                      const SizedBox(height: 8),
                      const Text(
                        'Open a business to work with its own products, inventory, sales, queue, expenses, and reports. Tap an available business below to switch workspaces.',
                      ),
                    ],
                  ),
                ),
              ),
              _sectionTitle(context, 'Active businesses'),
              for (final item in activeItems)
                _businessTile(context, ref, item, activeBusinessId),
              if (archivedItems.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionTitle(context, 'Archived businesses'),
                for (final item in archivedItems)
                  _businessTile(context, ref, item, activeBusinessId),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    );
  }

  Widget _businessTile(
    BuildContext context,
    WidgetRef ref,
    BusinessDatasetSummary item,
    String activeBusinessId,
  ) {
    final isDefault = item.id == 'default';
    final isActive = item.id == activeBusinessId;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            isDefault
                ? Icons.storefront_rounded
                : item.isArchived
                ? Icons.archive_outlined
                : Icons.store_rounded,
          ),
        ),
        title: Text(item.name),
        subtitle: Text(
          isDefault
              ? isActive
                    ? 'Current workspace · Original business · Protected'
                    : 'Original business · Protected · Tap to open'
              : isActive
              ? 'Current workspace'
              : item.isArchived
              ? 'Archived · Data preserved'
              : 'Tap to open this business',
        ),
        onTap: !item.isArchived && !isActive
            ? () => _open(context, ref, item)
            : null,
        trailing: isDefault
            ? const Icon(Icons.lock_outline_rounded)
            : PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'open') _open(context, ref, item);
                  if (action == 'rename') _rename(context, ref, item);
                  if (action == 'toggle') _archive(context, ref, item);
                  if (action == 'delete') _delete(context, ref, item);
                },
                itemBuilder: (context) => [
                  if (!item.isArchived && !isActive)
                    const PopupMenuItem(
                      value: 'open',
                      child: Text('Open business'),
                    ),
                  if (!item.isArchived)
                    const PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(item.isArchived ? 'Restore' : 'Archive'),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Permanently delete'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _BusinessNameDialog extends StatefulWidget {
  const _BusinessNameDialog({required this.initial});

  final String initial;

  @override
  State<_BusinessNameDialog> createState() => _BusinessNameDialogState();
}

class _BusinessNameDialogState extends State<_BusinessNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRenaming = widget.initial.isNotEmpty;

    return AlertDialog(
      title: Text(isRenaming ? 'Rename business' : 'Create business'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 80,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Business name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _DeleteBusinessDialog extends StatefulWidget {
  const _DeleteBusinessDialog({required this.businessName});

  final String businessName;

  @override
  State<_DeleteBusinessDialog> createState() => _DeleteBusinessDialogState();
}

class _DeleteBusinessDialogState extends State<_DeleteBusinessDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = _controller.text.trim() == widget.businessName;

    return AlertDialog(
      title: const Text('Permanently delete business?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This permanently deletes "${widget.businessName}" and all its products, categories, barcodes, sales, payments, queue records, inventory history, and expenses. This cannot be undone.',
          ),
          const SizedBox(height: 16),
          Text('Type "${widget.businessName}" to confirm.'),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Business name',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: matches ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          child: const Text('Delete permanently'),
        ),
      ],
    );
  }
}
