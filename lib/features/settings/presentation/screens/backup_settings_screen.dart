import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_notification.dart';
import '../../../../shared/providers/database_provider.dart';
import '../../data/services/backup_service.dart';

class BackupSettingsScreen extends ConsumerStatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  ConsumerState<BackupSettingsScreen> createState() =>
      _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends ConsumerState<BackupSettingsScreen> {
  bool _busy = false;
  String? _message;
  List<BackupRecord> _records = [];

  BackupService get _service => BackupService(ref.read(databaseProvider));

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final records = await _service.history();
    if (!mounted) return;
    setState(() => _records = records);
  }

  Future<void> _createBackup() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final record = await _service.createBackup();
      await _loadHistory();
      if (!mounted) return;
      setState(() {
        _message = 'Backup created: ${record.fileName}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = 'Backup failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
          'Restoring replaces the current xinPOS database with the selected '
          'backup. A safety backup of the current database will be created '
          'first. Continue only if you understand that newer records not '
          'included in the selected backup will no longer appear.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final safetyBackup = await _service.pickAndRestoreBackup();
      if (safetyBackup == null) return;
      ref.invalidate(databaseProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar(
          context: context,
          content: Text('Restore complete. Safety backup: $safetyBackup'),
        ),
      );
      context.go('/');
    } catch (error) {
      ref.invalidate(databaseProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar(context: context, content: Text('Restore failed: $error')),
      );
      context.go('/');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteManualBackup(BackupRecord record) async {
    if (record.automatic) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this backup?'),
        content: Text(
          'Delete ${record.fileName} from xinPOS private storage? '
          'Any exported copy in Downloads or cloud storage will remain untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _service.deleteManualBackup(record);
      await _loadHistory();
      if (!mounted) return;
      setState(() => _message = 'Manual backup deleted.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = 'Could not delete backup: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAllManualBackups() async {
    final manualCount = _records.where((record) => !record.automatic).length;
    if (manualCount == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete all manual backups?'),
        content: Text(
          'This will delete $manualCount manual backup${manualCount == 1 ? '' : 's'} '
          'from xinPOS private storage. Automatic backups and exported copies '
          'will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final deleted = await _service.deleteAllManualBackups();
      await _loadHistory();
      if (!mounted) return;
      setState(
        () => _message =
            '$deleted manual backup${deleted == 1 ? '' : 's'} deleted.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = 'Could not delete backups: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share(BackupRecord record) async {
    try {
      final saved = await _service.exportBackup(record);
      if (!mounted) return;
      setState(() {
        _message = saved
            ? 'Backup exported successfully.'
            : 'Backup export cancelled.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = 'Could not export backup: $error');
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Backup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield_outlined),
                      SizedBox(width: 10),
                      Text(
                        'Protect your business data',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Create a complete xinPOS database backup. Restore validates the backup '
                    'before replacing the current database. Automatic '
                    'backups are created once per day when you open the app. '
                    'The 10 most recent automatic backups are retained.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Backups are stored in app documents. Export a copy to save '
                    'a copy to your device storage or a connected cloud app.',
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _createBackup,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.backup_outlined),
                      label: Text(_busy ? 'Creating backup...' : 'Back Up Now'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _restoreBackup,
                      icon: const Icon(Icons.restore_rounded),
                      label: const Text('Restore from Backup'),
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(_message!),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Backup history',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              if (_records.any((record) => !record.automatic))
                TextButton.icon(
                  onPressed: _busy ? null : _deleteAllManualBackups,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Delete manual'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_records.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('No backups created yet.')),
              ),
            )
          else
            ..._records.map(
              (record) => Card(
                child: ListTile(
                  leading: Icon(
                    record.automatic
                        ? Icons.auto_mode_rounded
                        : Icons.backup_rounded,
                  ),
                  title: Text(record.fileName),
                  subtitle: Text(
                    '${record.createdAt.toLocal()}'
                    '\n${_formatSize(record.sizeBytes)} · '
                    '${record.automatic ? 'Automatic' : 'Manual'}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Save backup to device',
                        icon: const Icon(Icons.download_outlined),
                        onPressed: _busy ? null : () => _share(record),
                      ),
                      if (!record.automatic)
                        IconButton(
                          tooltip: 'Delete manual backup',
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: _busy
                              ? null
                              : () => _deleteManualBackup(record),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Important: Keep an exported copy outside this device. '
            'Uninstalling xinPOS or clearing its app storage can remove '
            'backups stored only inside the app.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
