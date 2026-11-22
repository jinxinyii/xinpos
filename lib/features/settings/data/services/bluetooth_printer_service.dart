import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../sales/domain/entities/sale_detail.dart';

class BluetoothPrinterService {
  static const _printerAddressKey = 'xinpos_receipt_printer_mac';

  Future<bool> get hasPermission =>
      PrintBluetoothThermal.isPermissionBluetoothGranted;

  Future<bool> get isBluetoothEnabled => PrintBluetoothThermal.bluetoothEnabled;

  Future<bool> get isConnected => PrintBluetoothThermal.connectionStatus;

  Future<List<BluetoothInfo?>> getPairedDevices() async {
    return PrintBluetoothThermal.pairedBluetooths;
  }

  Future<String?> getSavedPrinterAddress() async {
    final preferences = SharedPreferencesAsync();
    return preferences.getString(_printerAddressKey);
  }

  Future<bool> connect(String macAddress) async {
    final permission = await hasPermission;
    if (!permission) {
      throw StateError('Allow Nearby devices permission for xinPOS.');
    }

    final enabled = await isBluetoothEnabled;
    if (!enabled) {
      throw StateError('Turn on Bluetooth before connecting to the printer.');
    }

    final connected = await PrintBluetoothThermal.connect(
      macPrinterAddress: macAddress,
    );

    if (connected) {
      await SharedPreferencesAsync().setString(_printerAddressKey, macAddress);
    }

    return connected;
  }

  Future<bool> disconnect() async {
    final disconnected = await PrintBluetoothThermal.disconnect;
    await SharedPreferencesAsync().remove(_printerAddressKey);
    return disconnected;
  }

  Future<bool> _ensureConnected() async {
    final permission = await hasPermission;
    if (!permission) {
      throw StateError('Bluetooth permission is not granted for xinPOS.');
    }

    final enabled = await isBluetoothEnabled;
    if (!enabled) {
      throw StateError('Bluetooth is turned off. Turn it on and try again.');
    }

    if (await isConnected) return true;

    final macAddress = await getSavedPrinterAddress();
    if (macAddress == null || macAddress.isEmpty) {
      throw StateError(
        'No receipt printer is selected. Connect a printer in Settings > Printer Setup.',
      );
    }

    final connected = await PrintBluetoothThermal.connect(
      macPrinterAddress: macAddress,
    );

    if (!connected) {
      throw StateError(
        'Could not reconnect to the saved receipt printer. Open Settings > Printer Setup and reconnect.',
      );
    }

    return true;
  }

  Future<bool> _sendBytes(List<int> bytes) async {
    await _ensureConnected();

    var sent = await PrintBluetoothThermal.writeBytes(bytes);
    if (sent) return true;

    await PrintBluetoothThermal.disconnect;
    final macAddress = await getSavedPrinterAddress();
    if (macAddress == null || macAddress.isEmpty) return false;

    final reconnected = await PrintBluetoothThermal.connect(
      macPrinterAddress: macAddress,
    );
    if (!reconnected) return false;

    sent = await PrintBluetoothThermal.writeBytes(bytes);
    return sent;
  }

  Future<bool> printTestReceipt() async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final bytes = <int>[
      ...generator.reset(),
      ...generator.text(
        'xinPOS',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
      ...generator.text(
        'PRINTER TEST',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
      ...generator.hr(),
      ...generator.text('Printer: Bluetooth ESC/POS'),
      ...generator.text('Paper: 58mm'),
      ...generator.text('Connection: Bluetooth'),
      ...generator.hr(),
      ...generator.text(
        'If you can read this, printing works.',
        styles: const PosStyles(align: PosAlign.center),
      ),
      ...generator.feed(3),
    ];

    return _sendBytes(bytes);
  }

  String _printerText(String value) {
    return String.fromCharCodes(
      value.runes.map((rune) => rune >= 32 && rune <= 126 ? rune : 63),
    );
  }

  Future<bool> printSaleReceipt(SaleDetail sale) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final bytes = <int>[];
    final currency = NumberFormat.currency(
      locale: 'en_PH',
      symbol: 'PHP ',
      decimalDigits: 2,
    );

    String money(int centavos) => currency.format(centavos / 100);

    bytes.addAll(generator.reset());
    bytes.addAll(
      generator.text(
        'xinPOS',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    );
    bytes.addAll(
      generator.text(
        'SALES RECEIPT',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
    bytes.addAll(generator.hr());
    bytes.addAll(
      generator.text('Receipt: ${_printerText(sale.receiptNumber)}'),
    );
    if (sale.queueCode != null && sale.queueCode!.isNotEmpty) {
      bytes.addAll(
        generator.text(
          'QUEUE: ${_printerText(sale.queueCode!)}',
          styles: const PosStyles(bold: true, height: PosTextSize.size2),
        ),
      );
    }
    bytes.addAll(
      generator.text(DateFormat('MMM d, yyyy  h:mm a').format(sale.soldAt)),
    );
    bytes.addAll(generator.hr());
    bytes.addAll(
      generator.row([
        PosColumn(text: 'ITEM', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(
          text: 'TOTAL',
          width: 6,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]),
    );
    bytes.addAll(generator.hr());

    for (final item in sale.items) {
      bytes.addAll(
        generator.text(
          _printerText(item.productName),
          styles: const PosStyles(bold: true),
        ),
      );
      bytes.addAll(
        generator.row([
          PosColumn(
            text: '${item.quantity} x ${money(item.unitPriceCentavos)}',
            width: 7,
          ),
          PosColumn(
            text: money(item.lineTotalCentavos),
            width: 5,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );
    }

    bytes.addAll(generator.hr());
    bytes.addAll(
      generator.row([
        PosColumn(text: 'Subtotal', width: 6),
        PosColumn(
          text: money(sale.subtotalCentavos),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]),
    );
    if (sale.discountCentavos > 0) {
      bytes.addAll(
        generator.row([
          PosColumn(text: 'Discount', width: 6),
          PosColumn(
            text: '-${money(sale.discountCentavos)}',
            width: 6,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );
    }
    bytes.addAll(
      generator.row([
        PosColumn(
          text: 'TOTAL',
          width: 6,
          styles: const PosStyles(bold: true, height: PosTextSize.size2),
        ),
        PosColumn(
          text: money(sale.totalCentavos),
          width: 6,
          styles: const PosStyles(
            align: PosAlign.right,
            bold: true,
            height: PosTextSize.size2,
          ),
        ),
      ]),
    );
    bytes.addAll(generator.hr());
    bytes.addAll(
      generator.text(
        'Payment: ${sale.payment?.method.toUpperCase() ?? 'UNAVAILABLE'}',
      ),
    );
    if (sale.payment != null) {
      bytes.addAll(
        generator.text('Amount paid: ${money(sale.payment!.amountCentavos)}'),
      );
      final reference = sale.payment!.referenceNumber;
      if (reference != null && reference.isNotEmpty) {
        bytes.addAll(generator.text('Reference: ${_printerText(reference)}'));
      }
    }
    bytes.addAll(generator.hr());
    bytes.addAll(
      generator.text(
        'Thank you for your purchase!',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
    bytes.addAll(
      generator.text(
        'Please come again.',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(generator.feed(4));

    final printed = await _sendBytes(bytes);
    if (!printed) {
      throw StateError(
        'The printer did not accept the receipt. Check the paper and printer connection.',
      );
    }
    return true;
  }
}
