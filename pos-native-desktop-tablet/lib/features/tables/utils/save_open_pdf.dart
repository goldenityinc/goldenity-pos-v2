import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Resolve folder writable dengan 4 level fallback:
/// 1. Downloads (utama Windows/Linux)
/// 2. External Storage (khusus Android, scoped-storage aware)
/// 3. Application Documents (cross-platform fallback)
/// 4. Temporary Directory (last resort)
Future<Directory> _resolveWritableDirectory() async {
  try {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads;
  } catch (_) {}

  if (Platform.isAndroid) {
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) return ext;
    } catch (_) {}
  }

  try {
    final docs = await getApplicationDocumentsDirectory();
    return docs;
  } catch (_) {
    return getTemporaryDirectory();
  }
}

/// Simpan `bytes` sebagai file di folder Downloads (fallback: Documents / Temp)
/// lalu buka dengan aplikasi bawaan OS. Return path file yang tersimpan.
Future<String> savePdfAndOpen(List<int> bytes, String filename) async {
  final dir = await _resolveWritableDirectory();
  final safeName = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  final file = File('${dir.path}${Platform.pathSeparator}$safeName');
  await file.writeAsBytes(bytes, flush: true);

  try {
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', file.path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [file.path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [file.path]);
    } else if (Platform.isAndroid) {
      await OpenFilex.open(file.path, type: 'application/pdf');
    }
  } catch (_) {
    // Buka gagal → biarkan; caller tetap menampilkan path tersimpan.
  }
  return file.path;
}
