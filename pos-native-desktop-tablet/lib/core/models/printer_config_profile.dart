enum PrinterSlotDto { defaultPrinter, kitchen, cashier }

PrinterSlotDto parsePrinterSlot(String s) => switch (s) {
      'kitchen' => PrinterSlotDto.kitchen,
      'cashier' => PrinterSlotDto.cashier,
      _ => PrinterSlotDto.defaultPrinter
    };

String printerSlotToString(PrinterSlotDto s) => switch (s) {
      PrinterSlotDto.kitchen => 'kitchen',
      PrinterSlotDto.cashier => 'cashier',
      _ => 'defaultPrinter'
    };

enum PrinterConnectionTypeDto { bluetooth, usb, network, none }

PrinterConnectionTypeDto parsePrinterConnectionType(String s) => switch (s) {
      'bluetooth' => PrinterConnectionTypeDto.bluetooth,
      'usb' => PrinterConnectionTypeDto.usb,
      'network' => PrinterConnectionTypeDto.network,
      _ => PrinterConnectionTypeDto.none
    };

String printerConnTypeToString(PrinterConnectionTypeDto t) => switch (t) {
      PrinterConnectionTypeDto.bluetooth => 'bluetooth',
      PrinterConnectionTypeDto.usb => 'usb',
      PrinterConnectionTypeDto.network => 'network',
      _ => 'none'
    };

class PrinterConfigProfile {
  final String id;
  final String branchId;
  final PrinterSlotDto slot;
  final PrinterConnectionTypeDto connectionType;
  final String? address;
  final int? port;

  /// Lebar kertas thermal slot ini: 58 atau 80 (mm). Default 58.
  /// Issue #2 — sebelumnya di-hack di SharedPreferences, sekarang kolom DB nyata.
  final int paperWidth;

  /// Ported dari V1 (AppConfigService.autoOpenCashDrawer) — kirim perintah
  /// ESC/POS buka cash drawer ke printer slot ini setiap transaksi TUNAI
  /// selesai dicetak (drawer fisik umumnya nyambung via RJ11/RJ12 ke printer).
  final bool autoOpenCashDrawer;

  const PrinterConfigProfile({
    required this.id,
    required this.branchId,
    required this.slot,
    required this.connectionType,
    this.address,
    this.port,
    this.paperWidth = 58,
    this.autoOpenCashDrawer = false,
  });

  factory PrinterConfigProfile.fromJson(Map<String, dynamic> json) {
    return PrinterConfigProfile(
      id: json['id'] as String? ?? '',
      branchId: json['branchId'] as String? ?? '',
      slot: parsePrinterSlot(json['slot'] as String? ?? 'defaultPrinter'),
      connectionType: parsePrinterConnectionType(
          json['connectionType'] as String? ?? 'none'),
      address: json['address'] as String?,
      port: (json['port'] as num?)?.toInt(),
      paperWidth: (json['paperWidth'] as num?)?.toInt() == 80 ? 80 : 58,
      autoOpenCashDrawer: json['autoOpenCashDrawer'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'branchId': branchId,
        'slot': printerSlotToString(slot),
        'connectionType': printerConnTypeToString(connectionType),
        if (address != null) 'address': address,
        if (port != null) 'port': port,
        'paperWidth': paperWidth,
        'autoOpenCashDrawer': autoOpenCashDrawer,
      };

  PrinterConfigProfile copyWith({bool? autoOpenCashDrawer}) => PrinterConfigProfile(
        id: id,
        branchId: branchId,
        slot: slot,
        connectionType: connectionType,
        address: address,
        port: port,
        paperWidth: paperWidth,
        autoOpenCashDrawer: autoOpenCashDrawer ?? this.autoOpenCashDrawer,
      );
}
