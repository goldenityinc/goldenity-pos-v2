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

  const PrinterConfigProfile({
    required this.id,
    required this.branchId,
    required this.slot,
    required this.connectionType,
    this.address,
    this.port,
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
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'branchId': branchId,
        'slot': printerSlotToString(slot),
        'connectionType': printerConnTypeToString(connectionType),
        if (address != null) 'address': address,
        if (port != null) 'port': port,
      };
}
