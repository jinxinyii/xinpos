import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/app_notification.dart';
import '../providers/sync_providers.dart';

class SyncSettingsScreen extends ConsumerStatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  ConsumerState<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends ConsumerState<SyncSettingsScreen> {
  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();
  var _loading = true;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await ref.read(syncSettingsServiceProvider).read();
    if (!mounted) return;
    _urlController.text = settings?.apiBaseUrl.toString() ?? '';
    _tokenController.text = settings?.accessToken ?? '';
    setState(() => _loading = false);
  }

  Future<bool> _save() async {
    final uri = Uri.tryParse(_urlController.text.trim());
    if (uri == null) {
      _message('Enter a valid API URL.');
      return false;
    }

    try {
      await ref
          .read(syncSettingsServiceProvider)
          .save(apiBaseUrl: uri, accessToken: _tokenController.text);
      return true;
    } catch (error) {
      _message('Could not save sync settings: $error');
      return false;
    }
  }

  Future<void> _syncNow() async {
    setState(() => _busy = true);
    try {
      if (!await _save()) return;
      final result = await ref.read(syncWorkerProvider).syncPending();
      ref.invalidate(pendingSyncCountProvider);
      _message(
        result.failed > 0
            ? 'Synced ${result.sent}; ${result.failed} changes will retry later.'
            : result.sent == 0
            ? 'No pending changes to sync.'
            : 'Synced ${result.sent} changes.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(AppSnackBar(context: context, content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingSyncCountProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sync Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Connect xinPOS to your Laravel API. Use a secure HTTPS URL in production.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'API Base URL',
                    hintText: 'https://api.example.com/api',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _tokenController,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Access Token',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                pending.when(
                  data: (count) => Text('$count pending local changes'),
                  loading: () => const Text('Checking pending changes…'),
                  error: (_, _) =>
                      const Text('Could not read pending changes.'),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => context.push('/settings/sync/account'),
                  icon: const Icon(Icons.account_circle_outlined),
                  label: const Text('Sign In or Create Sync Account'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _syncNow,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: Text(_busy ? 'Syncing…' : 'Sync now'),
                ),
              ],
            ),
    );
  }
}
