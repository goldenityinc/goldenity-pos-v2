# pos-bridge — Goldenity POS Bridge

Companion lokal yang berjalan di komputer kasir / dapur. Menyambung ke
`pos-backend` via **Socket.IO** dan **auto-print tiket dapur (CHECKER)** setiap
ada web order baru dari pelanggan (`pos-web-order`).

```
pelanggan (pos-web-order)  ──POST /order/submit──▶  pos-backend
                                                      │  emit web_order:submitted (room branch:<id>)
                                                      ▼
                                                   pos-bridge  ──ESC/POS──▶  printer dapur
```

## Cara kerja

1. Login ke `POST /api/v1/auth/login` (`TENANT_SLUG` / `BRIDGE_USERNAME` / `BRIDGE_PASSWORD`) → JWT.
2. Connect Socket.IO (`auth: { token }`). Token membawa `branchId` user → otomatis join room `branch:<id>`.
3. On `web_order:submitted` → `GET /api/v1/web-orders/:id` (ambil item + catatan) → cetak tiket dapur.
4. On `web_order:status` → dicatat di `/status` (tidak mencetak).
5. HTTP lokal: `GET /health`, `GET /status`, `POST /reprint/:id`.

## Setup

```bash
cp .env.example .env      # sesuaikan kredensial + printer
npm install
npm run dev               # tsx watch
```

Mode printer:

- `PRINTER_MODE=console` — tiket dicetak sebagai teks di terminal (dev / belum ada printer).
- `PRINTER_MODE=tcp` — kirim byte ESC/POS mentah ke `PRINTER_HOST:PRINTER_PORT` (raw 9100).
  `PRINTER_COLS` 32 (58mm) atau 48 (80mm); `PRINTER_CUT=true` untuk auto-cut.

## Produksi

```bash
npm run build && npm start
```

Jalankan sebagai service (nssm / pm2 / systemd) di PC kasir. Satu instance per cabang;
kalau 1 PC melayani banyak cabang, jalankan beberapa instance dengan `.env` + `PORT` berbeda
dan `BRANCH_ID` di-set eksplisit.

## Endpoint lokal

| Method | Path           | Guna                                            |
| ------ | -------------- | ---------------------------------------------- |
| GET    | `/health`      | liveness (`{ ok, connected, uptimeSec }`)      |
| GET    | `/status`      | koneksi, cabang, 50 job terakhir, target printer |
| POST   | `/reprint/:id` | cetak ulang tiket dapur untuk 1 web order      |
