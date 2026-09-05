# 🎨 DESIGN TOKEN DOCUMENT — Goldenity POS V2 (Fase 1: F&B)

**Sumber:** Figma Make "POS System Design System" (`yyxgjqqxUa8RYlpA74s9g2`) — v1.0, Developer Handoff, Flutter + Web.
**Scope render Fase 1:** POS Native tablet (F&B). Token untuk Retail/Service/Web Order/KDS/Signage tetap didokumentasikan di sini (karena sudah final di Figma) tapi implementasinya menyusul di fase berikutnya.

> **📋 Riwayat verifikasi terhadap Figma:**
> - **[2026-09-03]** — Dibaca ULANG langsung dari source code asli Figma Make (`src/DesignSystem.tsx`, `src/index.css`, `src/data/shared.ts`, seluruh Section 01–10) via `get_design_context`, bukan dari screenshot/ingatan. Ditemukan & dikoreksi: tabel Tipografi (Bagian 2) punya beberapa size/weight yang meleset dari sumber asli; Motion (Bagian 6) kurang 2 animasi (`slideDown`, `ripple`); Komponen (Bagian 5) kurang 3 spec (`FloatingBottomBar`, `KdsTimerBadge`, `KanbanColumn`). Semua bagian lain (Warna, Spacing, Radius/Elevation, Biz Colors, KDS Timer States, Dark Surfaces, CSS Export) dicek ulang dan **cocok 100%** dengan versi sebelumnya di dokumen ini — tidak ada perubahan.
> - File ini juga sekarang mencakup source referensi tambahan yang ditemukan saat verifikasi: `src/data/shared.ts` (dummy data F&B/Retail/Service untuk keperluan seed/testing UI, bukan token desain — tidak didokumentasikan di sini) dan 8 file view referensi (`RetailPOS.tsx`, `ServicePOS.tsx`, `KitchenDisplay.tsx`, `BackOffice.tsx`, `InventoryBuilder.tsx`, `MobileApp.tsx`, `MobileWebOrder.tsx`, `WebOrdering.tsx`, `OrderStatus.tsx`, `QueueSignage.tsx`) — berguna sebagai referensi implementasi detail per-platform di fase mendatang, di luar scope dokumen token ini.

---

## 1. Warna

### 1.1 Primer & Netral

| Token | Hex | Flutter |
|---|---|---|
| `--color-primary` | `#1D4ED8` | `Color(0xFF1D4ED8)` |
| `--color-primary-hover` | `#1E40AF` | `Color(0xFF1E40AF)` |
| `--color-primary-light` | `#EFF6FF` | `Color(0xFFEFF6FF)` |
| `--color-primary-fg` | `#FFFFFF` | `Colors.white` |
| `--color-sidebar` | `#0F172A` | `Color(0xFF0F172A)` |
| `--color-sidebar-text` | `#94A3B8` | `Color(0xFF94A3B8)` |
| `--color-bg` | `#F4F6F9` | `Color(0xFFF4F6F9)` |
| `--color-surface` | `#FFFFFF` | `Colors.white` |
| `--color-surface-2` | `#F8FAFC` | `Color(0xFFF8FAFC)` |
| `--color-text` | `#0F172A` | `Color(0xFF0F172A)` |
| `--color-text-2` | `#334155` | `Color(0xFF334155)` |
| `--color-muted` | `#64748B` | `Color(0xFF64748B)` |
| `--color-disabled` | `#94A3B8` | `Color(0xFF94A3B8)` |
| `--color-border` | `#E2E8F0` | `Color(0xFFE2E8F0)` |
| `--color-border-2` | `#CBD5E1` | `Color(0xFFCBD5E1)` |

### 1.2 Semantik

| Token | Hex |
|---|---|
| `--color-success` / `-light` | `#16A34A` / `#DCFCE7` |
| `--color-warning` / `-light` | `#D97706` / `#FEF3C7` |
| `--color-error` / `-light` | `#DC2626` / `#FEE2E2` |

### 1.3 Aksen per Tipe Bisnis (Fase 1 pakai `fnb` saja)

| Biz | Base | Light | Dark | Pemakaian |
|---|---|---|---|---|
| **F&B (aktif Fase 1)** | `#D97706` | `#FEF3C7` | `#92400E` | Order timer, active-order banner, KDS thermal indicator, chip kategori F&B |
| Retail (Fase 2) | `#7C3AED` | `#F5F3FF` | `#5B21B6` | Selector varian, checkbox terpilih, tema kategori retail, badge promo |
| Service/Bengkel (Fase 2) | `#16A34A` | `#DCFCE7` | `#15803D` | Chip status servis, badge selesai, progress indicator |

### 1.4 KDS Timer States (referensi, implementasi KDS di luar scope Fase 1)

| State | Range | Text | Bg | Glow |
|---|---|---|---|---|
| Safe | < 8 menit | `#16A34A` | `#DCFCE7` | tidak ada |
| Warning | 8–15 menit | `#D97706` | `#FEF3C7` | blink 0.8s |
| Urgent | > 15 menit | `#DC2626` | `#FEE2E2` | glow `0 0 12px rgba(220,38,38,0.4)` + dot berkedip |

### 1.5 Dark Surfaces (Signage/KDS — referensi, fase depan)

| Token | Hex | Pemakaian |
|---|---|---|
| `--color-signage-bg` | `#060C18` | Background luar Queue Signage |
| `--color-signage-left` | `#0A1428` | Panel kiri signage (order menunggu) |
| `--color-signage-right` | `#021A0D` | Panel kanan signage (order siap, tint hijau) |
| `--color-kds-bg` | `#0C1117` | Background luar KDS |

---

## 2. Tipografi

> **🔄 Update [2026-09-03]:** Tabel di bawah dikoreksi setelah membaca ULANG langsung source code asli Figma Make (`src/DesignSystem.tsx`, Section 02) — versi sebelumnya di dokumen ini punya beberapa size/weight yang MELESET dari sumber asli (mis. H1 ditulis 26/900, padahal aslinya 22/800; "Numeric" role tidak ada di source, yang ada "Mono / Data"). Tabel ini sekarang persis 1:1 dengan source, termasuk letter-spacing (tracking) dan contoh isi teks aslinya.

**Font family:** Inter (teks UI) + JetBrains Mono (SEMUA angka: harga, qty, kode order, timestamp — `tabular-nums` aktif, konsisten wajib, tidak boleh campur Inter untuk angka).

Skala tipe (13 role, map ke Flutter `TextTheme`) — persis dari `TYPE_SCALE` di `DesignSystem.tsx`:

| Role | Size | Weight | Line-height | Tracking | Flutter TextTheme | Contoh |
|---|---|---|---|---|---|---|
| Display | 32px | 800 | 1.1 | -1px | `displayLarge` | `Rp 4,280,000` |
| Heading 1 | 22px | 800 | 1.2 | -0.5px | `headlineMedium` | `Dashboard` |
| Heading 2 | 18px | 700 | 1.25 | -0.3px | `headlineSmall` | `Transaksi Terkini` |
| Heading 3 | 16px | 700 | 1.3 | -0.2px | `titleLarge` | `Konfirmasi Pembayaran` |
| Heading 4 | 14px | 700 | 1.4 | normal | `titleMedium` | `Order #2842` |
| Body Large | 15px | 400 | 1.6 | normal | `bodyLarge` | `Total yang harus dibayar` |
| Body Regular | 13px | 400 | 1.55 | normal | `bodyMedium` | `Subtotal · PPN 11%` |
| Body Small | 12px | 400 | 1.5 | normal | `bodySmall` | `Cari produk atau SKU…` |
| Button Text | 15px | 700 | 1.0 | -0.2px | `labelLarge` | `Bayar Rp 148,000` |
| Label / Badge | 11px | 600 | 1.0 | 0.07em | `labelSmall` | `LOW STOCK · COMPLETED` |
| Caption | 10px | 500 | 1.0 | 0.08em | `labelSmall` | `POINT OF SALE` |
| Mono / Data | 12px | 500 | 1.4 | normal | `bodyMedium` (mono) | `TXN-2841 · FOD-001` |

**Catatan penting untuk Flutter:** role "Mono / Data" dan semua angka (harga/qty/timestamp) WAJIB pakai `FontFeature.tabularFigures()` di `TextStyle`, bukan hanya ganti font family — ini yang membuat kolom angka rata secara visual (lihat CSS `.tabular` di `index.css` sumber Figma).

`pubspec.yaml`:
```yaml
fonts:
  - family: Inter
    fonts:
      - asset: assets/fonts/Inter-Regular.ttf
      - asset: assets/fonts/Inter-Medium.ttf
        weight: 500
      - asset: assets/fonts/Inter-SemiBold.ttf
        weight: 600
      - asset: assets/fonts/Inter-Bold.ttf
        weight: 700
      - asset: assets/fonts/Inter-ExtraBold.ttf
        weight: 800
  - family: JetBrainsMono
    fonts:
      - asset: assets/fonts/JetBrainsMono-Regular.ttf
      - asset: assets/fonts/JetBrainsMono-Medium.ttf
        weight: 500
      - asset: assets/fonts/JetBrainsMono-Bold.ttf
        weight: 700
```

---

## 3. Spacing (8pt Grid)

| Token | Value |
|---|---|
| `xs` | 4px |
| `sm` | 8px |
| `md` | 16px |
| `lg` | 24px |
| `xl` | 32px |
| `2xl` | 48px |

### Layout constants (nilai aktual dari implementasi prototype, PAKAI ini bukan token dokumentasi lama)

| Constant | Value | Catatan |
|---|---|---|
| Tablet POS sidebar | **200px** | ⚠️ Dokumen token CSS lama tertulis 240px — TIDAK sinkron dengan implementasi nyata `TabletShell`. Pakai 200px. |
| Tablet cart panel | 340px | |
| Back Office sidebar | 200px | (Fase depan) |
| Mobile bottom nav | 56px | (Fase depan — mobile ordering) |

### Breakpoint (Flutter)

```dart
enum GoldenityBreakpoint { mobile, tablet, backOffice, signage }

extension BreakpointExtension on BuildContext {
  GoldenityBreakpoint get breakpoint {
    final w = MediaQuery.of(this).size.width;
    if (w < 600)  return GoldenityBreakpoint.mobile;
    if (w < 1024) return GoldenityBreakpoint.tablet;
    if (w < 1280) return GoldenityBreakpoint.backOffice;
    return GoldenityBreakpoint.signage;
  }
}
```

---

## 4. Border Radius & Elevation

| Radius token | Value |
|---|---|
| `xs` | 4px |
| `sm` | 6px |
| `md` | 8px |
| `lg` | 10px |
| `xl` | 12px |
| `2xl` | 14px |
| `3xl` | 20px |
| `full` | 9999px |

**6-level elevation (shadow):**

| Level | Value |
|---|---|
| Card | `0 1px 3px rgba(0,0,0,0.06)` |
| Card hover | `0 4px 12px rgba(0,0,0,0.10)` |
| Button primary | `0 4px 12px rgba(29,78,216,0.30)` |
| Button success | `0 4px 12px rgba(22,163,74,0.30)` |
| Modal | `0 24px 48px rgba(0,0,0,0.18)` |

---

## 5. Komponen Wajib Fase 1 (State Spec)

> **🔄 Update [2026-09-03]:** Ditambahkan 3 komponen yang sebelumnya TERLEWAT dari dokumen ini padahal ada di "V2 Component Catalog" (Section 09) source Figma Make asli: **Floating Bottom Bar**, **KDS Timer Badge**, **Kanban Column**. Ketiganya di luar scope render Fase 1 (F&B POS Native tablet tidak butuh floating bar mobile atau KDS), tapi didokumentasikan penuh di sini (persis seperti kebijakan token Retail/Service di atas) supaya Fase 2/3 tidak perlu riset Figma ulang.

Setiap komponen di bawah punya 4 state minimum (default/hover/pressed/disabled) dan WAJIB dibangun sebagai satu widget reusable di `lib/shared/widgets/` — dipakai di semua tempat yang butuh, tidak ditulis ulang (lihat BRD Anti-Pattern #2).

**Dipakai Fase 1 (POS Native tablet F&B):**

- **`GoldenityPrimaryButton`** — tombol aksi utama (Bayar, Simpan, dsb). Bg `primary`, shadow `btnPrimary`, radius `xl`.
- **`GoldenityCounterButton`** — tombol +/- qty di cart.
- **`GoldenityBottomSheet`** — slide-up 320ms `cubic-bezier(0.32,0.72,0,1)` (≈`Curves.easeOutQuart`), handle 36×4px `#E2E8F0` radius 2px center, bg `#fff` radius atas 22px, backdrop `rgba(15,23,42,0.55)` + blur 2px, max-height 92vh. Dipakai: detail produk.
- **`GoldenityPaymentCard`** — kartu pilihan metode bayar. Icon box 44×44 radius 11px (default bg `#F1F5F9`, selected bg `#DBEAFE`). Default: border `#E2E8F0`, bg `#FAFBFC`. Selected: border `primary`, bg `primary-light`, radio terisi. Padding 12px 14px, radius 12px, border 1.5px.
- **`GoldenityCashTenderModal`** — modal input tunai + kembalian dengan smart quick-suggestion chip kelipatan 5K. **Satu implementasi, dipakai checkout utama DAN "tandai sudah bayar".** *(Catatan: komponen ini spesifik kebutuhan project Goldenity, tidak ada di V2 Component Catalog Figma — dipertahankan di sini karena sudah ada di codebase.)*
- **`GoldenityActiveOrderBanner`** — banner order F&B aktif. Bg `#FFFBEB`, border 1px `#FDE68A`, radius 12px, ikon 24px emoji 🍳, judul 13/700 `#92400E`, subjudul 11px `#B45309`, tombol aksi padding 6px 12px bg `#FEF3C7` radius 8px teks 12/700 `#92400E`.
- **`GoldenityVariantRadioSelector`** — pilihan tunggal (ukuran). Default: border `#E2E8F0`, bg `#FAFBFC`, radio outline `#CBD5E1`. Selected: border `primary`, bg `primary-light`, radio 18×18 terisi dengan titik putih 7px. Padding 10px 14px, radius 10px, border 1.5px.
- **`GoldenityVariantCheckboxSelector`** — pilihan jamak (topping/extra). Default: border `#E2E8F0`, bg `#FAFBFC`, checkbox outline `#CBD5E1`. Selected: border `#7C3AED` (aksen retail/purple — warna modifier, BUKAN warna biz-type aktif), bg `#F5F3FF`, checkbox bg `#7C3AED` dengan centang putih. Checkbox 18×18px radius 4px.

**Didokumentasikan untuk fase depan (Retail/Service/KDS/Signage — TIDAK diimplementasi Fase 1):**

- **`GoldenityFloatingBottomBar`** — sticky CTA bar untuk cart summary mobile ordering. Tinggi 52px, radius 14px, bg `primary` (`#1D4ED8`), shadow `0 4px 20px rgba(29,78,216,0.40)`. Badge qty 32×32px radius 8px `rgba(0,0,0,0.25)` teks JetBrains Mono 14/800. Label Inter 14/800 putih flex-1. Harga JetBrains Mono 13/700 `rgba(255,255,255,0.85)`. Container absolute bottom 0 dengan gradient transparent → `#F4F6F9`.
- **`GoldenityKdsTimerBadge`** — indikator urgensi 3-state untuk timer order dapur. Safe (<8min): bg `#DCFCE7` teks `#16A34A`, tanpa glow. Warning (8–15min): bg `#FEF3C7` teks `#D97706`, animasi blink 0.8s. Urgent (>15min): bg `#FEE2E2` teks `#DC2626`, glow `0 0 12px rgba(220,38,38,0.4)`, dot merah berkedip. Padding 6px 12px, radius 8px, font JetBrains Mono 13/700.
- **`GoldenityKanbanColumn`** (KDS) — kolom status order di layar dapur. NEW: left border 3px `#94A3B8`, header teks `#64748B`. COOKING: left border 3px `#D97706`, header teks `#D97706`. READY: left border 3px `#16A34A`, header teks `#16A34A`. Bg kolom `#F8FAFC`, radius 10px, flex-1. Header padding 8px 12px, label 11/800 uppercase, count JetBrains Mono 11px.

---

## 6. Motion & Animasi

> **🔄 Update [2026-09-03]:** Ditambahkan 2 animasi yang terlewat (`slideDown`, `ripple`) — sekarang lengkap 5/5 sesuai `ANIMATIONS` di source Figma Make `DesignSystem.tsx` Section 10.

| Nama | Durasi | Easing | Properties | Dipakai untuk | Scope Fase 1 |
|---|---|---|---|---|---|
| `slideUp` | 320ms | `cubic-bezier(0.32,0.72,0,1)` | `translateY(100%)→0`, opacity 0.8→1 | Bottom sheet masuk (detail produk) | ✅ Dipakai |
| `flashIn` | 500ms | ease | `scale(0.95)→1`, opacity 0→1 | Kartu order baru muncul | Opsional Fase 1 |
| `pulse` | 1200ms | ease, infinite | opacity 0.3↔1, `scale(0.8)↔1` | Dot indikator urgent, stepper aktif | Opsional Fase 1 |
| `slideDown` | 400ms | ease | `translateY(-20px)→0`, opacity 0→1 | Toast order baru di Queue Signage | Fase depan (Signage) |
| `ripple` | 1800ms | ease-out, infinite | `scale(1)→1.4`, opacity 0.6→0 | Ring checkmark saat order sukses | Fase depan |

Flutter equivalent contoh (`slideUp`):
```dart
final controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
final slideAnim = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
  .animate(CurvedAnimation(parent: controller, curve: Curves.easeOutQuart));
```

Flutter equivalent (`ripple` — dipakai fase depan, dicatat untuk referensi):
```dart
final controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
final scaleAnim   = Tween<double>(begin: 1.0, end: 1.4)
  .animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));
final opacityAnim = Tween<double>(begin: 0.6, end: 0.0)
  .animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));
```

---

## 7. Token Export — CSS Variables (referensi lintas-platform)

```css
:root {
  --font-sans: 'Inter', system-ui, sans-serif;
  --font-mono: 'JetBrains Mono', monospace;
  --color-primary: #1D4ED8;
  --color-primary-hover: #1E40AF;
  --color-primary-light: #EFF6FF;
  --color-sidebar: #0F172A;
  --color-bg: #F4F6F9;
  --color-surface: #FFFFFF;
  --color-surface-2: #F8FAFC;
  --color-text: #0F172A;
  --color-muted: #64748B;
  --color-border: #E2E8F0;
  --color-success: #16A34A;
  --color-warning: #D97706;
  --color-error: #DC2626;
  --spacing-xs: 4px; --spacing-sm: 8px; --spacing-md: 16px; --spacing-lg: 24px; --spacing-xl: 32px; --spacing-2xl: 48px;
  --radius-xs: 4px; --radius-sm: 6px; --radius-md: 8px; --radius-lg: 10px; --radius-xl: 12px; --radius-2xl: 14px; --radius-3xl: 20px; --radius-full: 9999px;
  --shadow-card: 0 1px 3px rgba(0,0,0,0.06);
  --shadow-btn-primary: 0 4px 12px rgba(29,78,216,0.30);
  --sidebar-width: 200px; /* nilai aktual, bukan 240px */
  --cart-width: 340px;
}
```

---

## 8. Catatan Implementasi

- Semua token di Bagian 1–4 WAJIB diimplementasikan sebagai file konstanta Dart terpusat (`lib/core/design/`) SEBELUM screen apapun dibangun — lihat `MASTER_BLUEPRINT_V2.md` Bagian 7 Tahap 0.
- Token Retail/Service/KDS/Signage sudah final di Figma dan didokumentasikan penuh di sini supaya Fase 2 tidak perlu riset Figma ulang — tapi TIDAK diimplementasi UI-nya di Fase 1.
- Rekonsiliasi nilai sidebar 200px vs 240px: dokumen ini mengikuti nilai yang benar-benar dipakai di prototype tervalidasi (200px), bukan token CSS dokumentasi yang berpotensi basi.
