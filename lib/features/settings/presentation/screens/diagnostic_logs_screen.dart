import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/app_notification.dart';
import '../../../../core/logging/app_logger.dart';

class DiagnosticLogsScreen extends StatefulWidget {
  const DiagnosticLogsScreen({super.key});

  @override
  State<DiagnosticLogsScreen> createState() => _DiagnosticLogsScreenState();
}

class _DiagnosticLogsScreenState extends State<DiagnosticLogsScreen> {
  Future<String> _logs = AppLogger.instance.readLogs();
  bool _busy = false;

  void _refresh() {
    setState(() {
      _logs = AppLogger.instance.readLogs();
    });
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final exported = await AppLogger.instance.exportLogs();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar(
          context: context,
          content: Text(
            exported ? 'Diagnostic logs exported.' : 'Export cancelled.',
          ),
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.instance.error(
        'Could not export diagnostic logs',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar(
          context: context,
          content: const Text('Could not export diagnostic logs.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear diagnostic logs?'),
        content: const Text(
          'This deletes saved diagnostic logs only. Your products, sales, and database will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear logs'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AppLogger.instance.clearLogs();
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostic Logs'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Export logs',
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.ios_share),
          ),
          IconButton(
            tooltip: 'Clear logs',
            onPressed: _busy ? null : _clear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: _logs,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Unable to read logs: ${snapshot.error}'),
              ),
            );
          }
          final content = snapshot.data ?? 'No logs available.';
          return SelectionArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                content.isEmpty ? 'No diagnostic events recorded.' : content,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
