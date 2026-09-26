/// Server menjawab 401 — token login kedaluwarsa / tidak valid. Dibedakan dari
/// `Exception` biasa supaya poller bisa berhenti menembak API dengan token mati
/// dan memaksa login ulang, bukan diam-diam gagal tiap 6 detik (order web
/// tidak masuk, tidak ada notifikasi, tidak ada cetak — tanpa tanda apa pun).
class SessionExpiredException implements Exception {
  const SessionExpiredException([this.message = 'Sesi login telah habis. Silakan login kembali.']);
  final String message;

  @override
  String toString() => message;
}
