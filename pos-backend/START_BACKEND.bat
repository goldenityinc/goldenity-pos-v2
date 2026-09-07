@echo off
chcp 65001 >nul
title Goldenity POS V2 — Backend Watchdog (Auto-Restart Permanent)

REM =========================================================================
REM  START_BACKEND.bat — Goldenity POS V2 Backend (DOUBLE-CLICK INI SAJA!)
REM  Lokasi: pos-backend\START_BACKEND.bat
REM  Dibuat: 2026-09-07 — Solusi permanen "BE sering mati / HTTP 404 salah PID"
REM =========================================================================
REM  ✅ CARA PAKAI (Andre):
REM     1. Buka folder `pos-backend` di File Explorer
REM     2. DOUBLE-CLICK file ini (START_BACKEND.bat)
REM     3. Biarkan jendela hitam ini TERBUKA (boleh di-minimize ke taskbar)
REM        selama development / test Flutter.
REM     4. Jika kamu lihat baris teks MERAH:
REM        [WATCHDOG] Backend BERHENTI (exit code X)... Menyalakan ulang otomatis
REM        → Tunggu 3-5 detik, lalu klik 🔄 "Coba Lagi" di Flutter APP.
REM
REM  ✅ APA YANG OTOMATIS DILAKUKAN (100% PATUH POLICY TIDAK KILL GLOBAL NODE):
REM     1. Cek proses apa yang mendengarkan di PORT 3001
REM     2. Coba panggil GET http://localhost:3001/health → JIKA TIDAK 200 / timeout
REM        = proses tersebut BUKAN POS Backend V2 yang benar → MATIKAN HANYA PID ITU
REM        (proses Flutter/Trae/node.exe lain TIDAK DI-SENTUH SAMA SEKALI —
REM         100% sesuai Policy Permanen yang ditetapkan 2026-09-06)
REM     3. Jalankan `npm run dev` (tsx watch src/index.ts)
REM     4. SELALU PANTAU — jika backend crash/nyangkut kapanpun → OTOMATIS restart
REM        tanpa perlu minta Trae / buka terminal manual lagi.
REM
REM  ⚠️  CATATAN JUJUR (belum bisa di-test di PC Andre dari sesi ini):
REM     - Tool ini TIDAK AKTIF jika PC/Laptop Andre MODE SLEEP/HIBERNASI
REM       (watchdog ikut ter-suspend). Perlu Windows Power Settings diatur
REM       agar TIDAK pernah sleep saat terhubung listrik. Panduan bisa dibuatkan
REM       jika Andre kirim request lagi.
REM =========================================================================

echo.
echo ╔══════════════════════════════════════════════════════════════════════════╗
echo ║  🚀 Goldenity POS V2 — BACKEND WATCHDOG PERMANEN (Auto-Restart)         ║
echo ╠══════════════════════════════════════════════════════════════════════════╣
echo ║  Lokasi   : pos-backend\START_BACKEND.bat                                ║
echo ║  Port     : 3001                                                         ║
echo ║  Policy   : ✅ HANYA kill PID port 3001 spesifik (bukan global node)     ║
echo ║  Dibuat   : Andre / Klaude 2026-09-07                                    ║
echo ╚══════════════════════════════════════════════════════════════════════════╝
echo.
echo [I] Menjalankan Watchdog PowerShell (start-backend.ps1)...
echo [I] Kamu BISA MINIMIZE jendela ini ke taskbar. JANGAN DITUTUP!
echo.

REM  Pastikan working directory = FOLDER DIMANA FILE BAT INI BERADA (pos-backend)
cd /d "%~dp0"

REM  Jalankan PowerShell script watchdog:
REM   -ExecutionPolicy Bypass  → izinkan jalankan script tanpa ganti global policy
REM   -NoProfile                → jangan load profile user (cepat & bersih)
REM   -File ".\start-backend.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-backend.ps1"

REM  Jika watchdog keluar = user menekan Ctrl+C.
echo.
echo [S] Watchdog DIHENTIKAN oleh user (Ctrl+C tekan).
echo [S] Backend tidak akan auto-restart lagi sampai kamu double-click BAT ini lagi.
echo.
pause
