# 🎨 TASK PANJANG UNTUK TRAE — Audit & Perbaikan UI Menyeluruh (Goldenity POS V2)

> **Dibuat oleh:** Klaude (AI code auditor)
> **Tanggal:** 2026-09-07
> **Untuk:** Trae (menjalankan ini sebagai task panjang mandiri, dikerjakan 1-per-1 selagi Andre tidak online)
> **Instruksi asal dari Andre:** *"Sebelum kita lanjut perbaiki logic aku ingin kita perbaiki semua UI dulu supaya tidak rusak kedepannya juga"* — jadi prioritas SEKARANG adalah UI/layout stability di SELURUH aplikasi, bukan menambah fitur baru atau mengubah business logic.

---

## 📋 Cara pakai file task ini

1. **Kerjakan checklist di bawah SATU PER SATU, dari atas ke bawah** (sudah diurutkan berdasarkan prioritas — Bagian 1 = anti-pattern sistemik yang paling sering bikin bug berulang, Bagian 2 = checklist per-layar, Bagian 3 = item spesifik yang sudah diketahui).
2. **Centang `[x]` setiap item yang selesai DAN sudah diverifikasi jalan** (bukan cuma "menurut saya sudah benar" — harus benar-benar di-run di `flutter run -d windows` dan dicek visual, atau minimal `flutter analyze` bersih tanpa warning terkait).
3. **Setelah tiap item selesai, tulis entri baru di `PROJECT_LOG.md`** (paling atas, ikuti format yang sudah ada) — jangan tunggu sampai semua task selesai baru menulis satu entri besar. Satu entri kecil per item lebih baik daripada satu entri raksasa di akhir, supaya kalau sesi terputus di tengah jalan, riwayatnya tetap jelas.
4. **JANGAN klaim "✅ FIXED" tanpa verifikasi** — ini aturan permanen proyek ini (lihat header `PROJECT_LOG.md`). Kalau ragu apakah sudah benar-benar teruji, tulis "🟡 SUDAH DIUBAH, BELUM DIVERIFIKASI VISUAL" bukan "✅ FIXED".
5. **Kalau ada file yang barusan diedit Klaude/proses lain** (cek mtime sebelum edit kalau memungkinkan), jangan menimpa perubahan itu — baca ulang isi terbaru dulu sebelum mengedit, supaya tidak saling menghapus pekerjaan.
6. **JANGAN ubah business logic / kalkulasi apapun di task ini** (harga, pajak, quick-cash, dsb) kecuali item tsb eksplisit soal itu — fokus MURNI ke layout, spacing, responsiveness, visual consistency. Kalau menemukan bug logic saat audit UI, JANGAN diperbaiki di task ini — catat saja di `PROJECT_LOG.md` sebagai temuan terpisah untuk dikerjakan nanti, supaya scope task ini tetap UI-only dan mudah diverifikasi.
7. Kalau mentok/tidak yakin/butuh keputusan desain dari Andre untuk satu item spesifik → **skip item itu, lanjut ke item berikutnya**, jangan berhenti total. Tulis di `PROJECT_LOG.md` bagian mana yang di-skip dan kenapa, supaya Andre bisa jawab saat online lagi.

---

## Bagian 1 — Anti-pattern sistemik yang WAJIB di-audit di SELURUH layar

Ini adalah pola bug yang sudah ditemukan BERULANG KALI di proyek ini (lihat riwayat `PROJECT_LOG.md`). Karena polanya sama, kemungkinan besar ada di layar-layar lain juga yang belum ditemukan/dilaporkan Andre. Audit SEMUA file di `lib/features/**/screens/*.dart` dan `lib/shared/**/*.dart` untuk pola-pola ini:

### 1.1 — `Column` dengan blank space di bawah (root cause bug product card yang sudah diperbaiki)
**Pola bug:** `Column` (default `mainAxisSize.max`) di dalam `Stack`/`Container` berukuran tetap (misal karena grid `childAspectRatio` atau `SizedBox` fixed height) akan SELALU mengambil semua ruang vertikal yang tersedia, bukan cuma sebesar total children-nya. Kalau tidak ada child `Expanded`/`Flexible` yang menyerap sisa ruang, hasilnya blank space kosong di bagian bawah (biasanya di bawah children terakhir yang fixed-size, seperti tombol +/- qty).
**Cara cek:** Cari semua `Column(` yang berada di dalam `Container` dengan `height` tetap, atau di dalam `GridView`/`SliverGrid` dengan `childAspectRatio` fixed. Kalau isinya campuran fixed-size widgets TANPA ada `Expanded` di salah satu child-nya → berpotensi bug ini.
**Contoh fix yang sudah dilakukan (jadikan referensi pola):** `lib/features/inventory/screens/product_list_screen.dart` — `_ProductCard`, gambar placeholder diganti dari fixed-size/`AspectRatio` jadi `Expanded` supaya menyerap sisa ruang vertikal apa pun ukuran grid cell-nya.
**Layar yang WAJIB dicek** (grep manual, baca strukturnya, cek dengan `flutter run` apakah ada gap aneh):
- [ ] `lib/features/inventory/screens/product_management_list_screen.dart`
- [ ] `lib/features/inventory/screens/category_management_screen.dart`
- [ ] `lib/features/inventory/screens/product_builder_screen.dart`
- [ ] `lib/features/inventory/widgets/add_product_bottomsheet.dart`
- [ ] `lib/features/sales/screens/checkout_screen.dart`
- [ ] `lib/features/sales/screens/sales_history_screen.dart`
- [ ] `lib/features/sales/screens/payment_success_screen.dart`
- [ ] `lib/features/dashboard/screens/dashboard_screen.dart`
- [ ] `lib/features/finance/screens/finance_screen.dart`
- [ ] `lib/features/cashier_shift/screens/cashier_shift_screen.dart`
- [ ] `lib/features/settings/screens/settings_screen.dart`
- [ ] `lib/shared/shell/goldenity_cart_panel.dart`
- [ ] `lib/shared/shell/goldenity_payment_modal.dart`
- [ ] `lib/shared/shell/goldenity_sidebar.dart`
- [ ] `lib/shared/widgets/*.dart` (semua reusable widget — kalau ada bug di sini, dampaknya ke banyak layar sekaligus)

### 1.2 — `SliverGridDelegateWithMaxCrossAxisExtent`/`SliverGridDelegateWithFixedCrossAxisCount` dengan `childAspectRatio` yang tidak sesuai konten
**Pola bug:** `childAspectRatio` menentukan tinggi cell TETAP terlepas dari berapa pun tinggi konten aslinya → sumber utama blank space ATAU overflow (`RenderFlex overflowed by X pixels` di console) tergantung arah ketidakcocokannya.
**Cara cek:** Cari semua `SliverGridDelegateWith*(` di codebase, cek nilai `childAspectRatio`-nya, lalu run app dan bandingkan dengan behaviour di V1 (reference UX, lihat Bagian 2). Kalau ada `Expanded` di dalam children Column-nya sudah lebih aman (auto-adjust), tapi tetap cek visual di berbagai ukuran window.
- [ ] Grep semua pemakaian `childAspectRatio` di `lib/` dan daftar di sini file+line-nya sebelum mulai fix (isi list ini saat audit).

### 1.3 — Widget dengan lebar/tinggi hardcoded (px tetap) yang seharusnya responsif
**Pola bug:** `Container(width: 340)` dsb, tidak menyesuaikan ukuran window/layar → terlihat "kekecilan"/"kegedean" di resolusi berbeda. Ini penyebab bug cart panel yang sudah diperbaiki (`goldenity_cart_panel.dart`, sekarang pakai `MediaQuery` + `clamp()`).
**Cara cek:** Grep `width: ` dan `height: ` dengan angka literal (bukan dari `GoldenitySpacing`/token) di semua file `screens/` dan `shell/`. Untuk setiap match, pertimbangkan apakah nilai itu SEHARUSNYA proporsional terhadap `MediaQuery.of(context).size` (seperti panel/sidebar/modal width) atau memang boleh tetap (seperti icon size 24px, itu OK).
**Prioritas tinggi:** panel/sidebar/modal/dialog width & height — ini yang paling kentara kalau salah di layar besar (desktop/tablet landscape).
- [ ] `lib/shared/shell/goldenity_sidebar.dart` — cek lebar sidebar, apakah proporsional di window kecil vs besar.
- [ ] `lib/shared/widgets/goldenity_bottom_sheet.dart` — cek lebar/tinggi bottom sheet di berbagai ukuran window.
- [ ] `lib/features/inventory/widgets/add_product_bottomsheet.dart` — sama.
- [ ] `lib/shared/widgets/goldenity_cash_tender_modal.dart` — cek apakah modal ini masih dipakai (ada `goldenity_payment_modal.dart` yang baru) — kalau sudah tidak dipakai/dead code, laporkan ke Andre, JANGAN dihapus sendiri tanpa konfirmasi.

### 1.4 — Konsistensi spacing & warna (pakai token, bukan angka mentah)
**Cara cek:** Grep `EdgeInsets.all(` / `EdgeInsets.symmetric(` / `SizedBox(height:` / `SizedBox(width:` dengan angka literal yang BUKAN kelipatan token `GoldenitySpacing` (lihat `lib/core/design/goldenity_spacing.dart` untuk daftar token yang valid). Juga grep `Color(0x` / `Colors.` langsung di file screen (seharusnya semua warna lewat `GoldenityColors`, lihat `lib/core/design/goldenity_colors.dart`).
**Kenapa penting:** Andre sudah bilang UI harus "tidak rusak kedepannya" — angka magic number yang tersebar bikin desain gampang jadi tidak konsisten tiap kali ada perubahan kecil.
- [ ] Audit seluruh `lib/features/**/screens/*.dart` untuk magic number spacing/warna, ganti ke token yang sesuai KALAU nilainya dekat dengan salah satu token yang ada (jangan paksa kalau memang butuh nilai custom yang wajar).

### 1.5 — Overflow & responsiveness di ukuran window kecil (bukan cuma fullscreen)
**Cara cek:** `flutter run -d windows`, lalu **resize window jadi lebih kecil dari biasanya** (tablet-ish, ~1024x768 dan ~1280x800) untuk tiap layar utama. Cek apakah ada `RenderFlex overflowed` di console/log, atau elemen yang saling tumpang tindih secara visual.
- [ ] Test di ukuran window kecil: Dashboard, Product List (POS tab), Cart Panel + Payment Modal, Settings, Sales History, Cashier Shift.

---

## Bagian 2 — Referensi UX: bandingkan dengan V1

Andre ingin V2 mengikuti pola UI/UX V1 yang sudah battle-tested. Lokasi V1 (read-only, JANGAN diedit — cuma untuk referensi visual/behavior):
`E:\Goldenity\goldenity-pointofsales-app\lib\`

Layar V1 yang relevan sebagai pembanding langsung:
- `screens/table_management_screen.dart`, `widgets/retail_sales_layout.dart`, `widgets/retail_sales/product_grid_section.dart`, `widgets/retail_sales/cart_summary_section.dart` → pembanding untuk POS/product-grid + cart panel V2.
- `core/sales/smart_cash_checkout.dart` → SUDAH dipakai sebagai sumber kebenaran quick-cash (sudah diporting Klaude ke V2, lihat entri log terbaru — bagian ini TIDAK perlu disentuh lagi).
- `screens/printer_settings_screen.dart` → pembanding untuk `lib/features/settings/screens/settings_screen.dart` (bagian printer config).
- `widgets/transaction_detail_modal.dart` → pembanding untuk modal-modal transaksi/struk di V2.

**Instruksi:** untuk tiap layar V2 di Bagian 1, buka juga file V1 yang setara (kalau ada), bandingkan spacing/hierarchy visual/urutan elemen — BUKAN untuk menyalin 100% (V2 punya desain system sendiri, `GoldenityColors`/`GoldenityTheme`), tapi untuk memastikan pola interaksi yang sudah terbukti nyaman dipakai kasir tidak hilang di V2 (misal: urutan tombol, ukuran tap-target, dsb).

---

## Bagian 3 — Item spesifik yang SUDAH diketahui (dari laporan Andre & audit Klaude sebelumnya)

Sebagian sudah diperbaiki Klaude — **WAJIB diverifikasi ulang oleh Trae dengan `flutter run` sungguhan** (Klaude tidak punya akses compiler/toolchain sesi ini, jadi semua perbaikan Klaude berstatus "belum di-compile"):

- [ ] **Product card blank space** — sudah diedit (`product_list_screen.dart`, `Expanded` untuk image placeholder). **Verifikasi:** jalankan app, lihat tab produk, pastikan tidak ada gap kosong di bawah tombol +/- qty di card manapun, di berbagai ukuran window.
- [ ] **Cart panel width terasa kekecilan** — sudah diedit (`goldenity_cart_panel.dart`, width responsif `MediaQuery` + `clamp(340, 420)`). **Verifikasi:** cek di layar lebar (monitor besar) apakah cart panel sekarang terasa proporsional, bukan cuma pas di satu resolusi tertentu.
- [ ] **Quick cash suggestion salah** (28.000 loncat ke 50.000, seharusnya ada 30.000 dulu) — sudah diporting ulang 1:1 dari algoritma asli V1 (`smart_cash_checkout.dart`) ke `goldenity_payment_modal.dart`. **Verifikasi:** buka payment modal, input berbagai nominal (15.000, 20.000, 16.500, 28.000, dan angka lain sembarang), pastikan chip yang muncul = pembulatan ke atas ke kelipatan 10rb/50rb/100rb (BUKAN daftar pecahan uang).
- [ ] **Receipt printing tidak jalan setelah checkout** — sudah diedit beberapa kali (bridge `_convertPrinterProfileToHwConfig`, fetch printer config lewat `settingsApiServiceProvider.listPrinters()`, urutan resolve printer sebelum generate ESC/POS bytes). **INI PALING KRITIS untuk diverifikasi dengan printer fisik sungguhan** — Klaude sama sekali tidak bisa menguji ini (butuh hardware). Kalau masih gagal print, ini prioritas #1 untuk Trae investigasi dengan device nyata + log error yang muncul.
- [ ] **Ukuran kertas 58mm/80mm belum ada di setting** — sudah ditambahkan UI pilihan di `settings_screen.dart` (`ChoiceChip` 58mm/80mm) + disimpan ke `SharedPreferences` (LOCAL ke device ini saja, BELUM sinkron ke backend/database — backend Prisma schema belum punya kolom untuk ini). **Verifikasi:** pilih 80mm di settings, lakukan transaksi, cek apakah struk yang di-generate benar-benar pakai lebar 80mm (bukan default 58mm).
- [ ] **Receipt footer belum bisa di-setting** — sudah di-wire (`cart_provider.dart` cache `receiptFooter` dari `settingsApi.getStore()`, dipakai di `_mapSaleToReceipt()` di `goldenity_payment_modal.dart`). **Verifikasi:** ubah teks footer di Settings, lakukan transaksi, cek apakah teks itu benar-benar muncul di struk yang dicetak/di-generate.
- [ ] **Cart items tidak muncul di summary payment modal** — dilaporkan sudah diperbaiki round pertama (lihat entri log lebih lama). **Verifikasi ulang** karena ada indikasi file ini sempat divergen/di-overwrite proses lain di tengah sesi — pastikan fix-nya masih ada di kode saat ini, jangan asumsi otomatis masih berlaku.

---

## Bagian 4 — Setelah Bagian 1–3 selesai

Baru lanjut ke perbaikan LOGIC (bukan UI) yang masih outstanding — tapi ini di luar scope task ini, tunggu instruksi baru dari Andre atau Klaude soal urutan prioritas logic fixes berikutnya. Jangan mulai kerjakan logic baru sebelum checklist UI di atas benar-benar tuntas dan terverifikasi, sesuai instruksi eksplisit Andre.

---

## 🔁 Checklist verifikasi akhir sebelum menandai task ini "selesai total"

- [ ] `flutter analyze` dijalankan di root `pos-native-desktop-tablet/`, tidak ada warning/error baru yang muncul akibat perubahan task ini.
- [ ] App di-`flutter run -d windows`, dicoba end-to-end: login → pilih produk → cart → payment (cash) → checkout → cek struk — di MINIMAL 2 ukuran window berbeda.
- [ ] Semua entri PROJECT_LOG.md sudah ditulis per item (bukan cuma dicentang di file ini).
- [ ] Daftar item yang di-skip (jika ada) sudah dicatat jelas di PROJECT_LOG.md dengan alasan, supaya Andre bisa memutuskan saat online kembali.
