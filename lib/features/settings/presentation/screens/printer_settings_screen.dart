import 'package:material_ui/material_ui.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../../../shared/widgets/app_notification.dart';

import '../../data/services/bluetooth_printer_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final BluetoothPrinterService _printerService = BluetoothPrinterService();
  final TextEditingController _receiptTitleController = TextEditingController();
  bool _savingReceiptTitle = false;

  List<BluetoothInfo> _devices = [];
  String? _connectedAddress;
  bool _loading = true;
  bool _busy = false;
  bool _isConnected = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDevices();
    _loadReceiptTitle();
  }

  Future<void> _loadReceiptTitle() async {
    final title = await _printerService.getReceiptTitle();
    if (!mounted) return;
    _receiptTitleController.text = title;
  }

  Future<void> _saveReceiptTitle() async {
    final title = _receiptTitleController.text.trim();
    if (title.isEmpty) {
      AppNotification.show(
        context,
        message: 'Enter a business name for the receipt',
        type: AppNotificationType.error,
      );
      return;
    }

    setState(() => _savingReceiptTitle = true);
    try {
      await _printerService.saveReceiptTitle(title);
      if (!mounted) return;
      AppNotification.show(
        context,
        message: 'Receipt title saved',
        type: AppNotificationType.success,
      );
    } catch (error) {
      if (!mounted) return;
      AppNotification.show(
        context,
        message: 'Unable to save receipt title: $error',
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _savingReceiptTitle = false);
    }
  }

  @override
  void dispose() {
    _receiptTitleController.dispose();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final permission = await _printerService.hasPermission;
      final enabled = await _printerService.isBluetoothEnabled;
      if (!mounted) return;

      if (!permission) {
        setState(() {
          _devices = [];
          _loading = false;
          _error = 'Bluetooth permission is not granted. Allow Nearby devices permission for xinPOS in Android Settings.';
        });
        return;
      }

      if (!enabled) {
        setState(() {
          _devices = [];
          _loading = false;
          _error = 'Turn on Bluetooth on your tablet, then refresh this list.';
        });
        return;
      }

      final devices = (await _printerService.getPairedDevices())
          .whereType<BluetoothInfo>()
          .toList();
      final connected = await _printerService.isConnected;
      if (!mounted) return;

      setState(() {
        _devices = devices;
        _loading = false;
        _isConnected = connected;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load paired devices: $error';
      });
    }
  }

  Future<void> _connect(BluetoothInfo device) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final connected = await _printerService.connect(device.macAdress);
      if (!mounted) return;

      setState(() {
        _busy = false;
        _connectedAddress = connected ? device.macAdress : null;
        _isConnected = connected;
        if (!connected) {
          _error =
              'Could not connect to ${device.name}. Check that the printer is powered on and nearby.';
        }
      });

      if (connected) {
        _showPosNotification('Connected to ${device.name}');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Connection failed: $error';
      });
    }
  }

  Future<void> _disconnect() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _printerService.disconnect();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _connectedAddress = null;
        _isConnected = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Unable to disconnect: $error';
      });
    }
  }

  Future<void> _printTest() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final printed = await _printerService.printTestReceipt();
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (!printed) {
          _error = 'The printer did not accept the test receipt. Check the connection and paper.';
        }
      });

      if (printed) {
        _showPosNotification('Test receipt sent to printer');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Test print failed: $error';
      });
    }
  }

  void _showPosNotification(String message) {
    AppNotification.show(context, message: message);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final connected = _isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Setup'),
        actions: [
          IconButton(
            tooltip: 'Refresh Paired Devices',
            onPressed: _busy || _loading ? null : _loadDevices,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.print_rounded,
                            color: colors.primary,
                            size: 30,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bluetooth Receipt Printer',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                Text(
                                  '58mm ESC/POS compatible',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Chip(
                            avatar: Icon(
                              connected
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              size: 16,
                              color: connected
                                  ? colors.primary
                                  : colors.onSurfaceVariant,
                            ),
                            label: Text(
                              connected ? 'Connected' : 'Not connected',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        connected
                            ? (_connectedAddress == null
                                  ? 'A printer connection is currently active.'
                                  : 'Connected device: $_connectedAddress')
                            : 'Select a paired Bluetooth receipt printer below.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      if (connected) ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _printTest,
                            icon: const Icon(Icons.receipt_long),
                            label: const Text('Print Test Receipt'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _disconnect,
                            icon: const Icon(Icons.bluetooth_disabled),
                            label: const Text('Disconnect'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Receipt Customization',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Set the business name displayed at the top of printed receipts.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _receiptTitleController,
                        maxLength: 32,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Business Name',
                          hintText: 'e.g. ETP STORE',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Powered by xinPOS will remain on every receipt.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _savingReceiptTitle
                              ? null
                              : _saveReceiptTitle,
                          icon: _savingReceiptTitle
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: const Text('Save Receipt Title'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Paired Devices',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_devices.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        const Icon(Icons.bluetooth_searching, size: 36),
                        const SizedBox(height: 8),
                        const Text('No paired Bluetooth devices found.'),
                        const SizedBox(height: 8),
                        Text(
                          'Pair your printer in Android Bluetooth settings first, then refresh.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._devices.map((device) {
                  final isCurrent = device.macAdress == _connectedAddress;
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.bluetooth),
                      title: Text(
                        device.name.isEmpty ? 'Bluetooth Printer' : device.name,
                      ),
                      subtitle: Text(device.macAdress),
                      trailing: isCurrent
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : FilledButton(
                              onPressed: _busy ? null : () => _connect(device),
                              child: const Text('Connect'),
                            ),
                    ),
                  );
                }),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: colors.onErrorContainer),
                  ),
                ),
              ],
              if (_busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
