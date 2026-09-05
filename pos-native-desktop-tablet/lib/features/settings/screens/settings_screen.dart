import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../core/models/branch_profile_extended.dart';
import '../../../core/models/printer_config_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../inventory/providers/product_list_provider.dart';
import '../../sales/providers/cart_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with SingleTickerProviderStateMixin {
  bool _loading = false;
  String _errMsg = '';

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
  final GlobalKey<FormState> _storeFormKey = GlobalKey<FormState>();

  List<BranchWithPrintersProfile> _branches = [];
  final TextEditingController _branchNameCtrl = TextEditingController();
  final TextEditingController _branchQrisCtrl = TextEditingController();
  final GlobalKey<FormState> _branchFormKey = GlobalKey<FormState>();

  String? _selectedBranchId;
  final Map<PrinterSlotDto, TextEditingController> _printerAddressCtrls = {};
  final Map<PrinterSlotDto, TextEditingController> _printerPortCtrls = {};
  final Map<PrinterSlotDto, PrinterConnectionTypeDto> _printerConnTypes = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadStore();
      await _loadBranches();
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
        if (_storeLogoCtrl.text.trim().isNotEmpty) 'logoUrl': _storeLogoCtrl.text.trim(),
        if (_storeAddressCtrl.text.trim().isNotEmpty) 'address': _storeAddressCtrl.text.trim(),
        if (_storePhoneCtrl.text.trim().isNotEmpty) 'phone': _storePhoneCtrl.text.trim(),
        if (_storeReceiptFooterCtrl.text.trim().isNotEmpty) 'receiptFooter': _storeReceiptFooterCtrl.text.trim(),
        if (_storeQrisUrlCtrl.text.trim().isNotEmpty) 'qrisImageUrl': _storeQrisUrlCtrl.text.trim(),
        'allowPayAtCashier': _storeAllowPayAtCashier,
        'isPaymentProofMandatory': _storeIsPaymentProofMandatory,
        'blindShiftClose': _blindShiftClose,
        'taxEnabled': _taxEnabled,
        'taxRatePercentage': _taxRatePercentage.toInt(),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GoldenityRadius.xl)),
        title: Text(existing == null ? 'Tambah Cabang Baru' : 'Edit Cabang ${existing.name}'),
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
                validator: (v) => v!.trim().length < 3 ? 'Minimal 3 karakter' : null,
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
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: biz.base),
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
                    qrisImageUrl: _branchQrisCtrl.text.trim().isNotEmpty ? _branchQrisCtrl.text.trim() : null,
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
            child: const Text('Simpan'),
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
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: GoldenityColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Hapus'),
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
      final data = await settingsApi.removeBranch(authToken: token, branchId: b.id);
      final softDeleted = data['softDeleted'] as bool?;
      final affectedSales = data['affectedSales'] as int? ?? 0;
      final message = data['message'] as String?;

      if (mounted) {
        if (softDeleted == false && affectedSales > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: GoldenityColors.warning,
              content: Text(message ?? 'Masih dipakai $affectedSales transaksi'),
            ),
          );
        } else if (softDeleted == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: GoldenityColors.warning,
              content: Text(message ?? 'Cabang di-nonaktifkan karena masih ada data'),
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
      final list = await settingsApi.listPrinters(authToken: token, branchId: branchId);
      if (mounted) {
        for (final p in list) {
          _printerConnTypes[p.slot] = p.connectionType;
          _printerAddressCtrls[p.slot]?.text = p.address ?? '';
          _printerPortCtrls[p.slot]?.text = p.port != null ? '${p.port}' : '';
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
      final port = portRaw != null && portRaw.isNotEmpty ? int.tryParse(portRaw) : null;

      await settingsApi.upsertPrinter(
        authToken: token,
        branchId: _selectedBranchId!,
        slot: slot,
        connectionType: connType,
        address: address != null && address.isNotEmpty ? address : null,
        port: port,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final biz = theme.extension<GoldenityBizColors>() ?? GoldenityBizColors.fnb;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: GoldenityColors.surface,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pengaturan', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                'Kelola cabang, printer & informasi toko',
                style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2, fontWeight: FontWeight.w600),
              ),
            ],
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
                padding: const EdgeInsets.only(right: GoldenitySpacing.md, top: GoldenitySpacing.sm, bottom: GoldenitySpacing.sm),
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : () => _showBranchDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: biz.base,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.md, vertical: GoldenitySpacing.sm),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GoldenityRadius.md)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text('Tambah Cabang', style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
                ),
              ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: biz.base,
            unselectedLabelColor: GoldenityColors.text2,
            indicatorColor: biz.base,
            labelStyle: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
            tabs: const [
              Tab(text: 'Info Toko'),
              Tab(text: 'Daftar Cabang'),
              Tab(text: 'Printer per Cabang'),
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
                          const Icon(Icons.error_outline_rounded, size: 48, color: GoldenityColors.error),
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
                    ],
                  ),
      ),
    );
  }

  Widget _buildStoreInfoTab(BuildContext context, TextTheme textTheme, GoldenityBizColors biz) {
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
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            padding: const EdgeInsets.all(GoldenitySpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.store_rounded, color: biz.base),
                    const SizedBox(width: GoldenitySpacing.sm),
                    Text(
                      'Informasi Toko',
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
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
                  validator: (v) => v!.trim().isEmpty ? 'Nama toko wajib diisi' : null,
                ),
                const SizedBox(height: GoldenitySpacing.md),
                TextFormField(
                  controller: _storeLogoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL Logo Toko',
                    hintText: 'https://.../logo.png',
                  ),
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
                TextFormField(
                  controller: _storeQrisUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL Gambar QRIS',
                    hintText: 'https://.../qris.jpg',
                  ),
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
                            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: GoldenitySpacing.xs),
                          Text(
                            'Jika aktif, pelanggan bisa bayar langsung di kasir',
                            style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _storeAllowPayAtCashier,
                      onChanged: (v) => setState(() => _storeAllowPayAtCashier = v),
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
                            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: GoldenitySpacing.xs),
                          Text(
                            'Jika aktif, wajib upload bukti transfer untuk non-tunai',
                            style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _storeIsPaymentProofMandatory,
                      onChanged: (v) => setState(() => _storeIsPaymentProofMandatory = v),
                      activeTrackColor: biz.base.withValues(alpha: 0.5),
                      activeThumbColor: biz.base,
                    ),
                  ],
                ),
                const SizedBox(height: GoldenitySpacing.md),
                SwitchListTile.adaptive(
                  title: Text(
                    'Blind Close Shift Kasir',
                    style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Jika ON: kasir tidak melihat perkiraan uang sistem & selisih kasir saat buka/tutup shift (mode blind close).',
                    style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2),
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
                    style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Jika ON: transaksi akan dikenakan pajak sesuai persentase di bawah.',
                    style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2),
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
                      if (n != null) setState(() => _taxRatePercentage = n.clamp(0, 100));
                    },
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                  ),
                ),
                const SizedBox(height: GoldenitySpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _updateStore,
                    style: FilledButton.styleFrom(
                      backgroundColor: biz.base,
                      padding: const EdgeInsets.symmetric(vertical: GoldenitySpacing.md),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GoldenityRadius.md)),
                    ),
                    icon: const Icon(Icons.save_rounded),
                    label: Text('Simpan Pengaturan', style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchesTab(BuildContext context, TextTheme textTheme, GoldenityBizColors biz) {
    if (_branches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(GoldenitySpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_tree_outlined, size: 64, color: biz.base.withValues(alpha: 0.6)),
              const SizedBox(height: GoldenitySpacing.md),
              Text('Belum ada cabang', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: GoldenitySpacing.xs),
              Text(
                'Tekan "Tambah Cabang" di pojok kanan atas untuk mulai.',
                style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadBranches,
      color: biz.base,
      child: ListView.separated(
        padding: const EdgeInsets.all(GoldenitySpacing.lg),
        itemCount: _branches.length,
        separatorBuilder: (_, __) => const SizedBox(height: GoldenitySpacing.sm),
        itemBuilder: (context, i) {
          final b = _branches[i];
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(GoldenityRadius.md),
              border: Border.all(color: GoldenityColors.border),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
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
                    borderRadius: BorderRadius.circular(GoldenityRadius.md),
                  ),
                  child: Icon(Icons.storefront_rounded, color: biz.dark, size: 28),
                ),
                const SizedBox(width: GoldenitySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        b.name,
                        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (b.qrisImageUrl != null && b.qrisImageUrl!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: GoldenityColors.successLight,
                            borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.qr_code_2_rounded, size: 14, color: GoldenityColors.success),
                              const SizedBox(width: 4),
                              Text(
                                'QRIS tersedia',
                                style: textTheme.labelSmall?.copyWith(color: GoldenityColors.success, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: GoldenityColors.surface2,
                            borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                          ),
                          child: Text(
                            'Belum ada QRIS',
                            style: textTheme.labelSmall?.copyWith(color: GoldenityColors.text2, fontWeight: FontWeight.w700),
                          ),
                        ),
                      const SizedBox(height: GoldenitySpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: GoldenityColors.surface2,
                          borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                        ),
                        child: Text(
                          '${b.printerConfigs.length} printer dikonfigurasi',
                          style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2),
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
                      onPressed: _loading ? null : () => _showBranchDialog(existing: b),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Hapus',
                      color: GoldenityColors.error,
                      onPressed: _loading ? null : () => _confirmDeleteBranch(b),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPrintersTab(BuildContext context, TextTheme textTheme, GoldenityBizColors biz) {
    _ensurePrinterControllers();
    const slots = PrinterSlotDto.values;

    return ListView(
      padding: const EdgeInsets.all(GoldenitySpacing.lg),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(GoldenityRadius.md),
            border: Border.all(color: GoldenityColors.border),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
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
                    'Konfigurasi Printer per Cabang',
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: GoldenitySpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _selectedBranchId,
                decoration: const InputDecoration(
                  labelText: 'Pilih Cabang',
                  hintText: 'Pilih cabang untuk kelola printer',
                ),
                items: _branches
                    .map((b) => DropdownMenuItem<String>(
                          value: b.id,
                          child: Text(b.name),
                        ))
                    .toList(),
                onChanged: _loading
                    ? null
                    : (v) {
                        setState(() => _selectedBranchId = v);
                        if (v != null && v.isNotEmpty) {
                          _loadPrintersForBranch(v);
                        }
                      },
              ),
              const SizedBox(height: GoldenitySpacing.lg),
              if (_selectedBranchId == null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(GoldenitySpacing.xl),
                    child: Text(
                      'Silakan pilih cabang terlebih dahulu',
                      style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2),
                    ),
                  ),
                )
              else
                Column(
                  children: slots.map((slot) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: GoldenitySpacing.md),
                      child: _PrinterSlotCard(
                        slot: slot,
                        slotLabel: _slotLabel(slot),
                        connType: _printerConnTypes[slot] ?? PrinterConnectionTypeDto.none,
                        addressCtrl: _printerAddressCtrls[slot] ?? TextEditingController(),
                        portCtrl: _printerPortCtrls[slot] ?? TextEditingController(),
                        connTypeLabelFn: _connTypeLabel,
                        biz: biz,
                        textTheme: textTheme,
                        onConnTypeChanged: (t) => setState(() => _printerConnTypes[slot] = t),
                        onSave: _loading ? null : () => _upsertPrinter(slot),
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
  final VoidCallback? onSave;

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
    required this.onSave,
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
                  style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Chip(
                backgroundColor: connType == PrinterConnectionTypeDto.none ? GoldenityColors.surface : biz.light,
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
                label: Text(
                  connTypeLabelFn(connType),
                  style: textTheme.labelSmall?.copyWith(
                    color: connType == PrinterConnectionTypeDto.none ? GoldenityColors.text2 : biz.dark,
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
          TextFormField(
            controller: addressCtrl,
            enabled: connType != PrinterConnectionTypeDto.none,
            decoration: const InputDecoration(
              labelText: 'Alamat / MAC / IP Address',
              hintText: 'Contoh: 192.168.1.100 atau AA:BB:CC:DD:EE:FF',
            ),
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
          const SizedBox(height: GoldenitySpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onSave,
              style: FilledButton.styleFrom(
                backgroundColor: biz.base,
                padding: const EdgeInsets.symmetric(vertical: GoldenitySpacing.sm),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GoldenityRadius.md)),
              ),
              icon: const Icon(Icons.save_rounded, size: 18),
              label: Text('Simpan Slot $slotLabel', style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}
