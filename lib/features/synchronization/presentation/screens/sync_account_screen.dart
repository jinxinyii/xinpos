import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/app_notification.dart';
import '../../../businesses/presentation/providers/active_business_provider.dart';
import '../providers/sync_providers.dart';

class SyncAccountScreen extends ConsumerStatefulWidget {
  const SyncAccountScreen({super.key});

  @override
  ConsumerState<SyncAccountScreen> createState() => _SyncAccountScreenState();
}

class _SyncAccountScreenState extends ConsumerState<SyncAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();
  final _businessController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _isRegistering = false;
  var _busy = false;

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    _businessController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final apiUrl = Uri.tryParse(_urlController.text.trim());
    if (apiUrl == null || !apiUrl.hasScheme || apiUrl.host.isEmpty) {
      _message('Enter a valid API base URL.');
      return;
    }

    setState(() => _busy = true);
    try {
      final auth = ref.read(syncAuthServiceProvider);
      final account = _isRegistering
          ? await auth.register(
              apiBaseUrl: apiUrl,
              name: _nameController.text.trim(),
              email: _emailController.text.trim(),
              password: _passwordController.text,
              businessName: _businessController.text.trim(),
              deviceName: 'xinPOS Android device',
            )
          : await auth.login(
              apiBaseUrl: apiUrl,
              email: _emailController.text.trim(),
              password: _passwordController.text,
              deviceName: 'xinPOS Android device',
            );
      await ref
          .read(syncSettingsServiceProvider)
          .save(apiBaseUrl: apiUrl, accessToken: account.accessToken);
      if (account.businessId != null) {
        await ref
            .read(syncSettingsServiceProvider)
            .saveBusinessMapping(
              localBusinessId: ref.read(activeBusinessProvider),
              remoteBusinessId: account.businessId!,
            );
      }
      final syncResult = await ref.read(syncWorkerProvider).syncPending();
      if (!mounted) return;
      ref.invalidate(pendingSyncCountProvider);
      _message(
        syncResult.errorMessage != null
            ? 'Connected, but the initial sync stopped: ${syncResult.errorMessage}'
            : account.businessName == null
            ? 'Connected as ${account.email}. Received ${syncResult.received} changes.'
            : 'Connected to ${account.businessName}. Received ${syncResult.received} changes.',
      );
      Navigator.of(context).pop();
    } catch (error) {
      _message('Could not connect: $error');
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isRegistering ? 'Create Sync Account' : 'Sign In to Sync'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Use your own xinPOS Laravel API. Use HTTPS for any internet-accessible server.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'API Base URL',
                hintText: 'https://api.example.com/api',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            if (_isRegistering) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Your Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _businessController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Business Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value != null && value.contains('@')
                  ? null
                  : 'Enter a valid email',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: _isRegistering ? 'At least 12 characters.' : null,
                border: const OutlineInputBorder(),
              ),
              validator: (value) =>
                  value == null || value.length < (_isRegistering ? 12 : 1)
                  ? _isRegistering
                        ? 'Use at least 12 characters'
                        : 'Required'
                  : null,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(
                _busy
                    ? 'Connecting…'
                    : _isRegistering
                    ? 'Create Account'
                    : 'Sign In',
              ),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() => _isRegistering = !_isRegistering),
              child: Text(
                _isRegistering
                    ? 'I Already Have an Account'
                    : 'Create a New Account',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
