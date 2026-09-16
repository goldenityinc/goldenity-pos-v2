import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../core/models/printer_config_profile.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/hardware_connection_service.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/inventory/providers/product_list_provider.dart';
import '../../../features/settings/screens/settings_screen.dart';
import '../../../features/settings/widgets/printer_slot_card.dart';

class ProfileMobileScreen extends ConsumerStatefulWidget {
  const ProfileMobileScreen({super.key});

  @override
  ConsumerState<ProfileMobileScreen> createState() =>
      _ProfileMobileScreenState();
}

class _ProfileMobileScreenState extends ConsumerState<ProfileMobileScreen> {
  final HardwareConnectionService _hwSvc = HardwareConnectionService();

  final TextEditingController _printerAddressCtrl = TextEditingController();
  final TextEditingController _printerPortCtrl = TextEditingController();

  PrinterConnectionTypeDto _printerConnType = PrinterConnectionTypeDto.none;
  int _printerPaperWidthMm = 58;
  bool _printerAutoOpenCashDrawer = false;
  bool _printerIsBle = false;

  bool _scanLoading = false;
  String _scanMsg = '';
  List<HardwareDeviceInfo> _scannedDevices = [];
  bool _testingPrint = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPrinterDefault());
  }

  @override
  void dispose() {
    _printerAddressCtrl.dispose();
    _printerPortCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrinterDefault() async {
    try {
      final auth = ref.read(authNotifierProvider.notifier);
      final token = auth.session?.token;
      if (token == null) return;
      final settingsApi = ref.read(settingsApiServiceProvider);
      final session = ref.read(currentSessionProvider);
      final branchId =
          session?.selectedBranchId ?? session?.user.branchId;
      if (branchId == null || branchId.isEmpty) return;
      final list =
          await settingsApi.listPrinters(authToken: token, branchId: branchId);
      if (!mounted) return;
      for (final p in list) {
        if (p.slot == PrinterSlotDto.defaultPrinter) {
          setState(() {
            _printerConnType = p.connectionType;
            var addr = p.address ?? '';
            final isBle = p.connectionType ==
                    PrinterConnectionTypeDto.bluetooth &&
                addr.toLowerCase().endsWith('|ble');
            if (isBle) {
              addr = addr.substring(0, addr.length - '|ble'.length).trim();
            }
            _printerAddressCtrl.text = addr;
            _printerIsBle = isBle;
            _printerPortCtrl.text = p.port != null ? '${p.port}' : '';
            _printerPaperWidthMm = p.paperWidth;
            _printerAutoOpenCashDrawer = p.autoOpenCashDrawer;
          });
          break;
        }
      }
    } catch (_) {}
  }

  String _connTypeLabel(PrinterConnectionTypeDto t) {
    return switch (t) {
      PrinterConnectionTypeDto.bluetooth => 'Bluetooth',
      PrinterConnectionTypeDto.usb => 'USB',
      PrinterConnectionTypeDto.network => 'Network (LAN)',
      PrinterConnectionTypeDto.none => 'Tidak Aktif',
    };
  }

  Future<void> _onScan() async {
    if (_scanLoading) return;
    if (_printerConnType == PrinterConnectionTypeDto.none) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: GoldenityColors.warning,
            content: Text(
              'Pilih tipe koneksi terlebih dahulu (Bluetooth / USB) sebelum Scan.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        );
      }
      return;
    }
    if (_printerConnType == PrinterConnectionTypeDto.network) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: GoldenityColors.primary,
            content: Text(
              'Network (LAN) tidak support auto-scan. Masukkan IP & Port secara manual.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        );
      }
      return;
    }
    setState(() {
      _scanLoading = true;
      _scanMsg = 'Sedang mencari perangkat...';
      _scannedDevices = [];
    });
    try {
      final hwType = _printerConnType == PrinterConnectionTypeDto.bluetooth
          ? ConnectionType.bluetooth
          : ConnectionType.usb;
      final results = await _hwSvc.discoverDevices(hwType,
          timeout: const Duration(seconds: 5));
      setState(() {
        _scannedDevices = results;
        _scanMsg = results.isEmpty
            ? 'Tidak ditemukan perangkat. Pastikan printer sudah ON & terkoneksi / ter-pairing.'
            : 'Ditemukan ${results.length} perangkat. Pilih salah satu dibawah.';
      });
    } catch (e) {
      setState(() {
        _scanMsg = 'Scan gagal: ${e.toString()}';
      });
    } finally {
      if (mounted) setState(() => _scanLoading = false);
    }
  }

  HardwareConnectionConfig? _buildLiveHwConfig() {
    final connType = _printerConnType;
    final hwType = switch (connType) {
      PrinterConnectionTypeDto.bluetooth => ConnectionType.bluetooth,
      PrinterConnectionTypeDto.usb => ConnectionType.usb,
      PrinterConnectionTypeDto.network => ConnectionType.network,
      _ => ConnectionType.none,
    };
    if (hwType == ConnectionType.none) return null;
    final addr = _printerAddressCtrl.text.trim();
    if (addr.isEmpty) return null;
    final isNetwork = hwType == ConnectionType.network;
    final isUsb = hwType == ConnectionType.usb;
    String usbName = '';
    String vid = '';
    String pid = '';
    if (isUsb) {
      final parts = addr.split('|');
      if (parts.length >= 3) {
        usbName = parts[0].trim();
        vid = parts[1].trim();
        pid = parts[2].trim();
      } else {
        usbName = addr;
      }
    }
    final portRaw = _printerPortCtrl.text.trim();
    final port =
        portRaw.isNotEmpty ? int.tryParse(portRaw) : null;
    return HardwareConnectionConfig(
      connectionType: hwType,
      deviceName: isUsb ? usbName : '',
      deviceAddress: isNetwork ? '' : addr,
      vendorId: vid,
      productId: pid,
      isBle: _printerIsBle,
      networkIp: isNetwork ? addr : '',
      networkPort: isNetwork && port != null && port > 0 ? port : 9100,
    );
  }

  List<int> _buildTestPrintBytes() {
    final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final addr = _printerAddressCtrl.text.trim();
    final ascii = <int>[];
    void addLine(String text) {
      for (final ch in text.runes) {
        ascii.add(ch < 128 ? ch : 63);
      }
      ascii.add(10);
    }

    ascii.addAll([0x1B, 0x40]);
    ascii.addAll([0x1B, 0x61, 0x01]);
    addLine('*** TEST PRINT ***');
    addLine('Goldenity POS');
    addLine(now);
    ascii.addAll([0x1B, 0x61, 0x00]);
    addLine('Slot: Default');
    addLine('Koneksi: ${_connTypeLabel(_printerConnType)}');
    if (addr.isNotEmpty) addLine('Alamat: $addr');
    addLine('------------------------');
    addLine('Printer terhubung dan OK!');
    ascii.addAll([0x0A, 0x0A]);
    if (_printerAutoOpenCashDrawer) {
      addLine('(Mencoba buka cash drawer...)');
      ascii.addAll(_hwSvc.buildOpenCashDrawerBytes());
    }
    ascii.addAll([0x0A]);
    ascii.addAll([0x1B, 0x69]);
    return ascii;
  }

  Future<void> _onTestPrint() async {
    if (_testingPrint) return;
    final config = _buildLiveHwConfig();
    if (config == null || !config.isConfigured) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: GoldenityColors.warning,
            content: Text(
              'Lengkapi tipe koneksi & alamat printer dulu sebelum test print.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        );
      }
      return;
    }
    setState(() => _testingPrint = true);
    try {
      await _hwSvc
          .sendRawBytes(config, _buildTestPrintBytes())
          .timeout(const Duration(seconds: 15));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: GoldenityColors.success,
            content: Text(
              '✅ Test print terkirim. Cek kertas pada printer.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GoldenityColors.error,
            content: Text(
              'Test print gagal: ${e.toString().replaceAll('Exception: ', '')}',
              style:
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _testingPrint = false);
    }
  }

  String _encodeDeviceAddress(HardwareDeviceInfo d) {
    if (d.connectionType == ConnectionType.usb) {
      final vid = (d.vendorId ?? '').trim();
      final pid = (d.productId ?? '').trim();
      final name = d.name.trim().isNotEmpty
          ? d.name.trim()
          : d.address.trim();
      if (vid.isNotEmpty && pid.isNotEmpty) {
        return '$name|$vid|$pid';
      }
      return name.isNotEmpty ? name : d.address.trim();
    }
    return d.address.isNotEmpty ? d.address : d.name;
  }

  void _onApplyDevice(HardwareDeviceInfo d) {
    setState(() {
      if (d.connectionType == ConnectionType.bluetooth) {
        _printerConnType = PrinterConnectionTypeDto.bluetooth;
        _printerIsBle = false;
      } else if (d.connectionType == ConnectionType.usb) {
        _printerConnType = PrinterConnectionTypeDto.usb;
      }
      _printerAddressCtrl.text = _encodeDeviceAddress(d);
    });
  }

  Future<void> _onSavePrinter() async {
    try {
      final auth = ref.read(authNotifierProvider.notifier);
      final token = auth.session?.token;
      if (token == null) throw Exception('Sesi tidak ditemukan');
      final settingsApi = ref.read(settingsApiServiceProvider);
      final session = ref.read(currentSessionProvider);
      final branchId =
          session?.selectedBranchId ?? session?.user.branchId;
      if (branchId == null || branchId.isEmpty) return;
      final connType = _printerConnType;
      var address = _printerAddressCtrl.text.trim();
      if (connType == PrinterConnectionTypeDto.bluetooth &&
          _printerIsBle &&
          address.isNotEmpty) {
        address = '$address|ble';
      }
      final portRaw = _printerPortCtrl.text.trim();
      final port =
          portRaw.isNotEmpty ? int.tryParse(portRaw) : null;

      await settingsApi.upsertPrinter(
        authToken: token,
        branchId: branchId,
        slot: PrinterSlotDto.defaultPrinter,
        connectionType: connType,
        address: address.isNotEmpty ? address : null,
        port: port,
        paperWidth: _printerPaperWidthMm,
        autoOpenCashDrawer: _printerAutoOpenCashDrawer,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: GoldenityColors.success,
            content: Text('Printer Default berhasil disimpan'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GoldenityColors.error,
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    }
  }

  Future<void> _onLogout() async {
    await ref.read(authNotifierProvider.notifier).logout();
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '--';
    final parts = trimmed.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (parts[0].length >= 2) {
      return parts[0].substring(0, 2).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  String _roleLabel(UserRole role) {
    return switch (role) {
      UserRole.CASHIER => 'CASHIER',
      UserRole.TENANT_ADMIN => 'TENANT_ADMIN',
      UserRole.SUPER_ADMIN => 'SUPER_ADMIN',
      UserRole.CRM_STAFF => 'CRM_STAFF',
      UserRole.WORKSHOP_ADMIN => 'WORKSHOP_ADMIN',
      UserRole.ACCOUNTANT => 'ACCOUNTANT',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final biz = theme.extension<GoldenityBizColors>() ??
        GoldenityBizColors.fnb;
    final session = ref.watch(currentSessionProvider);
    final user = session?.user;
    final tenant = session?.tenant;
    final selectedBranch = session?.selectedBranch;
    final branchName =
        selectedBranch?.name ?? user?.branchId ?? tenant?.name ?? 'Cabang';
    final userName = user?.username ?? tenant?.name ?? 'User';
    final userRole = user?.role ?? UserRole.CASHIER;

    return Scaffold(
      backgroundColor: GoldenityColors.bg,
      appBar: AppBar(
        backgroundColor: GoldenityColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Profil'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: GoldenitySpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: GoldenitySpacing.md),
              Container(
                padding: const EdgeInsets.all(GoldenitySpacing.lg),
                decoration: BoxDecoration(
                  color: GoldenityColors.surface2,
                  borderRadius:
                      BorderRadius.circular(GoldenityRadius.xxxl),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: biz.base,
                      child: Text(
                        _getInitials(userName),
                        style: textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: GoldenitySpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Cabang Aktif: $branchName',
                            style: textTheme.bodyMedium?.copyWith(
                              color: GoldenityColors.muted,
                            ),
                          ),
                          const SizedBox(height: GoldenitySpacing.sm),
                          Badge(
                            backgroundColor: biz.base,
                            textColor: Colors.white,
                            label: Text(
                              _roleLabel(userRole),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Expanded(child: SizedBox()),
                    IconButton.filledTonal(
                      onPressed: _onLogout,
                      icon: const Icon(Icons.power_settings_new_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: GoldenitySpacing.lg),
              Text(
                'Akun',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: GoldenitySpacing.sm),
              Container(
                decoration: BoxDecoration(
                  color: GoldenityColors.surface,
                  borderRadius:
                      BorderRadius.circular(GoldenityRadius.lg),
                  border: Border.all(color: GoldenityColors.border),
                ),
                child: Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.lock_outline_rounded),
                      title: Text('Ubah Password'),
                      subtitle: Text('Segera hadir'),
                      trailing:
                          Icon(Icons.chevron_right_rounded),
                      onTap: null,
                      enabled: false,
                    ),
                    const Divider(
                      height: 1,
                      color: GoldenityColors.border,
                      indent: GoldenitySpacing.lg + 24,
                    ),
                    ListTile(
                      leading:
                          const Icon(Icons.storefront_outlined),
                      title: const Text('Cabang Aktif'),
                      trailing:
                          const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Fitur akan hadir'),
                          ),
                        );
                      },
                    ),
                    const Divider(
                      height: 1,
                      color: GoldenityColors.border,
                      indent: GoldenitySpacing.lg + 24,
                    ),
                    ListTile(
                      leading:
                          const Icon(Icons.devices_outlined),
                      title: const Text('Device Info'),
                      subtitle: const Text('version v2.0.0'),
                      trailing:
                          const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('version v2.0.0'),
                          ),
                        );
                      },
                    ),
                    const Divider(
                      height: 1,
                      color: GoldenityColors.border,
                      indent: GoldenitySpacing.lg + 24,
                    ),
                    ListTile(
                      leading: const Icon(Icons.tune_rounded),
                      title: const Text('Buka Pengaturan Lanjutan'),
                      trailing:
                          const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: GoldenitySpacing.lg),
              Text(
                'Pengaturan Printer',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: GoldenitySpacing.sm),
              PrinterSlotCard(
                slot: PrinterSlotDto.defaultPrinter,
                slotLabel: 'Default',
                connType: _printerConnType,
                addressCtrl: _printerAddressCtrl,
                portCtrl: _printerPortCtrl,
                connTypeLabelFn: _connTypeLabel,
                biz: biz,
                textTheme: textTheme,
                onConnTypeChanged: (v) {
                  setState(() => _printerConnType = v);
                },
                paperWidthMm: _printerPaperWidthMm,
                onPaperWidthChanged: (v) {
                  setState(() => _printerPaperWidthMm = v);
                },
                autoOpenCashDrawer: _printerAutoOpenCashDrawer,
                onAutoOpenCashDrawerChanged: (v) {
                  setState(() => _printerAutoOpenCashDrawer = v);
                },
                isBle: _printerIsBle,
                onIsBleChanged: (v) {
                  setState(() => _printerIsBle = v);
                },
                testingPrint: _testingPrint,
                onTestPrint: _onTestPrint,
                onSave: _onSavePrinter,
                scanning: _scanLoading,
                scanMsg: _scanMsg,
                scannedDevices: _scannedDevices,
                onAutoScan: _onScan,
                onApplyDevice: _onApplyDevice,
              ),
              const SizedBox(height: GoldenitySpacing.xl),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(
                    bottom: GoldenitySpacing.xl,
                  ),
                  child: Text(
                    'Goldenity POS v2.0.0',
                    style: textTheme.bodySmall?.copyWith(
                      color: GoldenityColors.muted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
