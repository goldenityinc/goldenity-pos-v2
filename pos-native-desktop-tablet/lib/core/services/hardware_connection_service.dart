import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:image/image.dart' as img;

enum ConnectionType { bluetooth, usb, network, none }

enum PrinterSlot {
  defaultPrinter,
  kitchen,
  cashier,
}

String printerSlotStoragePrefix(PrinterSlot slot) {
  switch (slot) {
    case PrinterSlot.defaultPrinter:
      return 'hardware_';
    case PrinterSlot.kitchen:
      return 'kitchen_printer_';
    case PrinterSlot.cashier:
      return 'cashier_printer_';
  }
}

String printerSlotLabel(PrinterSlot slot) {
  switch (slot) {
    case PrinterSlot.defaultPrinter:
      return 'Default (Semua Kebutuhan)';
    case PrinterSlot.kitchen:
      return 'Printer Dapur (Kitchen Checker)';
    case PrinterSlot.cashier:
      return 'Printer Kasir (Struk Pembayaran)';
  }
}

List<PrinterSlot> allPrinterSlots = const [
  PrinterSlot.defaultPrinter,
  PrinterSlot.kitchen,
  PrinterSlot.cashier,
];

ConnectionType parseConnectionType(String? rawValue) {
  switch ((rawValue ?? '').trim().toLowerCase()) {
    case 'bluetooth':
      return ConnectionType.bluetooth;
    case 'usb':
      return ConnectionType.usb;
    case 'network':
      return ConnectionType.network;
    default:
      return ConnectionType.none;
  }
}

String connectionTypeStorageValue(ConnectionType type) {
  return type.name;
}

String connectionTypeLabel(ConnectionType type) {
  switch (type) {
    case ConnectionType.bluetooth:
      return 'Bluetooth';
    case ConnectionType.usb:
      return 'USB';
    case ConnectionType.network:
      return 'Wi-Fi / Network';
    case ConnectionType.none:
      return 'Tidak digunakan';
  }
}

class HardwareDeviceInfo {
  const HardwareDeviceInfo({
    required this.name,
    required this.address,
    required this.connectionType,
    this.vendorId,
    this.productId,
    this.isBle = false,
  });

  final String name;
  final String address;
  final ConnectionType connectionType;
  final String? vendorId;
  final String? productId;
  final bool isBle;

  String get selectionKey => [
    connectionType.name,
    name,
    address,
    vendorId ?? '',
    productId ?? '',
    isBle ? '1' : '0',
  ].join('|');
}

class HardwareConnectionConfig {
  const HardwareConnectionConfig({
    required this.connectionType,
    this.deviceName = '',
    this.deviceAddress = '',
    this.vendorId = '',
    this.productId = '',
    this.networkIp = '',
    this.networkPort = 9100,
    this.isBle = false,
  });

  final ConnectionType connectionType;
  final String deviceName;
  final String deviceAddress;
  final String vendorId;
  final String productId;
  final String networkIp;
  final int networkPort;
  final bool isBle;

  bool get hasBluetoothTarget =>
      connectionType == ConnectionType.bluetooth && deviceAddress.isNotEmpty;

  bool get hasUsbTarget =>
      connectionType == ConnectionType.usb &&
          (
              (deviceName.isNotEmpty && vendorId.isNotEmpty && productId.isNotEmpty) ||
                  deviceAddress.isNotEmpty ||
                  deviceName.isNotEmpty);

  bool get hasNetworkTarget =>
      connectionType == ConnectionType.network && networkIp.isNotEmpty;

  bool get isConfigured {
    switch (connectionType) {
      case ConnectionType.bluetooth:
        return hasBluetoothTarget;
      case ConnectionType.usb:
        return hasUsbTarget;
      case ConnectionType.network:
        return hasNetworkTarget;
      case ConnectionType.none:
        return false;
    }
  }

  Map<String, dynamic> toLocalSettingsMap() {
    return {
      'hardware_connection_type': connectionTypeStorageValue(connectionType),
      'hardware_device_name': deviceName,
      'hardware_device_address': deviceAddress,
      'hardware_vendor_id': vendorId,
      'hardware_product_id': productId,
      'hardware_network_ip': networkIp,
      'hardware_network_port': networkPort,
      'hardware_is_ble': isBle,
    };
  }

  Map<String, dynamic> toLocalSettingsMapForSlot(
      PrinterSlot slot, {
        bool mirrorToDefault = false,
      }) {
    final prefix = printerSlotStoragePrefix(slot);
    final map = <String, dynamic>{
      '${prefix}connection_type': connectionTypeStorageValue(connectionType),
      '${prefix}device_name': deviceName,
      '${prefix}device_address': deviceAddress,
      '${prefix}vendor_id': vendorId,
      '${prefix}product_id': productId,
      '${prefix}network_ip': networkIp,
      '${prefix}network_port': networkPort,
      '${prefix}is_ble': isBle,
    };
    if (mirrorToDefault && slot != PrinterSlot.defaultPrinter) {
      map.addAll(toLocalSettingsMap());
    }
    return map;
  }

  factory HardwareConnectionConfig.fromSettings(Map<String, dynamic> settings) {
    return HardwareConnectionConfig(
      connectionType: parseConnectionType(
        settings['hardware_connection_type']?.toString(),
      ),
      deviceName: (settings['hardware_device_name'] ?? '').toString(),
      deviceAddress: (settings['hardware_device_address'] ?? '').toString(),
      vendorId: (settings['hardware_vendor_id'] ?? '').toString(),
      productId: (settings['hardware_product_id'] ?? '').toString(),
      networkIp: (settings['hardware_network_ip'] ?? '').toString(),
      networkPort:
          int.tryParse(
            (settings['hardware_network_port'] ?? 9100).toString(),
          ) ??
              9100,
      isBle: (settings['hardware_is_ble'] ?? false) == true,
    );
  }

  factory HardwareConnectionConfig.fromSettingsForSlot(
      Map<String, dynamic> settings,
      PrinterSlot slot,
      ) {
    if (slot == PrinterSlot.defaultPrinter) {
      return HardwareConnectionConfig.fromSettings(settings);
    }
    final prefix = printerSlotStoragePrefix(slot);
    final slotType = parseConnectionType(
      settings['${prefix}connection_type']?.toString(),
    );
    if (slotType == ConnectionType.none) {
      return HardwareConnectionConfig.fromSettings(settings);
    }
    return HardwareConnectionConfig(
      connectionType: slotType,
      deviceName: (settings['${prefix}device_name'] ?? '').toString(),
      deviceAddress: (settings['${prefix}device_address'] ?? '').toString(),
      vendorId: (settings['${prefix}vendor_id'] ?? '').toString(),
      productId: (settings['${prefix}product_id'] ?? '').toString(),
      networkIp: (settings['${prefix}network_ip'] ?? '').toString(),
      networkPort:
          int.tryParse(
            (settings['${prefix}network_port'] ?? 9100).toString(),
          ) ??
              9100,
      isBle: (settings['${prefix}is_ble'] ?? false) == true,
    );
  }

  factory HardwareConnectionConfig.fromDevice(HardwareDeviceInfo device) {
    return HardwareConnectionConfig(
      connectionType: device.connectionType,
      deviceName: device.name,
      deviceAddress: device.address,
      vendorId: device.vendorId ?? '',
      productId: device.productId ?? '',
      isBle: device.isBle,
    );
  }

  HardwareConnectionConfig copyWith({
    ConnectionType? connectionType,
    String? deviceName,
    String? deviceAddress,
    String? vendorId,
    String? productId,
    String? networkIp,
    int? networkPort,
    bool? isBle,
  }) {
    return HardwareConnectionConfig(
      connectionType: connectionType ?? this.connectionType,
      deviceName: deviceName ?? this.deviceName,
      deviceAddress: deviceAddress ?? this.deviceAddress,
      vendorId: vendorId ?? this.vendorId,
      productId: productId ?? this.productId,
      networkIp: networkIp ?? this.networkIp,
      networkPort: networkPort ?? this.networkPort,
      isBle: isBle ?? this.isBle,
    );
  }
}

class HardwareReceiptLineItem {
  const HardwareReceiptLineItem({
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.lineTotal,
    this.note,
  });

  final String name;
  final int qty;
  final double unitPrice;
  final double lineTotal;
  final String? note;
}

class HardwareReceiptData {
  const HardwareReceiptData({
    required this.storeName,
    this.branchName = '',
    required this.storeAddress,
    required this.receiptNumber,
    required this.formattedDate,
    required this.customerName,
    required this.cashierName,
    required this.paymentMethod,
    required this.items,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    this.pb1Amount = 0,
    required this.total,
    required this.paperSize,
    this.receiptTitle = 'Struk Penjualan',
    this.receiptNumberLabel = 'No. Struk',
    this.statusHeaderText = '',
    this.statusFooterText = '',
    this.previousKasbonAmount = 0,
    this.orderNote = '',
    this.cashReceived,
    this.changeAmount,
    this.showPoweredBy = true,
    this.isKasBon = false,
    this.isFnBMode = false,
    this.orderType = 'WALK_IN',
    this.tableNumber,
    this.logoBytes,
  });

  final String storeName;
  final String branchName;
  final String storeAddress;
  final String receiptNumber;
  final String formattedDate;
  final String customerName;
  final String cashierName;
  final String paymentMethod;
  final List<HardwareReceiptLineItem> items;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double pb1Amount;
  final double total;
  final int previousKasbonAmount;
  final String receiptTitle;
  final String receiptNumberLabel;
  final String statusHeaderText;
  final String statusFooterText;
  final String orderNote;
  final double? cashReceived;
  final double? changeAmount;
  final bool showPoweredBy;
  final bool isKasBon;
  final bool isFnBMode;
  final String orderType;
  final String? tableNumber;
  final String paperSize;
  final Uint8List? logoBytes;
}

class HardwareConnectionService {
  HardwareConnectionService({PrinterManager? printerManager})
      : _printerManager = printerManager ?? PrinterManager.instance;

  final PrinterManager _printerManager;
  static Future<void> _hardwareIoChain = Future<void>.value();
  static final Map<String, DateTime> _lastPrintAtByTarget =
  <String, DateTime>{};
  static bool includeLogoInThermalReceipt = false;

  Future<List<HardwareDeviceInfo>> discoverDevices(
      ConnectionType type, {
        bool isBle = false,
        Duration timeout = const Duration(seconds: 4),
      }) async {
    if (type != ConnectionType.bluetooth && type != ConnectionType.usb) {
      return const [];
    }

    final devices = <HardwareDeviceInfo>[];
    final completer = Completer<List<HardwareDeviceInfo>>();
    late final StreamSubscription<dynamic> subscription;
    Timer? timer;

    subscription = _printerManager
        .discovery(type: _toPrinterType(type), isBle: isBle)
        .listen(
          (dynamic device) {
        final item = HardwareDeviceInfo(
          name: (device.name ?? 'Perangkat Tanpa Nama').toString(),
          address: (device.address ?? '').toString(),
          connectionType: type,
          vendorId: device.vendorId?.toString(),
          productId: device.productId?.toString(),
          isBle: isBle,
        );
        final exists = devices.any(
              (existing) => existing.selectionKey == item.selectionKey,
        );
        if (!exists) {
          devices.add(item);
        }
      },
      onError: (Object error, StackTrace stackTrace) async {
        timer?.cancel();
        await subscription.cancel();
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
    );

    timer = Timer(timeout, () async {
      await subscription.cancel();
      if (!completer.isCompleted) {
        completer.complete(devices);
      }
    });

    return completer.future;
  }

  Future<List<HardwareDeviceInfo>> discoverBluetoothDevices({
    bool isBle = false,
    Duration timeout = const Duration(seconds: 4),
  }) {
    return discoverDevices(
      ConnectionType.bluetooth,
      isBle: isBle,
      timeout: timeout,
    );
  }

  Future<List<HardwareDeviceInfo>> discoverUsbDevices({
    Duration timeout = const Duration(seconds: 4),
  }) {
    return discoverDevices(ConnectionType.usb, timeout: timeout);
  }

  Future<void> sendRawBytes(
      HardwareConnectionConfig config,
      List<int> bytes, {
        Function(double progress, String status)? onProgress,
      }) async {
    onProgress?.call(0.1, 'Menghubungkan printer...');
    final targetKey = _resolvePrintTargetKey(config);
    final queued = _hardwareIoChain.then((_) async {
      final lastAt = _lastPrintAtByTarget[targetKey];
      if (lastAt != null) {
        final elapsed = DateTime.now().difference(lastAt);
        const minGap = Duration(milliseconds: 700);
        if (elapsed < minGap) {
          await Future<void>.delayed(minGap - elapsed);
        }
      }

      onProgress?.call(0.2, 'Mengirim data ke printer...');
      await _sendRawBytesNow(config, bytes).timeout(
        const Duration(seconds: 25),
        onTimeout: () {
          throw TimeoutException(
            'Print job timeout. Koneksi printer mungkin sedang sibuk.',
          );
        },
      );
      _lastPrintAtByTarget[targetKey] = DateTime.now();
      onProgress?.call(0.9, 'Menyelesaikan transfer...');
      if (!kIsWeb &&
          Platform.isWindows &&
          config.connectionType == ConnectionType.usb) {
        await Future<void>.delayed(const Duration(milliseconds: 2500));
      }
      onProgress?.call(1.0, 'Berhasil dikirim!');
    });
    _hardwareIoChain = queued.catchError((_) {});
    return queued;
  }

  String _resolvePrintTargetKey(HardwareConnectionConfig config) {
    switch (config.connectionType) {
      case ConnectionType.network:
        return 'network:${config.networkIp}:${config.networkPort}';
      case ConnectionType.bluetooth:
        return 'bluetooth:${config.deviceAddress}';
      case ConnectionType.usb:
        final usbId =
            '${config.deviceName}|${config.vendorId}|${config.productId}|${config.deviceAddress}';
        return 'usb:$usbId';
      case ConnectionType.none:
        return 'none';
    }
  }

  Future<void> _sendRawBytesNow(
      HardwareConnectionConfig config,
      List<int> bytes,
      ) async {
    if (!config.isConfigured) {
      throw Exception('Perangkat hardware belum dikonfigurasi');
    }

    switch (config.connectionType) {
      case ConnectionType.network:
        await _sendToNetwork(config, bytes);
        return;
      case ConnectionType.bluetooth:
      case ConnectionType.usb:
        await _sendToPrinterManager(config, bytes);
        return;
      case ConnectionType.none:
        throw Exception('Tipe koneksi hardware belum dipilih');
    }
  }

  Future<void> openCashDrawer(HardwareConnectionConfig config) {
    return sendRawBytes(config, buildOpenCashDrawerBytes(), onProgress: null);
  }

  List<int> buildOpenCashDrawerBytes() {
    return <int>[0x1B, 0x40, 0x1B, 0x70, 0x00, 0x19, 0xFA];
  }

  List<int> buildThermalReceiptBytes(HardwareReceiptData data) {
    final width = data.paperSize.trim().toLowerCase() == 'roll80' ? 42 : 32;
    final isRoll80 = width == 42;
    final bytes = <int>[0x1B, 0x40];
    final includeLogo = includeLogoInThermalReceipt;
    final itemsSubtotal = data.items.fold<double>(0, (sum, item) {
      final line = item.lineTotal > 0
          ? item.lineTotal
          : (item.unitPrice * item.qty);
      return sum + line;
    });
    final double subtotalFromTotals =
        data.total + data.discountAmount - data.taxAmount - data.pb1Amount;
    final double effectiveSubtotal = data.subtotal > 0
        ? data.subtotal
        : (itemsSubtotal > 0
        ? itemsSubtotal
        : (subtotalFromTotals > 0 ? subtotalFromTotals : 0.0));

    void addLine(
        String text, {
          int align = 0,
          bool bold = false,
          bool doubleSize = false,
        }) {
      final lines = _sanitizeText(text).split('\n');
      for (final line in lines) {
        bytes.addAll(<int>[0x1B, 0x61, align]);
        final style = (bold ? 0x08 : 0x00) | (doubleSize ? 0x30 : 0x00);
        bytes.addAll(<int>[0x1B, 0x21, style]);
        bytes.addAll(ascii.encode('$line\n'));
        bytes.addAll(<int>[0x1B, 0x21, 0x00]);
      }
    }

    void addWrappedText(
        String text, {
          int align = 0,
          bool bold = false,
          bool doubleSize = false,
        }) {
      for (final line in _wrapText(text, width)) {
        addLine(line, align: align, bold: bold, doubleSize: doubleSize);
      }
    }

    void addSeparator() {
      addLine('-' * width);
    }

    void addKeyValue(String label, String value, {bool bold = false}) {
      final padded = _padBetween(label, value, width);
      addLine(padded, bold: bold);
    }

    bool shouldPrintItemNote(String? rawNote) {
      final normalized = (rawNote ?? '').trim().toLowerCase();
      if (normalized.isEmpty) return false;
      return normalized != 'layanan jasa' && normalized != 'item servis';
    }

    try {
      if (includeLogo && data.logoBytes != null && data.logoBytes!.isNotEmpty) {
        final logoRaster = _buildEscPosRasterImageBytes(
          data.logoBytes!,
          maxWidth: data.paperSize.trim().toLowerCase() == 'roll80' ? 128 : 96,
          maxHeight: data.paperSize.trim().toLowerCase() == 'roll80' ? 40 : 32,
        );
        if (logoRaster.isNotEmpty && logoRaster.length <= 1600) {
          bytes.addAll(<int>[0x1B, 0x61, 0x01]);
          bytes.addAll(logoRaster);
          bytes.addAll(<int>[0x0A]);
        }
      }
    } catch (_) {}

    bytes.addAll(<int>[0x1B, 0x40]);

    addWrappedText(data.storeName, align: 1, bold: true, doubleSize: isRoll80);
    if (data.branchName.trim().isNotEmpty &&
        data.branchName.trim().toLowerCase() != 'unknown') {
      addWrappedText(data.branchName, align: 1, bold: true);
    }
    if (data.storeAddress.trim().isNotEmpty &&
        data.storeAddress.trim() != '-') {
      addWrappedText(data.storeAddress, align: 1);
    }
    addLine(data.receiptTitle, align: 1, bold: true);
    if (data.statusHeaderText.trim().isNotEmpty) {
      addWrappedText(data.statusHeaderText.trim(), align: 1, bold: true);
    }
    if (data.isKasBon) {
      addLine('BUKTI KAS BON / BELUM LUNAS', align: 1, bold: true);
    }
    addSeparator();
    addWrappedText('${data.receiptNumberLabel}: ${data.receiptNumber}');
    addWrappedText('Tanggal: ${data.formattedDate}');
    final normalizedOrderType = data.orderType.trim().toUpperCase();
    if (normalizedOrderType == 'DINE_IN' &&
        (data.tableNumber ?? '').trim().isNotEmpty) {
      addWrappedText('MEJA: ${(data.tableNumber ?? '').trim()}', bold: true);
      addWrappedText('Tipe: DINE-IN', bold: true);
    } else if (normalizedOrderType == 'TAKEAWAY') {
      addWrappedText('Tipe: TAKEAWAY', bold: true);
    }
    addWrappedText('Pelanggan: ${data.customerName}');
    addWrappedText('Kasir: ${data.cashierName}');
    addSeparator();

    for (final item in data.items) {
      addWrappedText(item.name);
      if (shouldPrintItemNote(item.note)) {
        addLine('  * ${item.note}');
      }
      final safeQty = item.qty <= 0 ? 1 : item.qty;
      addKeyValue(
        '$safeQty x ${_formatCompactCurrency(item.unitPrice)}',
        _formatCompactCurrency(item.lineTotal),
      );
    }

    addSeparator();
    addKeyValue('Subtotal', _formatCompactCurrency(effectiveSubtotal));
    if (data.discountAmount > 0) {
      addKeyValue('Diskon', '-${_formatCompactCurrency(data.discountAmount)}');
    }
    if (data.taxAmount > 0) {
      addKeyValue(
        'DPP',
        _formatCompactCurrency(effectiveSubtotal - data.discountAmount),
      );
      addKeyValue('PPN (11%)', _formatCompactCurrency(data.taxAmount));
    }
    if (data.pb1Amount > 0) {
      addKeyValue('PB1 (10%)', _formatCompactCurrency(data.pb1Amount));
    }
    if (data.previousKasbonAmount > 0) {
      addKeyValue(
        'Kasbon Lama',
        _formatCompactCurrency(data.previousKasbonAmount.toDouble()),
      );
    }

    addKeyValue(
      data.previousKasbonAmount > 0 ? 'Total Tanggungan' : 'Total',
      _formatCompactCurrency(data.total + data.previousKasbonAmount),
      bold: true,
    );
    addKeyValue('Metode Bayar', data.paymentMethod);

    if ((data.cashReceived ?? 0) > 0 && data.paymentMethod == 'Cash') {
      addKeyValue(
        'Tunai Diterima',
        _formatCompactCurrency(data.cashReceived ?? 0),
      );
      addKeyValue('Kembalian', _formatCompactCurrency(data.changeAmount ?? 0));
    }

    if (data.orderNote.trim().isNotEmpty) {
      addSeparator();
      addWrappedText('CATATAN KHUSUS:', bold: true);
      addWrappedText(data.orderNote.trim());
    }

    addSeparator();
    if (data.statusFooterText.trim().isNotEmpty) {
      addWrappedText(
        data.statusFooterText.trim(),
        align: 1,
        bold: true,
        doubleSize: isRoll80,
      );
      addSeparator();
    }
    addLine('Terima Kasih', align: 1, bold: true);
    addWrappedText(
      'Barang yang sudah dibeli tidak dapat ditukar/dikembalikan',
      align: 1,
    );
    if (data.showPoweredBy) {
      addLine('* Powered by Goldenity POS', align: 1);
    }

    bytes.addAll(<int>[0x0A, 0x0A, 0x0A, 0x0A]);
    bytes.addAll(<int>[0x1D, 0x56, 0x42, 0x00]);
    return bytes;
  }

  List<int> buildPrinterTestBytes({
    required String storeName,
    required String paperSizeLabel,
  }) {
    final buffer = StringBuffer()
      ..writeln(storeName)
      ..writeln('TEST PRINTER HARDWARE')
      ..writeln('Koneksi berhasil')
      ..writeln('Mode: $paperSizeLabel')
      ..writeln(DateTime.now().toIso8601String())
      ..writeln()
      ..writeln();

    return <int>[
      0x1B,
      0x40,
      ...ascii.encode(buffer.toString()),
      0x1B,
      0x64,
      0x04,
      0x1D,
      0x56,
      0x42,
      0x00,
    ];
  }

  List<int> _buildEscPosRasterImageBytes(
      Uint8List sourceBytes, {
        int maxWidth = 360,
        int maxHeight = 180,
      }) {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) {
      return const <int>[];
    }

    img.Image normalized = decoded;
    if (normalized.width > maxWidth) {
      final targetHeight = (normalized.height * maxWidth / normalized.width).round();
      normalized = img.copyResize(
        normalized,
        width: maxWidth,
        height: targetHeight,
        interpolation: img.Interpolation.average,
      );
    }

    if (normalized.height > maxHeight) {
      final targetWidth = (normalized.width * maxHeight / normalized.height).round();
      normalized = img.copyResize(
        normalized,
        width: targetWidth,
        height: maxHeight,
        interpolation: img.Interpolation.average,
      );
    }

    final width = normalized.width;
    final height = normalized.height;
    if (width <= 0 || height <= 0) {
      return const <int>[];
    }

    final out = <int>[];
    out.addAll(<int>[0x1B, 0x33, 16]);

    for (var y = 0; y < height; y += 8) {
      out.addAll(<int>[0x1B, 0x2A, 0, width & 0xFF, (width >> 8) & 0xFF]);

      for (var x = 0; x < width; x++) {
        var byteValue = 0;
        for (var bit = 0; bit < 8; bit++) {
          final pixelY = y + bit;
          if (pixelY >= height) {
            continue;
          }

          final pixel = normalized.getPixel(x, pixelY);
          final alpha = img.getAlpha(pixel);
          if (alpha < 80) {
            continue;
          }

          final luma = (0.299 * img.getRed(pixel) + 0.587 * img.getGreen(pixel) + 0.114 * img.getBlue(pixel)).round();
          if (luma < 150) {
            byteValue |= (1 << (7 - bit));
          }
        }
        out.add(byteValue);
      }

      out.add(0x0A);
    }

    out.addAll(<int>[0x1B, 0x32]);
    return out;
  }

  Future<void> _sendToNetwork(
      HardwareConnectionConfig config,
      List<int> bytes,
      ) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        config.networkIp,
        config.networkPort,
        timeout: const Duration(seconds: 5),
      );
      socket.add(bytes);
      await socket.flush();
    } finally {
      await socket?.close();
    }
  }

  Future<void> _sendToPrinterManager(
      HardwareConnectionConfig config,
      List<int> bytes,
      ) async {
    final printerType = _toPrinterType(config.connectionType);
    var connected = false;
    var sent = false;

    try {
      await _printerManager.disconnect(type: printerType);
    } catch (_) {}

    try {
      switch (config.connectionType) {
        case ConnectionType.bluetooth:
          connected = await _printerManager.connect(
            type: printerType,
            model: BluetoothPrinterInput(
              name: config.deviceName,
              address: config.deviceAddress,
              isBle: config.isBle,
              autoConnect: false,
            ),
          ).timeout(const Duration(seconds: 5));
          if (!connected) {
            throw Exception('Gagal terhubung ke printer Bluetooth.');
          }
          if (!kIsWeb && Platform.isAndroid) {
            await Future<void>.delayed(const Duration(milliseconds: 700));
          }
          break;
        case ConnectionType.usb:
          connected = await _printerManager.connect(
            type: printerType,
            model: UsbPrinterInput(
              name: config.deviceName,
              productId: config.productId,
              vendorId: config.vendorId,
            ),
          ).timeout(const Duration(seconds: 5));
          if (!connected) {
            throw Exception(
              'Gagal terhubung ke printer USB. Pada Windows, gunakan nama printer USB yang terdeteksi (bukan COM port).',
            );
          }
          break;
        case ConnectionType.network:
        case ConnectionType.none:
          break;
      }

      bool hasEscPosImageCommand(List<int> payload) {
        for (var i = 0; i < payload.length - 2; i++) {
          if (payload[i] == 0x1B && payload[i + 1] == 0x2A) {
            return true;
          }
          if (payload[i] == 0x1D &&
              payload[i + 1] == 0x76 &&
              payload[i + 2] == 0x30) {
            return true;
          }
        }
        return false;
      }

      Future<void> sendWithChunking(
          List<int> payload, {
            int? overrideChunkSize,
            int? overrideInterChunkDelayMs,
          }) async {
        final chunkSize =
            overrideChunkSize ??
                (config.connectionType == ConnectionType.usb ? 512 : 1024);
        final interChunkDelayMs = overrideInterChunkDelayMs ?? 50;

        if (payload.length <= chunkSize) {
          sent = await _printerManager.send(type: printerType, bytes: payload);
          if (!sent) {
            throw Exception('Data print tidak terkirim ke perangkat.');
          }
          return;
        }

        for (var offset = 0; offset < payload.length; offset += chunkSize) {
          final end = (offset + chunkSize < payload.length)
              ? offset + chunkSize
              : payload.length;
          final chunk = payload.sublist(offset, end);
          sent = await _printerManager.send(type: printerType, bytes: chunk);
          if (!sent) {
            throw Exception(
              'Data print tidak terkirim ke perangkat (chunk ${offset ~/ chunkSize + 1}).',
            );
          }
          if (end < payload.length) {
            await Future<void>.delayed(
              Duration(milliseconds: interChunkDelayMs),
            );
          }
        }
      }

      final containsImageCommand = hasEscPosImageCommand(bytes);
      final isWindowsUsb =
          !kIsWeb &&
              Platform.isWindows &&
              config.connectionType == ConnectionType.usb;
      Future<void> sendWindowsUsbReceiptWithTailFlush(List<int> payload) async {
        const tailBytes = 192;
        const tailPauseMs = 450;

        if (payload.length <= tailBytes) {
          await sendWithChunking(
            payload,
            overrideChunkSize: 128,
            overrideInterChunkDelayMs: 120,
          );
          return;
        }

        final splitIndex = payload.length - tailBytes;
        final head = payload.sublist(0, splitIndex);
        final tail = payload.sublist(splitIndex);

        await sendWithChunking(
          head,
          overrideChunkSize: 256,
          overrideInterChunkDelayMs: 90,
        );
        await Future<void>.delayed(const Duration(milliseconds: tailPauseMs));
        await sendWithChunking(
          tail,
          overrideChunkSize: 96,
          overrideInterChunkDelayMs: 140,
        );
      }

      if (containsImageCommand) {
        sent = await _printerManager.send(type: printerType, bytes: bytes);
        if (!sent) {
          throw Exception('Data print tidak terkirim ke perangkat.');
        }
        await Future<void>.delayed(const Duration(milliseconds: 700));
      } else if (isWindowsUsb) {
        await sendWindowsUsbReceiptWithTailFlush(bytes);
      } else if (bytes.length <=
          (config.connectionType == ConnectionType.usb ? 512 : 1024)) {
        sent = await _printerManager.send(type: printerType, bytes: bytes);
        if (!sent) {
          throw Exception('Data print tidak terkirim ke perangkat.');
        }
      } else {
        await sendWithChunking(bytes);
      }

      await Future<void>.delayed(const Duration(seconds: 3));

      final payloadSize = bytes.length;
      final baseDelayMs = config.connectionType == ConnectionType.usb
          ? 1200
          : 700;
      final variableDelayMs = ((payloadSize / 120).ceil() * 80).clamp(0, 2800);
      var settleDelayMs = (baseDelayMs + variableDelayMs).clamp(900, 4500);
      if (!kIsWeb &&
          Platform.isWindows &&
          config.connectionType == ConnectionType.usb) {
        final windowsUsbDelay = switch (payloadSize) {
          > 18000 => 12000,
          > 10000 => 9000,
          > 6000 => 7000,
          _ => settleDelayMs + 500,
        };
        settleDelayMs = windowsUsbDelay.clamp(1200, 12000);
      }
      await Future<void>.delayed(Duration(milliseconds: settleDelayMs));
    } finally {
      try {
        await _printerManager.disconnect(type: printerType);
      } catch (_) {}
    }
  }

  PrinterType _toPrinterType(ConnectionType type) {
    switch (type) {
      case ConnectionType.bluetooth:
        return PrinterType.bluetooth;
      case ConnectionType.usb:
        return PrinterType.usb;
      case ConnectionType.network:
        return PrinterType.network;
      case ConnectionType.none:
        throw Exception('ConnectionType.none tidak punya PrinterType');
    }
  }

  String _formatCompactCurrency(double value) {
    final raw = value.toInt().toString();
    final grouped = raw.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match match) => '${match[1]}.',
    );
    return 'Rp $grouped';
  }

  String _sanitizeText(String text) {
    final normalized = text.replaceAll('\r', ' ').trimRight();
    return normalized.replaceAllMapped(
      RegExp(r'[^\x0A\x0D\x20-\x7E]'),
          (_) => ' ',
    );
  }

  List<String> _wrapText(String text, int width) {
    final normalized = _sanitizeText(text).trim();
    if (normalized.isEmpty) {
      return const [''];
    }

    final lines = <String>[];
    for (final rawLine in normalized.split('\n')) {
      final words = rawLine.split(RegExp(r'\s+'));
      var current = '';
      for (final word in words) {
        if (word.isEmpty) continue;
        final candidate = current.isEmpty ? word : '$current $word';
        if (candidate.length <= width) {
          current = candidate;
          continue;
        }
        if (current.isNotEmpty) {
          lines.add(current);
          current = '';
        }
        if (word.length <= width) {
          current = word;
          continue;
        }
        var remaining = word;
        while (remaining.length > width) {
          lines.add(remaining.substring(0, width));
          remaining = remaining.substring(width);
        }
        current = remaining;
      }
      if (current.isNotEmpty) {
        lines.add(current);
      }
      if (rawLine.trim().isEmpty) {
        lines.add('');
      }
    }
    return lines.isEmpty ? const [''] : lines;
  }

  String _padBetween(String left, String right, int width) {
    final safeLeft = _sanitizeText(left).trim();
    final safeRight = _sanitizeText(right).trim();
    const minSpacing = 2;
    final spaces = width - safeLeft.length - safeRight.length;

    if (spaces >= minSpacing) {
      return '$safeLeft${' ' * spaces}$safeRight';
    }

    final fallbackSpaces = width - safeLeft.length - safeRight.length;
    if (fallbackSpaces >= 1) {
      return '$safeLeft${' ' * fallbackSpaces}$safeRight';
    }

    return '$safeLeft\n${safeRight.padLeft(width)}';
  }
}
