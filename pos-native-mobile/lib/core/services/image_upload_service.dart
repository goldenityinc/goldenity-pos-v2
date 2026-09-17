import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/api_constants.dart';

/// Hasil pilih file gambar dari disk.
class PickedImage {
  final String path;
  final String filename;
  final List<int> bytes;
  final String mime;

  const PickedImage({
    required this.path,
    required this.filename,
    required this.bytes,
    required this.mime,
  });

  int get sizeBytes => bytes.length;
}

const Map<String, String> _mimeByExt = {
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'webp': 'image/webp',
  'gif': 'image/gif',
};

/// Upload gambar (logo toko, QRIS statis, foto produk) — Issue #3.
/// Menggantikan input URL manual: user pilih file dari komputer, di-upload ke
/// backend (`POST /api/v1/uploads`, JSON base64), balikannya URL publik yang
/// disimpan ke field (mis. `Tenant.logoUrl`).
class ImageUploadService {
  ImageUploadService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const int maxBytes = 6 * 1024 * 1024;

  /// Pilih gambar dari disk (Windows) atau galeri (Android). Return null
  /// kalau user batal.
  Future<PickedImage?> pickImageFromDisk() async {
    if (Platform.isAndroid) return _pickImageAndroid();
    if (!Platform.isWindows) {
      throw UnsupportedError('Pilih gambar hanya didukung di Windows desktop / Android untuk saat ini.');
    }
    return _pickImageWindows();
  }

  /// BUG FIX: sebelumnya method ini SELALU throw UnsupportedError kalau bukan
  /// Windows — upload QRIS/logo/foto produk 100% tidak bisa jalan sama sekali
  /// di APK Android (tidak pernah diimplementasikan), padahal tablet ini
  /// sekarang juga di-build untuk Android. Pakai `image_picker` (galeri
  /// bawaan Android, tidak butuh permission runtime tambahan di Android 13+
  /// karena lewat system Photo Picker).
  Future<PickedImage?> _pickImageAndroid() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (xfile == null) return null;

    final bytes = await xfile.readAsBytes();
    if (bytes.isEmpty) throw Exception('File kosong.');
    if (bytes.length > maxBytes) {
      throw Exception(
        'Ukuran ${(bytes.length / 1024 / 1024).toStringAsFixed(1)}MB melebihi batas 6MB.',
      );
    }
    final name = xfile.name.isNotEmpty ? xfile.name : xfile.path.split('/').last;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    final mime = _mimeByExt[ext] ?? xfile.mimeType;
    if (mime == null || !_mimeByExt.containsValue(mime)) {
      throw Exception('Format tidak didukung (hanya png / jpg / webp / gif).');
    }
    return PickedImage(path: xfile.path, filename: name, bytes: bytes, mime: mime);
  }

  Future<PickedImage?> _pickImageWindows() async {
    const script = r'''
Add-Type -AssemblyName System.Windows.Forms | Out-Null
$dlg = New-Object System.Windows.Forms.OpenFileDialog
$dlg.Title = 'Pilih Gambar'
$dlg.Filter = 'Gambar (*.png;*.jpg;*.jpeg;*.webp;*.gif)|*.png;*.jpg;*.jpeg;*.webp;*.gif'
$dlg.Multiselect = $false
if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { [Console]::Out.Write($dlg.FileName) }
''';
    final res = await Process.run(
      'powershell',
      ['-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-Command', script],
    );
    final path = (res.stdout as String).trim();
    if (path.isEmpty) return null;

    final file = File(path);
    if (!await file.exists()) {
      throw Exception('File tidak ditemukan: $path');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw Exception('File kosong.');
    if (bytes.length > maxBytes) {
      throw Exception(
        'Ukuran ${(bytes.length / 1024 / 1024).toStringAsFixed(1)}MB melebihi batas 6MB.',
      );
    }
    final name = path.split(RegExp(r'[\\/]')).last;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    final mime = _mimeByExt[ext];
    if (mime == null) {
      throw Exception('Format tidak didukung (hanya png / jpg / webp / gif).');
    }
    return PickedImage(path: path, filename: name, bytes: bytes, mime: mime);
  }

  /// Kirim gambar ke backend, kembalikan URL publik.
  Future<String> upload({
    required PickedImage image,
    required String authToken,
    String kind = 'other',
  }) async {
    final resp = await _client
        .post(
          ApiConstants.uploadsEndpoint(),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
          body: jsonEncode({
            'filename': image.filename,
            'mime': image.mime,
            'kind': kind,
            'dataBase64': base64Encode(image.bytes),
          }),
        )
        .timeout(const Duration(seconds: 30));

    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {}

    if ((resp.statusCode == 200 || resp.statusCode == 201) &&
        body != null &&
        body['success'] == true) {
      final data = body['data'];
      final url = data is Map ? data['url']?.toString() : null;
      if (url != null && url.isNotEmpty) return url;
      throw Exception('Response upload tidak memuat url.');
    }
    final msg = body?['error']?.toString() ??
        body?['message']?.toString() ??
        'Upload gagal (HTTP ${resp.statusCode})';
    throw Exception(msg);
  }

  /// Pilih + upload sekaligus. Return null kalau user batal.
  Future<String?> pickAndUpload({
    required String authToken,
    String kind = 'other',
  }) async {
    final picked = await pickImageFromDisk();
    if (picked == null) return null;
    return upload(image: picked, authToken: authToken, kind: kind);
  }
}
