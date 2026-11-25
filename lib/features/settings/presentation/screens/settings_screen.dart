import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.print_rounded),
              title: const Text('Receipt Printer'),
              subtitle: const Text('Connect and manage your receipt printer'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/printer'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('Business Management'),
              subtitle: const Text('Create and manage business datasets'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/businesses'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Diagnostic Logs'),
              subtitle: const Text('View, export, and clear app error logs'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/logs'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Data Backup'),
              subtitle: const Text('Create and export database backups'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/backup'),
            ),
          ),
        ],
      ),
    );
  }
}
