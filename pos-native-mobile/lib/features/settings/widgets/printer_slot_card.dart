import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_elevation.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../core/models/printer_config_profile.dart';
import '../../../core/services/hardware_connection_service.dart';
import '../../../shared/widgets/goldenity_choice_chip.dart';
import '../../../shared/widgets/goldenity_primary_button.dart';
import '../../../shared/widgets/goldenity_toggle.dart';

class PrinterSlotCard extends ConsumerWidget {
  final PrinterSlotDto slot;
  final String slotLabel;
  final PrinterConnectionTypeDto connType;
  final TextEditingController addressCtrl;
  final TextEditingController portCtrl;
  final String Function(PrinterConnectionTypeDto) connTypeLabelFn;
  final GoldenityBizColors biz;
  final TextTheme textTheme;
  final ValueChanged<PrinterConnectionTypeDto> onConnTypeChanged;
  final int paperWidthMm;
  final ValueChanged<int> onPaperWidthChanged;
  final bool autoOpenCashDrawer;
  final ValueChanged<bool> onAutoOpenCashDrawerChanged;
  final bool isBle;
  final ValueChanged<bool> onIsBleChanged;
  final bool testingPrint;
  final VoidCallback? onTestPrint;
  final VoidCallback? onSave;
  final bool scanning;
  final String scanMsg;
  final List<HardwareDeviceInfo> scannedDevices;
  final VoidCallback? onAutoScan;
  final ValueChanged<HardwareDeviceInfo> onApplyDevice;

  const PrinterSlotCard({
    super.key,
    required this.slot,
    required this.slotLabel,
    required this.connType,
    required this.addressCtrl,
    required this.portCtrl,
    required this.connTypeLabelFn,
    required this.biz,
    required this.textTheme,
    required this.onConnTypeChanged,
    required this.paperWidthMm,
    required this.onPaperWidthChanged,
    required this.autoOpenCashDrawer,
    required this.onAutoOpenCashDrawerChanged,
    required this.isBle,
    required this.onIsBleChanged,
    required this.testingPrint,
    required this.onTestPrint,
    required this.onSave,
    required this.scanning,
    required this.scanMsg,
    required this.scannedDevices,
    required this.onAutoScan,
    required this.onApplyDevice,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const connOptions = PrinterConnectionTypeDto.values;
    return Container(
      decoration: BoxDecoration(
        color: GoldenityColors.surface2,
        borderRadius: BorderRadius.circular(GoldenityRadius.md),
        border: Border.all(color: GoldenityColors.border),
      ),
      padding: const EdgeInsets.all(GoldenitySpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: GoldenityColors.surface,
                  borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                ),
                child: Icon(Icons.print_outlined, color: biz.base, size: 20),
              ),
              const SizedBox(width: GoldenitySpacing.sm),
              Expanded(
                child: Text(
                  'Slot $slotLabel',
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Chip(
                backgroundColor: connType == PrinterConnectionTypeDto.none
                    ? GoldenityColors.surface
                    : biz.light,
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
                label: Text(
                  connTypeLabelFn(connType),
                  style: textTheme.labelSmall?.copyWith(
                    color: connType == PrinterConnectionTypeDto.none
                        ? GoldenityColors.text2
                        : biz.dark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: GoldenitySpacing.md),
          Wrap(
            spacing: GoldenitySpacing.xs,
            runSpacing: GoldenitySpacing.xs,
            children: connOptions.map((t) {
              final selected = connType == t;
              return GoldenityChoiceChip(
                label: connTypeLabelFn(t),
                selected: selected,
                activeColor: biz.base,
                dense: true,
                onSelected: (_) => onConnTypeChanged(t),
              );
            }).toList(),
          ),
          const SizedBox(height: GoldenitySpacing.md),
          Text(
            'Ukuran Kertas',
            style: textTheme.labelSmall?.copyWith(
              color: GoldenityColors.text2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: GoldenitySpacing.xs),
          Wrap(
            spacing: GoldenitySpacing.xs,
            runSpacing: GoldenitySpacing.xs,
            children: [58, 80].map((mm) {
              final selected = paperWidthMm == mm;
              return GoldenityChoiceChip(
                label: '${mm}mm',
                selected: selected,
                activeColor: biz.base,
                dense: true,
                onSelected: (_) => onPaperWidthChanged(mm),
              );
            }).toList(),
          ),
          const SizedBox(height: GoldenitySpacing.md),
          GoldenitySwitchRow(
            value: autoOpenCashDrawer,
            onChanged: connType == PrinterConnectionTypeDto.none
                ? null
                : onAutoOpenCashDrawerChanged,
            activeColor: biz.base,
            title: 'Otomatis Buka Cash Drawer',
            subtitle: 'Buka laci kasir otomatis setiap transaksi tunai selesai dicetak.',
          ),
          if (connType == PrinterConnectionTypeDto.bluetooth) ...[
            const SizedBox(height: GoldenitySpacing.md),
            GoldenitySwitchRow(
              value: isBle,
              onChanged: onIsBleChanged,
              activeColor: biz.base,
              title: 'Sambungkan via BLE',
              subtitle:
                  'Aktifkan jika printer gagal print / muncul "Bluetooth connection lost" '
                  'walau sudah terdeteksi (umum untuk printer bernama "..._BLE").',
            ),
          ],
          const SizedBox(height: GoldenitySpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextFormField(
                  controller: addressCtrl,
                  enabled: connType != PrinterConnectionTypeDto.none,
                  decoration: const InputDecoration(
                    labelText: 'Alamat / MAC / IP Address',
                    hintText: 'Contoh: 192.168.1.100 atau AA:BB:CC:DD:EE:FF',
                  ),
                ),
              ),
              const SizedBox(width: GoldenitySpacing.sm),
              ElevatedButton.icon(
                onPressed: onAutoScan,
                icon: Icon(
                  scanning
                      ? Icons.wifi_tethering_rounded
                      : Icons.manage_search_rounded,
                  size: 18,
                ),
                label: scanning
                    ? const Text('Scan...',
                        style: TextStyle(fontWeight: FontWeight.w700))
                    : const Text('Cari',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: scanning
                      ? GoldenityColors.disabled
                      : GoldenityColors.primary,
                  foregroundColor: GoldenityColors.surface,
                  disabledBackgroundColor: GoldenityColors.disabled,
                  disabledForegroundColor: GoldenityColors.text2,
                  minimumSize: const Size(110, 48),
                  padding: const EdgeInsets.symmetric(
                      horizontal: GoldenitySpacing.md),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(GoldenityRadius.md),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: GoldenitySpacing.md),
          TextFormField(
            controller: portCtrl,
            enabled: connType == PrinterConnectionTypeDto.network,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Port (Network saja)',
              hintText: 'Contoh: 9100',
            ),
          ),
          if (scanMsg.isNotEmpty) ...[
            const SizedBox(height: GoldenitySpacing.sm),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: GoldenitySpacing.sm),
              child: Text(
                scanMsg,
                style: textTheme.bodySmall?.copyWith(
                  color: scanMsg.toLowerCase().contains('gagal') ||
                          scanMsg.toLowerCase().contains('tidak ditemukan')
                      ? GoldenityColors.error
                      : GoldenityColors.text2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (scannedDevices.isNotEmpty) ...[
            const SizedBox(height: GoldenitySpacing.sm),
            Container(
              padding: const EdgeInsets.all(GoldenitySpacing.xs),
              decoration: BoxDecoration(
                color: GoldenityColors.surface,
                borderRadius: BorderRadius.circular(GoldenityRadius.lg),
                border: Border.all(color: GoldenityColors.border),
              ),
              child: Column(
                children: scannedDevices.asMap().entries.map((entry) {
                  final i = entry.key;
                  final d = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(
                        bottom: i == scannedDevices.length - 1
                            ? 0
                            : GoldenitySpacing.xs),
                    child: Material(
                      color: GoldenityColors.surface,
                      borderRadius: BorderRadius.circular(GoldenityRadius.md),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(GoldenityRadius.md),
                        onTap: () => onApplyDevice(d),
                        child: Padding(
                          padding: const EdgeInsets.all(GoldenitySpacing.sm),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: GoldenityColors.surface2,
                                  borderRadius:
                                      BorderRadius.circular(GoldenityRadius.sm),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  d.connectionType == ConnectionType.bluetooth
                                      ? Icons.bluetooth_rounded
                                      : Icons.usb_rounded,
                                  size: 16,
                                  color: GoldenityColors.text2,
                                ),
                              ),
                              const SizedBox(width: GoldenitySpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      d.name.isEmpty
                                          ? 'Perangkat Tanpa Nama'
                                          : d.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: GoldenityColors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      [
                                        connectionTypeLabel(d.connectionType),
                                        if (d.address.isNotEmpty) d.address,
                                        if (d.vendorId != null &&
                                            d.productId != null)
                                          'USB: ${d.vendorId}/${d.productId}',
                                      ].join('  ·  '),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.labelSmall?.copyWith(
                                          color: GoldenityColors.text2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: GoldenitySpacing.sm),
                              const Icon(Icons.chevron_right_rounded,
                                  size: 18, color: GoldenityColors.muted),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: GoldenitySpacing.md),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed:
                  connType == PrinterConnectionTypeDto.none ? null : onTestPrint,
              icon: testingPrint
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.receipt_long_outlined, size: 18),
              label: Text(
                testingPrint
                    ? 'Mengirim Test Print...'
                    : autoOpenCashDrawer
                        ? 'Test Print + Cash Drawer'
                        : 'Test Print',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: biz.base,
                side: BorderSide(color: biz.base),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(GoldenityRadius.md),
                ),
              ),
            ),
          ),
          const SizedBox(height: GoldenitySpacing.sm),
          GoldenityPrimaryButton(
            label: 'Simpan Slot $slotLabel',
            icon: Icons.save_rounded,
            backgroundColor: biz.base,
            shadow: GoldenityElevation.btnPrimary,
            height: 44,
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}
