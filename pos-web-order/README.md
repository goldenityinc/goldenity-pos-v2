# pos-web-order — Web Order Customer App

Mobile-first customer web app. Pelanggan scan QR di meja → lihat menu → pesan →
lacak status. Wired ke `pos-backend` `/api/v1/order/*` (tanpa JWT, discope
`sessionToken` di localStorage).

## Stack
Vite + React + TS + Tailwind v3 + react-router + zustand.

## Dev
```bash
npm install
npm run dev          # http://localhost:5174 , /api di-proxy ke :3001
```
Buka: `http://localhost:5174/t/<qrToken>` (qrToken meja dari POS Native "Generate QR Meja").
Format URL QR dari backend: `/{tenantSlug}/{branchId}/t/{qrToken}` juga didukung.

## Prod
`VITE_API_BASE=https://api.goldenity.app npm run build` → serve `dist/`.

## Flow
1. `SessionGate` — baca qrToken dari path, isi nama/HP opsional → `POST /order/session`.
2. `Menu` — `GET /order/menu`; kategori chip + search; `ProductSheet` (varian +
   qty + instruksi khusus) → keranjang (zustand, persist).
3. `Checkout` — review keranjang, metode (Bayar di Kasir / QRIS), catatan →
   `POST /order/submit` → redirect `/orders?new=<id>`.
4. `Orders` — `GET /order/session/<token>` polling 8 dtk; stepper status
   (Antri→Terima→Masak→Siap→Antar); QRIS: tombol "Saya sudah bayar" →
   `POST /order/<id>/paid`.

## E2E (verified 2026-09-08)
Customer submit → POS Native Web Orders (SUBMITTED) → Terima → SalesRecord;
customer app poll → status "Diterima".
