import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Simpan `bytes` sebagai file di folder Downloads (fallback: Documents / Temp)
/// lalu buka dengan aplikasi bawaan OS. Return path file yang tersimpan.
Future<String> savePdfAndOpen(List<int> bytes, String filename) async {
  Directory dir;
  try {
    dir = (await getDownloadsDirectory()) ??
        await getApplicationDocumentsDirectory();
  } catch (_) {
    dir = await getTemporaryDirectory();
  }
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
    }
  } catch (_) {
    // Buka gagal → biarkan; caller tetap menampilkan path tersimpan.
  }
  return file.path;
}
