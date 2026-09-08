import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../core/design/goldenity_elevation.dart';
import '../../../core/services/hardware_connection_service.dart';
import '../../../shared/widgets/goldenity_image_upload_field.dart';
import '../../../shared/widgets/goldenity_page_header.dart';
import '../../../shared/widgets/goldenity_primary_button.dart';
import '../../../core/models/branch_profile_extended.dart';
import '../../../core/models/printer_config_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../inventory/providers/product_list_provider.dart';
import '../../sales/providers/cart_provider.dart';
import '../services/device_api_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  String _errMsg = '';
  final HardwareConnectionService _hwSvc = HardwareConnectionService();
  final Map<PrinterSlotDto, List<HardwareDeviceInfo>> _scannedDevices = {};
  final Map<PrinterSlotDto, bool> _scanning = {};
  final Map<PrinterSlotDto, String> _scanMsg = {};

  late TabController _tabController;

  final TextEditingController _storeNameCtrl = TextEditingController();
  final TextEditingController _storeLogoCtrl = TextEditingController();
  final TextEditingController _storeAddressCtrl = TextEditingController();
  final TextEditingController _storePhoneCtrl = TextEditingController();
  final TextEditingController _storeReceiptFooterCtrl = TextEditingController();
  final TextEditingController _storeQrisUrlCtrl = TextEditingController();
  bool _storeAllowPayAtCashier = true;
  bool _storeIsPaymentProofMandatory = false;
  bool _blindShiftClose = false;
  bool _taxEnabled = true;
  num _taxRatePercentage = 11;
  bool _pricesIncludeTax = false;
  // Terima + cetak web order otomatis (toggle di tab "Printer per Cabang").
  bool _webOrderAutoAccept = false;
  bool _savingAutoAccept = false;
  final GlobalKey<FormState> _storeFormKey = GlobalKey<FormState>();

  List<BranchWithPrintersProfile> _branches = [];
  final TextEditingController _branchNameCtrl = TextEditingController();
  final TextEditingController _branchQrisCtrl = TextEditingController();
  final TextEditingController _branchSearchCtrl = TextEditingController();
  String _branchSearchQuery = '';
  final GlobalKey<FormState> _branchFormKey = GlobalKey<FormState>();

  String? _selectedBranchId;
  final Map<PrinterSlotDto, TextEditingController> _printerAddressCtrls = {};
  final Map<PrinterSlotDto, TextEditingController> _printerPortCtrls = {};
  final Map<PrinterSlotDto, PrinterConnectionTypeDto> _printerConnTypes = {};
  // Issue #2 — ukuran kertas 58/80mm per slot. Sekarang kolom nyata
  // `PrinterConfig.paperWidth` di backend (bukan lagi hack SharedPreferences):
  // di-load dari & disimpan ke `upsertPrinter`, dibaca payment modal dari
  // profil printer langsung.
  final Map<PrinterSlotDto, int> _printerPaperWidths = {};

  // Perangkat (multi-device)
  List<DeviceInfo> _devices = [];
  bool _devicesLoading = false;
  DeviceInfo? _thisDevice;
  final TextEditingController _deviceNameCtrl = TextEditingController();
  String _deviceRole = 'BOTH';

  /// Cabang yang aktif = cabang login (tanpa picker; beda cabang beda printer).
  String? get _loginBranchId {
    final s = ref.read(currentSessionProvider);
    return s?.selectedBranchId ?? s?.user.branchId;
  }

  String _branchNameFor(String? id) {
    if (id == null) return 'Cabang';
    for (final b in _branches) {
      if (b.id == id) return b.name;
    }
    final s = ref.read(currentSessionProvider);
    return s?.selectedBranch?.name ?? s?.tenant.name ?? 'Cabang';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _deviceNameCtrl.text = ref.read(deviceApiServiceProvider).localDeviceName();
    _deviceRole = ref.read(deviceApiServiceProvider).localDeviceRole();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadStore();
      await _loadBranches();
      // Printer terikat cabang login — muat otomatis, tanpa picker.
      final b = _loginBranchId;
      if (b != null && b.isNotEmpty) {
        _selectedBranchId = b;
        await _loadPrintersForBranch(b);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _storeNameCtrl.dispose();
    _storeLogoCtrl.dispose();
    _storeAddressCtrl.dispose();
    _storePhoneCtrl.dispose();
    _storeReceiptFooterCtrl.dispose();
    _storeQrisUrlCtrl.dispose();
    _branchNameCtrl.dispose();
    _branchQrisCtrl.dispose();
    _branchSearchCtrl.dispose();
    _deviceNameCtrl.dispose();
    for (final ctrl in _printerAddressCtrls.values) {
      ctrl.dispose();
    }
    for (final ctrl in _printerPortCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadStore() async {
    setState(() => _loading = true);
    try {
      final auth = ref.read(authNotifierProvider.notifier);
      final token = auth.session?.token;
      if (token == null) throw Exception('Sesi tidak ditemukan');
      final settingsApi = ref.read(settingsApiServiceProvider);
      final store = await settingsApi.getStore(authToken: token);
      if (store != null && mounted) {
        setState(() {
          _storeNameCtrl.text = store.name;
          _storeLogoCtrl.text = store.logoUrl ?? '';
          _storeAddressCtrl.text = store.address ?? '';
          _storePhoneCtrl.text = store.phone ?? '';
          _storeReceiptFooterCtrl.text = store.receiptFooter ?? '';
          _storeQrisUrlCtrl.text = store.qrisImageUrl ?? '';
          _storeAllowPayAtCashier = store.allowPayAtCashier;
          _storeIsPaymentProofMandatory = store.isPaymentProofMandatory;
          _blindShiftClose = store.blindShiftClose;
          _taxEnabled = store.taxEnabled;
          _taxRatePercentage = store.taxRatePercentage;
          _pricesIncludeTax = store.pricesIncludeTax;
          _webOrderAutoAccept = store.webOrderAutoAccept;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errMsg = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStore() async {
    final form = _storeFormKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() => _loading = true);
    try {
      final auth = ref.read(authNotifierProvider.notifier);
      final token = auth.session?.token;
      if (token == null) throw Exception('Sesi tidak ditemukan');
      final settingsApi = ref.read(settingsApiServiceProvider);
      final payload = <String, dynamic>{
        'name': _storeNameCtrl.text.trim(),
        // logo & QRIS: selalu dikirim (null saat dikosongkan) supaya user bisa
        // menghapus gambar, bukan cuma menambah.
        'logoUrl': _storeLogoCtrl.text.trim().isEmpty
            ? null
            : _storeLogoCtrl.text.trim(),
        'qrisImageUrl': _storeQrisUrlCtrl.text.trim().isEmpty
            ? null
            : _storeQrisUrlCtrl.text.trim(),
        if (_storeAddressCtrl.text.trim().isNotEmpty)
          'address': _storeAddressCtrl.text.trim(),
        if (_storePhoneCtrl.text.trim().isNotEmpty)
          'phone': _storePhoneCtrl.text.trim(),
        if (_storeReceiptFooterCtrl.text.trim().isNotEmpty)
          'receiptFooter': _storeReceiptFooterCtrl.text.trim(),
        'allowPayAtCashier': _storeAllowPayAtCashier,
        'isPaymentProofMandatory': _storeIsPaymentProofMandatory,
        'blindShiftClose': _blindShiftClose,
        'taxEnabled': _taxEnabled,
        'taxRatePercentage': _taxRatePercentage.toInt(),
        'pricesIncludeTax': _pricesIncludeTax,
        'webOrderAutoAccept': _webOrderAutoAccept,
      };
      await settingsApi.updateStore(authToken: token, data: payload);
      final cartNotifier = ref.read(cartNotifierProvider.notifier);
      cartNotifier.invalidateTaxCache();
      await cartNotifier.ensureTaxConfigCached(force: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: GoldenityColors.success,
            content: Text('Pengaturan toko berhasil diperbarui'),
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
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadBranches() async {
    setState(() => _loading = true);
    try {
      final auth = ref.read(authNotifierProvider.notifier);
      final token = auth.session?.token;
      if (token == null) throw Exception('Sesi tidak ditemukan');
      final settingsApi = ref.read(settingsApiServiceProvider);
      final list = await settingsApi.listBranches(authToken: token);
      if (mounted) {
        setState(() => _branches = list);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errMsg = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showBranchDialog({BranchWithPrintersProfile? existing}) async {
    _branchNameCtrl.text = existing?.name ?? '';
    _branchQrisCtrl.text = existing?.qrisImageUrl ?? '';
    final theme = Theme.of(context);
    final biz = theme.extension<GoldenityBizColors>() ?? GoldenityBizColors.fnb;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GoldenityRadius.xl)),
        title: Text(existing == null
            ? 'Tambah Cabang Baru'
            : 'Edit Cabang ${existing.name}'),
        content: Form(
          key: _branchFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _branchNameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nama Cabang',
                  hintText: 'Contoh: Cabang Pusat',
                ),
                validator: (v) =>
                    v!.trim().length < 3 ? 'Minimal 3 karakter' : null,
              ),
              const SizedBox(height: GoldenitySpacing.md),
              TextFormField(
                controller: _branchQrisCtrl,
                decoration: const InputDecoration(
                  labelText: 'URL Gambar QRIS',
                  hintText: 'https://.../qris.jpg',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          GoldenityPrimaryButton(
            label: 'Simpan',
            height: 40,
            backgroundColor: biz.base,
            shadow: GoldenityElevation.btnPrimary,
            onPressed: () async {
              final form = _branchFormKey.currentState;
              if (form == null || !form.validate()) return;
              try {
                final auth = ref.read(authNotifierProvider.notifier);
                final token = auth.session?.token;
                if (token == null) throw Exception('Sesi tidak ditemukan');
                final settingsApi = ref.read(settingsApiServiceProvider);
                if (existing == null) {
                  await settingsApi.createBranch(
                    authToken: token,
                    name: _branchNameCtrl.text.trim(),
                    qrisImageUrl: _branchQrisCtrl.text.trim().isNotEmpty
                        ? _branchQrisCtrl.text.trim()
                        : null,
                  );
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        backgroundColor: GoldenityColors.success,
                        content: Text('Cabang berhasil dibuat'),
                      ),
                    );
                  }
                } else {
                  final payload = <String, dynamic>{
                    'name': _branchNameCtrl.text.trim(),
                  };
                  if (_branchQrisCtrl.text.trim().isNotEmpty) {
                    payload['qrisImageUrl'] = _branchQrisCtrl.text.trim();
                  }
                  await settingsApi.updateBranch(
                    authToken: token,
                    branchId: existing.id,
                    data: payload,
                  );
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        backgroundColor: GoldenityColors.success,
                        content: Text('Cabang berhasil diperbarui'),
                      ),
                    );
                  }
                }
                await _loadBranches();
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      backgroundColor: GoldenityColors.error,
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteBranch(BranchWithPrintersProfile b) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: Text('Yakin hapus cabang ${b.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          GoldenityPrimaryButton(
            label: 'Ya, Hapus',
            height: 40,
            backgroundColor: GoldenityColors.error,
            shadow: GoldenityElevation.btnSuccess,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (result != true) return;

    setState(() => _loading = true);
    try {
      final auth = ref.read(authNotifierProvider.notifier);
      final token = auth.session?.token;
      if (token == null) throw Exception('Sesi tidak ditemukan');
      final settingsApi = ref.read(settingsApiServiceProvider);
      final data =
          await settingsApi.removeBranch(authToken: token, branchId: b.id);
      final softDeleted = data['softDeleted'] as bool?;
      final affectedSales = data['affectedSales'] as int? ?? 0;
      final message = data['message'] as String?;

      if (mounted) {
        if (softDeleted == false && affectedSales > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: GoldenityColors.warning,
              content:
                  Text(message ?? 'Masih dipakai $affectedSales transaksi'),
            ),
          );
        } else if (softDeleted == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: GoldenityColors.warning,
              content: Text(
                  message ?? 'Cabang di-nonaktifkan karena masih ada data'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: GoldenityColors.success,
              content: Text('Cabang dihapus permanen'),
            ),
          );
        }
      }
      await _loadBranches();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GoldenityColors.error,
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _ensurePrinterControllers() {
    for (final slot in PrinterSlotDto.values) {
      if (!_printerAddressCtrls.containsKey(slot)) {
        _printerAddressCtrls[slot] = TextEditingController();
      }
      if (!_printerPortCtrls.containsKey(slot)) {
        _printerPortCtrls[slot] = TextEditingController();
      }
      if (!_printerConnTypes.containsKey(slot)) {
        _printerConnTypes[slot] = PrinterConnectionTypeDto.none;
      }
      if (!_printerPaperWidths.containsKey(slot)) {
        _printerPaperWidths[slot] = 58;
      }
    }
  }

  Future<void> _loadPrintersForBranch(String branchId) async {
    _ensurePrinterControllers();
    setState(() => _loading = true);
    try {
      final auth = ref.read(authNotifierProvider.notifier);
      final token = auth.session?.token;
      if (token == null) throw Exception('Sesi tidak ditemukan');
      final settingsApi = ref.read(settingsApiServiceProvider);
      final list =
          await settingsApi.listPrinters(authToken: token, branchId: branchId);
      if (mounted) {
        // Reset ke default dulu (slot yang belum ada config-nya di BE).
        for (final slot in PrinterSlotDto.values) {
          _printerPaperWidths[slot] = 58;
        }
        for (final p in list) {
          _printerConnTypes[p.slot] = p.connectionType;
          _printerAddressCtrls[p.slot]?.text = p.address ?? '';
          _printerPortCtrls[p.slot]?.text = p.port != null ? '${p.port}' : '';
          // Issue #2 — ukuran kertas sekarang kolom nyata di PrinterConfig BE.
          _printerPaperWidths[p.slot] = p.paperWidth;
        }
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
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upsertPrinter(PrinterSlotDto slot) async {
    if (_selectedBranchId == null || _selectedBranchId!.isEmpty) return;
    setState(() => _loading = true);
    try {
      final auth = ref.read(authNotifierProvider.notifier);
      final token = auth.session?.token;
      if (token == null) throw Exception('Sesi tidak ditemukan');
      final settingsApi = ref.read(settingsApiServiceProvider);
      final connType = _printerConnTypes[slot] ?? PrinterConnectionTypeDto.none;
      final address = _printerAddressCtrls[slot]?.text.trim();
      final portRaw = _printerPortCtrls[slot]?.text.trim();
      final port =
          portRaw != null && portRaw.isNotEmpty ? int.tryParse(portRaw) : null;

      await settingsApi.upsertPrinter(
        authToken: token,
        branchId: _selectedBranchId!,
        slot: slot,
        connectionType: connType,
        address: address != null && address.isNotEmpty ? address : null,
        port: port,
        paperWidth: _printerPaperWidths[slot] ?? 58,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GoldenityColors.success,
            content: Text('Printer ${_slotLabel(slot)} berhasil disimpan'),
          ),
        );
      }
      await _loadPrintersForBranch(_selectedBranchId!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GoldenityColors.error,
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _slotLabel(PrinterSlotDto slot) {
    return switch (slot) {
      PrinterSlotDto.defaultPrinter => 'Default',
      PrinterSlotDto.kitchen => 'Dapur',
      PrinterSlotDto.cashier => 'Kasir',
    };
  }

  String _connTypeLabel(PrinterConnectionTypeDto t) {
    return switch (t) {
      PrinterConnectionTypeDto.bluetooth => 'Bluetooth',
      PrinterConnectionTypeDto.usb => 'USB',
      PrinterConnectionTypeDto.network => 'Network (LAN)',
      PrinterConnectionTypeDto.none => 'Tidak Aktif',
    };
  }

  Future<void> _runPrinterAutoScan(PrinterSlotDto slot) async {
    if (_scanning[slot] == true) return;
    final connType = _printerConnTypes[slot] ?? PrinterConnectionTypeDto.none;
    if (connType == PrinterConnectionTypeDto.none) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: GoldenityColors.warning,
            content: Text(
                'Pilih tipe koneksi terlebih dahulu (Bluetooth / USB) sebelum Scan.',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        );
      }
      return;
    }
    if (connType == PrinterConnectionTypeDto.network) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: GoldenityColors.primary,
            content: Text(
                'Network (LAN) tidak support auto-scan. Masukkan IP & Port secara manual.',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        );
      }
      return;
    }
    setState(() {
      _scanning[slot] = true;
      _scanMsg[slot] = 'Sedang mencari perangkat...';
      _scannedDevices[slot] = [];
    });
    try {
      final hwType = connType == PrinterConnectionTypeDto.bluetooth
          ? ConnectionType.bluetooth
          : ConnectionType.usb;
      final results = await _hwSvc.discoverDevices(hwType,
          timeout: const Duration(seconds: 5));
      setState(() {
        _scannedDevices[slot] = results;
        _scanMsg[slot] = results.isEmpty
            ? 'Tidak ditemukan perangkat. Pastikan printer sudah ON & terkoneksi / ter-pairing.'
            : 'Ditemukan ${results.length} perangkat. Pilih salah satu dibawah.';
      });
    } catch (e) {
      setState(() {
        _scanMsg[slot] = 'Scan gagal: ${e.toString()}';
      });
    } finally {
      if (mounted) setState(() => _scanning[slot] = false);
    }
  }

  void _applyScannedDevice(PrinterSlotDto slot, HardwareDeviceInfo d) {
    setState(() {
      if (d.connectionType == ConnectionType.bluetooth) {
        _printerConnTypes[slot] = PrinterConnectionTypeDto.bluetooth;
      } else if (d.connectionType == ConnectionType.usb) {
        _printerConnTypes[slot] = PrinterConnectionTypeDto.usb;
      }
      _printerAddressCtrls[slot]?.text = _encodeDeviceAddress(d);
    });
  }

  /// USB butuh vendorId/productId (Android) SELAIN nama (Windows). Simpan
  /// ketiganya sbagai `nama|vid|pid` supaya `_convertPrinterProfileToHwConfig`
  /// bisa isi lengkap. Bluetooth/lainnya tetap pakai address apa adanya.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final biz = theme.extension<GoldenityBizColors>() ?? GoldenityBizColors.fnb;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: GoldenityColors.bg,
        appBar: AppBar(
          backgroundColor: GoldenityColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: const GoldenityPageHeader(
            title: 'Pengaturan',
            subtitle: 'Kelola cabang, printer & informasi toko',
            dense: true,
          ),
          actions: [
            IconButton(
              onPressed: _loading
                  ? null
                  : () async {
                      setState(() => _errMsg = '');
                      final idx = _tabController.index;
                      if (idx == 0) {
                        await _loadStore();
                      } else if (idx == 1) {
                        await _loadBranches();
                      } else if (idx == 2 && _selectedBranchId != null) {
                        await _loadPrintersForBranch(_selectedBranchId!);
                      } else if (idx == 3) {
                        await _loadDevices();
                      }
                    },
              icon: _loading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: biz.base,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
            ),
            if (_tabController.index == 1)
              Padding(
                padding: const EdgeInsets.only(
                    right: GoldenitySpacing.md,
                    top: GoldenitySpacing.sm,
                    bottom: GoldenitySpacing.sm),
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : () => _showBranchDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: biz.base,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: GoldenitySpacing.md,
                        vertical: GoldenitySpacing.sm),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(GoldenityRadius.md)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text('Tambah Cabang',
                      style: textTheme.labelMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
              ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: biz.base,
            unselectedLabelColor: GoldenityColors.text2,
            indicatorColor: biz.base,
            labelStyle:
                textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'Info Toko'),
              Tab(text: 'Daftar Cabang'),
              Tab(text: 'Printer per Cabang'),
              Tab(text: 'Perangkat'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _errMsg.isNotEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(GoldenitySpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 48, color: GoldenityColors.error),
                          const SizedBox(height: GoldenitySpacing.md),
                          Text(_errMsg, style: textTheme.bodyMedium),
                          const SizedBox(height: GoldenitySpacing.md),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() => _errMsg = '');
                            },
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildStoreInfoTab(context, textTheme, biz),
                      _buildBranchesTab(context, textTheme, biz),
                      _buildPrintersTab(context, textTheme, biz),
                      _buildDevicesTab(context, textTheme, biz),
                    ],
                  ),
      ),
    );
  }

  Widget _buildStoreInfoTab(
      BuildContext context, TextTheme textTheme, GoldenityBizColors biz) {
    final token = ref.read(authNotifierProvider.notifier).session?.token ?? '';
    return Form(
      key: _storeFormKey,
      child: ListView(
        padding: const EdgeInsets.all(GoldenitySpacing.lg),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(GoldenityRadius.md),
              border: Border.all(color: GoldenityColors.border),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2))
              ],
            ),
            padding: const EdgeInsets.all(GoldenitySpacing.lg),
            // Material transparan → SwitchListTile di dalam kartu tetap merender
            // ink-ripple (hilangkan warning "ListTile ... may be invisible").
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.store_rounded, color: biz.base),
                      const SizedBox(width: GoldenitySpacing.sm),
                      Text(
                        'Informasi Toko',
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: GoldenitySpacing.md),
                  TextFormField(
                    controller: _storeNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Toko',
                      hintText: 'Nama toko Anda',
                    ),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Nama toko wajib diisi' : null,
                  ),
                  const SizedBox(height: GoldenitySpacing.md),
                  GoldenityImageUploadField(
                    label: 'Logo Toko',
                    kind: 'logo',
                    authToken: token,
                    value: _storeLogoCtrl.text.trim().isEmpty
                        ? null
                        : _storeLogoCtrl.text.trim(),
                    enabled: !_loading,
                    helperText: 'PNG / JPG, maks 6MB. Tampil di header struk.',
                    onChanged: (url) =>
                        setState(() => _storeLogoCtrl.text = url ?? ''),
                  ),
                  const SizedBox(height: GoldenitySpacing.md),
                  TextFormField(
                    controller: _storeAddressCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Alamat Toko',
                      hintText: 'Alamat lengkap toko',
                    ),
                  ),
                  const SizedBox(height: GoldenitySpacing.md),
                  TextFormField(
                    controller: _storePhoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nomor Telepon',
                      hintText: '08xx-xxxx-xxxx',
                    ),
                  ),
                  const SizedBox(height: GoldenitySpacing.md),
                  TextFormField(
                    controller: _storeReceiptFooterCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Footer Struk',
                      hintText: 'Terima kasih atas kunjungan Anda',
                    ),
                  ),
                  const SizedBox(height: GoldenitySpacing.md),
                  GoldenityImageUploadField(
                    label: 'Gambar QRIS Statis',
                    kind: 'qris',
                    authToken: token,
                    value: _storeQrisUrlCtrl.text.trim().isEmpty
                        ? null
                        : _storeQrisUrlCtrl.text.trim(),
                    enabled: !_loading,
                    helperText:
                        'QRIS statis toko — ditampilkan saat pelanggan bayar QRIS.',
                    onChanged: (url) =>
                        setState(() => _storeQrisUrlCtrl.text = url ?? ''),
                  ),
                  const SizedBox(height: GoldenitySpacing.lg),
                  const Divider(),
                  const SizedBox(height: GoldenitySpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Izinkan Pembayaran di Kasir',
                              style: textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: GoldenitySpacing.xs),
                            Text(
                              'Jika aktif, pelanggan bisa bayar langsung di kasir',
                              style: textTheme.bodySmall
                                  ?.copyWith(color: GoldenityColors.text2),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _storeAllowPayAtCashier,
                        onChanged: (v) =>
                            setState(() => _storeAllowPayAtCashier = v),
                        activeTrackColor: biz.base.withValues(alpha: 0.5),
                        activeThumbColor: biz.base,
                      ),
                    ],
                  ),
                  const SizedBox(height: GoldenitySpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bukti Pembayaran Wajib',
                              style: textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: GoldenitySpacing.xs),
                            Text(
                              'Jika aktif, wajib upload bukti transfer untuk non-tunai',
                              style: textTheme.bodySmall
                                  ?.copyWith(color: GoldenityColors.text2),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _storeIsPaymentProofMandatory,
                        onChanged: (v) =>
                            setState(() => _storeIsPaymentProofMandatory = v),
                        activeTrackColor: biz.base.withValues(alpha: 0.5),
                        activeThumbColor: biz.base,
                      ),
                    ],
                  ),
                  const SizedBox(height: GoldenitySpacing.md),
                  SwitchListTile.adaptive(
                    title: Text(
                      'Blind Close Shift Kasir',
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'Jika ON: kasir tidak melihat perkiraan uang sistem & selisih kasir saat buka/tutup shift (mode blind close).',
                      style: textTheme.bodySmall
                          ?.copyWith(color: GoldenityColors.text2),
                    ),
                    value: _blindShiftClose,
                    activeTrackColor: biz.base.withValues(alpha: 0.5),
                    activeThumbColor: biz.base,
                    contentPadding: EdgeInsets.zero,
                    onChanged: _loading
                        ? null
                        : (val) => setState(() => _blindShiftClose = val),
                  ),
                  const SizedBox(height: GoldenitySpacing.md),
                  SwitchListTile.adaptive(
                    title: Text(
                      'Aktifkan Pajak (PPN)',
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'Jika ON: transaksi akan dikenakan pajak sesuai persentase di bawah.',
                      style: textTheme.bodySmall
                          ?.copyWith(color: GoldenityColors.text2),
                    ),
                    value: _taxEnabled,
                    activeTrackColor: biz.base.withValues(alpha: 0.5),
                    activeThumbColor: biz.base,
                    contentPadding: EdgeInsets.zero,
                    onChanged: _loading
                        ? null
                        : (val) => setState(() => _taxEnabled = val),
                  ),
                  const SizedBox(height: GoldenitySpacing.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Persentase PPN (%)',
                        suffixText: '%',
                        helperText: 'Default 11% (standar PPN UMKM F&B)',
                      ),
                      enabled: _taxEnabled && !_loading,
                      keyboardType: TextInputType.number,
                      initialValue: _taxRatePercentage.toString(),
                      onChanged: (s) {
                        final n = num.tryParse(s);
                        if (n != null) {
                          setState(() => _taxRatePercentage = n.clamp(0, 100));
                        }
                      },
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3)
                      ],
                    ),
                  ),
                  const SizedBox(height: GoldenitySpacing.md),
                  SwitchListTile.adaptive(
                    title: Text(
                      'Harga Sudah Termasuk PPN',
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'ON: harga jual produk sudah termasuk pajak, PPN dihitung mundur '
                      '(total ÷ (1 + rate) × rate) dan tidak ditambah lagi di atas total. '
                      'OFF: PPN ditambahkan di atas subtotal.',
                      style: textTheme.bodySmall
                          ?.copyWith(color: GoldenityColors.text2),
                    ),
                    value: _pricesIncludeTax,
                    activeTrackColor: biz.base.withValues(alpha: 0.5),
                    activeThumbColor: biz.base,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (_taxEnabled && !_loading)
                        ? (val) => setState(() => _pricesIncludeTax = val)
                        : null,
                  ),
                  const SizedBox(height: GoldenitySpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: GoldenityPrimaryButton(
                      onPressed: _loading ? null : _updateStore,
                      label: 'Simpan Pengaturan',
                      icon: Icons.save_rounded,
                      backgroundColor: biz.base,
                      height: 48,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchesTab(
      BuildContext context, TextTheme textTheme, GoldenityBizColors biz) {
    final q = _branchSearchQuery.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _branches
        : _branches.where((b) {
            if (b.name.toLowerCase().contains(q)) return true;
            if (b.id.toLowerCase().contains(q)) return true;
            if (b.printerConfigs.length.toString().contains(q)) return true;
            if ((b.qrisImageUrl ?? '').isNotEmpty && 'qris'.contains(q)) {
              return true;
            }
            return false;
          }).toList(growable: false);
    if (_branches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(GoldenitySpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_tree_outlined,
                  size: 64, color: biz.base.withValues(alpha: 0.6)),
              const SizedBox(height: GoldenitySpacing.md),
              Text('Belum ada cabang',
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: GoldenitySpacing.xs),
              Text(
                'Tekan "Tambah Cabang" di pojok kanan atas untuk mulai.',
                style:
                    textTheme.bodySmall?.copyWith(color: GoldenityColors.text2),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            GoldenitySpacing.lg,
            GoldenitySpacing.md,
            GoldenitySpacing.lg,
            GoldenitySpacing.sm,
          ),
          child: TextField(
            controller: _branchSearchCtrl,
            onChanged: (v) => setState(() => _branchSearchQuery = v),
            decoration: InputDecoration(
              hintText: 'Cari nama cabang / QRIS / jumlah printer...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _branchSearchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _branchSearchCtrl.clear();
                        setState(() => _branchSearchQuery = '');
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: GoldenitySpacing.md,
                vertical: GoldenitySpacing.md,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(GoldenityRadius.md),
                borderSide:
                    const BorderSide(color: GoldenityColors.border, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(GoldenityRadius.md),
                borderSide: BorderSide(color: biz.base, width: 1.5),
              ),
            ),
          ),
        ),
        const Divider(height: 1, color: GoldenityColors.border2),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadBranches,
            color: biz.base,
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(GoldenitySpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search_off_rounded,
                              size: 48, color: GoldenityColors.muted),
                          const SizedBox(height: GoldenitySpacing.md),
                          Text(
                            'Tidak ada cabang yang cocok',
                            style: textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Coba kata kunci lain atau hapus filter pencarian.',
                            style: textTheme.bodySmall
                                ?.copyWith(color: GoldenityColors.text2),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(GoldenitySpacing.lg),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: GoldenitySpacing.sm),
                    itemBuilder: (context, i) {
                      final b = filtered[i];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(GoldenityRadius.md),
                          border: Border.all(color: GoldenityColors.border),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        padding: const EdgeInsets.all(GoldenitySpacing.md),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: biz.light,
                                borderRadius:
                                    BorderRadius.circular(GoldenityRadius.md),
                              ),
                              child: Icon(Icons.storefront_rounded,
                                  color: biz.dark, size: 28),
                            ),
                            const SizedBox(width: GoldenitySpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    b.name,
                                    style: textTheme.titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  if (b.qrisImageUrl != null &&
                                      b.qrisImageUrl!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: GoldenityColors.successLight,
                                        borderRadius: BorderRadius.circular(
                                            GoldenityRadius.sm),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.qr_code_2_rounded,
                                              size: 14,
                                              color: GoldenityColors.success),
                                          const SizedBox(width: 4),
                                          Text(
                                            'QRIS tersedia',
                                            style: textTheme.labelSmall
                                                ?.copyWith(
                                                    color:
                                                        GoldenityColors.success,
                                                    fontWeight:
                                                        FontWeight.w800),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: GoldenityColors.surface2,
                                        borderRadius: BorderRadius.circular(
                                            GoldenityRadius.sm),
                                      ),
                                      child: Text(
                                        'Belum ada QRIS',
                                        style: textTheme.labelSmall?.copyWith(
                                            color: GoldenityColors.text2,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  const SizedBox(height: GoldenitySpacing.xs),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: GoldenityColors.surface2,
                                      borderRadius: BorderRadius.circular(
                                          GoldenityRadius.sm),
                                    ),
                                    child: Text(
                                      '${b.printerConfigs.length} printer dikonfigurasi',
                                      style: textTheme.bodySmall?.copyWith(
                                          color: GoldenityColors.text2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: GoldenitySpacing.md),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  tooltip: 'Edit',
                                  onPressed: _loading
                                      ? null
                                      : () => _showBranchDialog(existing: b),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Hapus',
                                  color: GoldenityColors.error,
                                  onPressed: _loading
                                      ? null
                                      : () => _confirmDeleteBranch(b),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // ═══════════ Perangkat (multi-device) ═══════════
  Future<void> _loadDevices() async {
    setState(() => _devicesLoading = true);
    try {
      final token = ref.read(currentSessionProvider)?.token;
      if (token == null) throw Exception('Sesi tidak ditemukan');
      final svc = ref.read(deviceApiServiceProvider);
      final list = await svc.list(token: token, branchId: _loginBranchId);
      final myId = svc.localDeviceId();
      if (mounted) {
        setState(() {
          _devices = list;
          _thisDevice = list.where((d) => d.id == myId).firstOrNull;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errMsg = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _devicesLoading = false);
    }
  }

  Future<void> _registerThisDevice() async {
    setState(() => _devicesLoading = true);
    try {
      final token = ref.read(currentSessionProvider)?.token;
      if (token == null) throw Exception('Sesi tidak ditemukan');
      final svc = ref.read(deviceApiServiceProvider);
      await svc.saveLocal(name: _deviceNameCtrl.text.trim(), role: _deviceRole);
      await svc.register(token: token, branchId: _loginBranchId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: GoldenityColors.success, content: Text('Perangkat terdaftar.')));
      }
      await _loadDevices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: GoldenityColors.error,
            content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _devicesLoading = false);
    }
  }

  Future<void> _patchDevice(DeviceInfo d, {String? role, bool? isActive}) async {
    try {
      final token = ref.read(currentSessionProvider)?.token;
      if (token == null) throw Exception('Sesi tidak ditemukan');
      await ref
          .read(deviceApiServiceProvider)
          .patch(token: token, id: d.id, role: role, isActive: isActive);
      await _loadDevices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: GoldenityColors.error,
            content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    }
  }

  Widget _buildDevicesTab(
      BuildContext context, TextTheme textTheme, GoldenityBizColors biz) {
    final svc = ref.read(deviceApiServiceProvider);
    final myId = svc.localDeviceId();
    final registered = _thisDevice != null;
    final others = _devices.where((d) => d.id != myId).toList();

    return RefreshIndicator(
      onRefresh: _loadDevices,
      color: biz.base,
      child: ListView(
        padding: const EdgeInsets.all(GoldenitySpacing.lg),
        children: [
          _card(
            title: 'Perangkat Ini',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('UUID'),
                SelectableText(myId,
                    style: const TextStyle(
                        fontSize: 12, color: GoldenityColors.text2, fontFamily: 'monospace')),
                const SizedBox(height: GoldenitySpacing.md),
                _fieldLabel('Nama Perangkat'),
                TextField(
                  controller: _deviceNameCtrl,
                  decoration: const InputDecoration(hintText: 'mis. Kasir Depan / Tablet Dapur'),
                ),
                const SizedBox(height: GoldenitySpacing.md),
                _fieldLabel('Peran'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final r in const ['CASHIER', 'CHECKER', 'BOTH'])
                      ChoiceChip(
                        label: Text(_roleLabel(r)),
                        selected: _deviceRole == r,
                        onSelected: (_) => setState(() => _deviceRole = r),
                      ),
                  ],
                ),
                const SizedBox(height: GoldenitySpacing.md),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: registered
                            ? GoldenityColors.successLight
                            : GoldenityColors.warningLight,
                        borderRadius: BorderRadius.circular(GoldenityRadius.full),
                      ),
                      child: Text(
                        registered ? 'Terdaftar ✓' : 'Belum Terdaftar',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: registered ? GoldenityColors.success : GoldenityColors.warning),
                      ),
                    ),
                    if (registered && _thisDevice!.lastSeenAt != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Terakhir aktif ${_relTime(_thisDevice!.lastSeenAt!)}',
                        style: const TextStyle(fontSize: 11, color: GoldenityColors.muted),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: GoldenitySpacing.md),
                GoldenityPrimaryButton(
                  label: registered ? 'Perbarui Pendaftaran' : 'Daftarkan Perangkat',
                  icon: Icons.devices_rounded,
                  isLoading: _devicesLoading,
                  onPressed: _devicesLoading ? null : _registerThisDevice,
                ),
              ],
            ),
          ),
          const SizedBox(height: GoldenitySpacing.lg),
          _card(
            title: 'Perangkat Lain di ${_branchNameFor(_loginBranchId)} (${others.length})',
            child: others.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Belum ada perangkat lain terdaftar di cabang ini.',
                        style: TextStyle(fontSize: 13, color: GoldenityColors.muted)),
                  )
                : Column(
                    children: [
                      for (final d in others) _deviceRow(d),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _deviceRow(DeviceInfo d) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: GoldenityColors.surface2,
          borderRadius: BorderRadius.circular(GoldenityRadius.md),
          border: Border.all(color: GoldenityColors.border),
        ),
        child: Row(
          children: [
            Icon(d.role == 'CHECKER' ? Icons.soup_kitchen_rounded : Icons.point_of_sale_rounded,
                size: 18, color: GoldenityColors.text2),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  Text(
                    '${_roleLabel(d.role)}'
                    '${d.lastSeenAt != null ? ' · aktif ${_relTime(d.lastSeenAt!)}' : ''}',
                    style: const TextStyle(fontSize: 11, color: GoldenityColors.muted),
                  ),
                ],
              ),
            ),
            Switch(
              value: d.isActive,
              onChanged: (v) => _patchDevice(d, isActive: v),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      );

  Widget _card({required String title, required Widget child}) => Container(
        decoration: BoxDecoration(
          color: GoldenityColors.surface,
          borderRadius: BorderRadius.circular(GoldenityRadius.xl),
          border: Border.all(color: GoldenityColors.border),
          boxShadow: GoldenityElevation.card,
        ),
        padding: const EdgeInsets.all(GoldenitySpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: GoldenityColors.text)),
            const SizedBox(height: GoldenitySpacing.md),
            child,
          ],
        ),
      );

  Widget _fieldLabel(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(s,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
      );

  static String _roleLabel(String r) => switch (r) {
        'CASHIER' => 'Kasir',
        'CHECKER' => 'Dapur (Checker)',
        _ => 'Kasir + Dapur',
      };

  static String _relTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'baru saja';
    if (d.inMinutes < 60) return '${d.inMinutes} mnt lalu';
    if (d.inHours < 24) return '${d.inHours} jam lalu';
    return '${d.inDays} hari lalu';
  }

  /// Toggle "Penerimaan Web Order Otomatis" — simpan langsung ke /settings/store.
  Future<void> _toggleWebOrderAutoAccept(bool value) async {
    final prev = _webOrderAutoAccept;
    setState(() {
      _webOrderAutoAccept = value;
      _savingAutoAccept = true;
    });
    try {
      final token = ref.read(authNotifierProvider.notifier).session?.token;
      if (token == null) throw Exception('Sesi tidak ditemukan');
      await ref.read(settingsApiServiceProvider).updateStore(
            authToken: token,
            data: {'webOrderAutoAccept': value},
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: GoldenityColors.success,
          content: Text(value
              ? 'Mode otomatis aktif — web order langsung diterima & dicetak.'
              : 'Mode manual — kasir menerima & mencetak dari Web Orders.'),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _webOrderAutoAccept = prev);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: GoldenityColors.error,
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ));
      }
    } finally {
      if (mounted) setState(() => _savingAutoAccept = false);
    }
  }

  Widget _buildWebOrderAutoCard(TextTheme textTheme) {
    final on = _webOrderAutoAccept;
    const green = GoldenityColors.success;
    return Container(
      decoration: BoxDecoration(
        color: on ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(GoldenityRadius.md),
        border: Border.all(color: on ? const Color(0xFFBBF7D0) : GoldenityColors.border),
      ),
      padding: const EdgeInsets.all(GoldenitySpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: on ? green.withValues(alpha: 0.12) : GoldenityColors.primaryLight,
                  borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.delivery_dining_rounded,
                    size: 20, color: on ? green : GoldenityColors.primary),
              ),
              const SizedBox(width: GoldenitySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Penerimaan Web Order Otomatis',
                        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('Berlaku untuk semua pesanan masuk via QR / Mobile Web',
                        style: textTheme.bodySmall?.copyWith(color: GoldenityColors.muted)),
                  ],
                ),
              ),
              _savingAutoAccept
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : Switch(
                      value: on,
                      activeThumbColor: green,
                      onChanged: _loading ? null : _toggleWebOrderAutoAccept,
                    ),
            ],
          ),
          const SizedBox(height: GoldenitySpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(GoldenitySpacing.md),
            decoration: BoxDecoration(
              color: on ? green.withValues(alpha: 0.08) : GoldenityColors.surface2,
              borderRadius: BorderRadius.circular(GoldenityRadius.sm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(on ? Icons.circle : Icons.circle_outlined,
                        size: 10, color: on ? green : GoldenityColors.muted),
                    const SizedBox(width: 6),
                    Text(on ? 'Mode Otomatis — Aktif' : 'Mode Manual — Aktif',
                        style: textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: on ? green : GoldenityColors.text2)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  on
                      ? 'Setiap web order yang masuk langsung diterima, antrian dibuat, '
                          'dan printer diperintahkan mencetak otomatis.'
                      : 'Web order masuk sebagai "menunggu konfirmasi". Kasir menerima '
                          'manual di halaman Web Orders — struk & nota dapur baru dicetak setelah diterima.',
                  style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2, height: 1.4),
                ),
              ],
            ),
          ),
          if (on) ...[
            const SizedBox(height: GoldenitySpacing.md),
            Text('YANG DICETAK OTOMATIS SAAT PESANAN MASUK',
                style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: GoldenityColors.muted)),
            const SizedBox(height: GoldenitySpacing.sm),
            LayoutBuilder(builder: (context, c) {
              final twoCol = c.maxWidth > 560;
              final children = [
                _autoPrintChip(textTheme, Icons.receipt_long_rounded, 'Struk Kasir',
                    'Nomor order, item, total, metode bayar, info meja'),
                _autoPrintChip(textTheme, Icons.soup_kitchen_rounded, 'Nota Dapur',
                    'Item + varian + catatan khusus, nomor meja'),
              ];
              return twoCol
                  ? Row(children: [
                      Expanded(child: children[0]),
                      const SizedBox(width: GoldenitySpacing.md),
                      Expanded(child: children[1]),
                    ])
                  : Column(children: [
                      children[0],
                      const SizedBox(height: GoldenitySpacing.sm),
                      children[1],
                    ]);
            }),
            const SizedBox(height: GoldenitySpacing.md),
            Container(
              padding: const EdgeInsets.all(GoldenitySpacing.sm),
              decoration: BoxDecoration(
                color: const Color(0xFFFEFCE8),
                borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF854D0E)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Cetak dimulai 3–5 detik setelah pesanan dikonfirmasi oleh pelanggan.',
                      style: textTheme.bodySmall?.copyWith(color: const Color(0xFF854D0E)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _autoPrintChip(TextTheme textTheme, IconData icon, String title, String sub) {
    return Container(
      padding: const EdgeInsets.all(GoldenitySpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GoldenityRadius.sm),
        border: Border.all(color: GoldenityColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: GoldenityColors.primary),
          const SizedBox(width: GoldenitySpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(sub,
                    style: textTheme.bodySmall
                        ?.copyWith(color: GoldenityColors.muted, fontSize: 11, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrintersTab(
      BuildContext context, TextTheme textTheme, GoldenityBizColors biz) {
    _ensurePrinterControllers();
    const slots = PrinterSlotDto.values;

    return ListView(
      padding: const EdgeInsets.all(GoldenitySpacing.lg),
      children: [
        _buildWebOrderAutoCard(textTheme),
        const SizedBox(height: GoldenitySpacing.lg),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(GoldenityRadius.md),
            border: Border.all(color: GoldenityColors.border),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2))
            ],
          ),
          padding: const EdgeInsets.all(GoldenitySpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.print_rounded, color: biz.base),
                  const SizedBox(width: GoldenitySpacing.sm),
                  Text(
                    'Printer — ${_branchNameFor(_selectedBranchId ?? _loginBranchId)}',
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Setiap cabang punya printer sendiri — konfigurasi ini otomatis '
                'mengikuti cabang tempat Anda login.',
                style: textTheme.bodySmall?.copyWith(color: GoldenityColors.muted),
              ),
              const SizedBox(height: GoldenitySpacing.lg),
              if (_selectedBranchId == null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(GoldenitySpacing.xl),
                    child: Text(
                      'Memuat printer cabang…',
                      style: textTheme.bodySmall
                          ?.copyWith(color: GoldenityColors.text2),
                    ),
                  ),
                )
              else
                Column(
                  children: slots.map((slot) {
                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: GoldenitySpacing.md),
                      child: _PrinterSlotCard(
                        slot: slot,
                        slotLabel: _slotLabel(slot),
                        connType: _printerConnTypes[slot] ??
                            PrinterConnectionTypeDto.none,
                        addressCtrl: _printerAddressCtrls[slot] ??
                            TextEditingController(),
                        portCtrl:
                            _printerPortCtrls[slot] ?? TextEditingController(),
                        connTypeLabelFn: _connTypeLabel,
                        biz: biz,
                        textTheme: textTheme,
                        onConnTypeChanged: (t) =>
                            setState(() => _printerConnTypes[slot] = t),
                        paperWidthMm: _printerPaperWidths[slot] ?? 58,
                        onPaperWidthChanged: (w) =>
                            setState(() => _printerPaperWidths[slot] = w),
                        onSave: _loading ? null : () => _upsertPrinter(slot),
                        scanning: _scanning[slot] ?? false,
                        scanMsg: _scanMsg[slot] ?? '',
                        scannedDevices: _scannedDevices[slot] ?? const [],
                        onAutoScan:
                            _loading ? null : () => _runPrinterAutoScan(slot),
                        onApplyDevice: (d) => _applyScannedDevice(slot, d),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrinterSlotCard extends StatelessWidget {
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
  final VoidCallback? onSave;
  final bool scanning;
  final String scanMsg;
  final List<HardwareDeviceInfo> scannedDevices;
  final VoidCallback? onAutoScan;
  final ValueChanged<HardwareDeviceInfo> onApplyDevice;

  const _PrinterSlotCard({
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
    required this.onSave,
    required this.scanning,
    required this.scanMsg,
    required this.scannedDevices,
    required this.onAutoScan,
    required this.onApplyDevice,
  });

  @override
  Widget build(BuildContext context) {
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
                  color: Colors.white,
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
              return ChoiceChip(
                label: Text(connTypeLabelFn(t)),
                selected: selected,
                selectedColor: biz.base,
                onSelected: (_) => onConnTypeChanged(t),
                labelStyle: textTheme.labelSmall?.copyWith(
                  color: selected ? Colors.white : GoldenityColors.text2,
                  fontWeight: FontWeight.w700,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: GoldenitySpacing.md),
          // FIX (temuan Andre): pilihan ukuran kertas 58mm / 80mm — sebelumnya
          // sama sekali tidak ada di UI, struk selalu di-generate untuk 58mm.
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
              return ChoiceChip(
                label: Text('${mm}mm'),
                selected: selected,
                selectedColor: biz.base,
                onSelected: (_) => onPaperWidthChanged(mm),
                labelStyle: textTheme.labelSmall?.copyWith(
                  color: selected ? Colors.white : GoldenityColors.text2,
                  fontWeight: FontWeight.w700,
                ),
              );
            }).toList(),
          ),
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
              const SizedBox(width: 8),
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
                  foregroundColor: Colors.white,
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
