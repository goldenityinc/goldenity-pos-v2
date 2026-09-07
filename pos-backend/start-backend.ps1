#Requires -Version 5.1
<#
.SYNOPSIS
  Goldenity POS V2 — Backend Watchdog PowerShell (Auto-Restart Permanent)
.DESCRIPTION
  Dipanggil oleh START_BACKEND.bat (double-click). Tidak perlu dijalankan manual.
  PATUH 100% KE POLICY PERMANEN (ditetapkan 2026-09-06):
    ❌ DILARANG KERAS: Stop-Process -Name node -Force (kill GLOBAL semua node.exe)
    ✅ HANYA BOLEH kill PID SPESIFIK yang listen PORT 3001 DAN terbukti BUKAN
       POS Backend V2 yang benar (GET /health != 200 / timeout).
.LOCATION
  pos-backend\start-backend.ps1
.NOTES
  Dibuat: 2026-09-07 (Andre / Klaude)
  Belum di-test di PC Andre langsung dari sesi ini — tolong dicoba sekali dan
  dikabari hasilnya lewat chat.
#>

# ============================================================================
# 0. KONFIGURASI TETAP (JANGAN DIUBAH KECUALI ADA PERMINTAAN ANDRE)
# ============================================================================
$BACKEND_PORT = 3001
$HEALTH_URL   = "http://localhost:${BACKEND_PORT}/health"
$HEALTH_TIMEOUT_MS = 2500       # 2,5 detik — timeout cek /health
$CRASH_RESTART_COOLDOWN_SEC = 3 # Tunggu 3 detik sebelum restart kalau crash
$WORKDIR = Split-Path -Parent $MyInvocation.MyCommand.Path  # = pos-backend\

# Warna log helper
function Write-Info($msg)    { Write-Host "[WATCHDOG]  " -ForegroundColor Cyan -NoNewline; Write-Host $msg }
function Write-OK($msg)      { Write-Host "[WATCHDOG]  " -ForegroundColor Green -NoNewline; Write-Host $msg }
function Write-Warn($msg)    { Write-Host "[WATCHDOG]  " -ForegroundColor Yellow -NoNewline; Write-Host $msg -ForegroundColor Yellow }
function Write-Fail($msg)    { Write-Host "[WATCHDOG]  " -ForegroundColor Red -NoNewline; Write-Host $msg -ForegroundColor Red }
function Write-Header($msg)  { Write-Host ""; Write-Host "══ $msg ══" -ForegroundColor Magenta }

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  🚀 Goldenity POS V2  —  BACKEND WATCHDOG (Auto-Restart Permanent)      ║" -ForegroundColor Cyan
Write-Host "╠══════════════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "║  Working Dir : $WORKDIR"
Write-Host "║  Port Check  : $BACKEND_PORT"
Write-Host "║  Health URL  : $HEALTH_URL"
Write-Host "║  Policy Kill : ❌ NO global node kill — ✅ ONLY PID spesifik port $BACKEND_PORT" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# 1. PASTIKAN WORKING DIRECTORY SELALU = pos-backend\ (dimana package.json ada)
# ============================================================================
try {
    Set-Location $WORKDIR -ErrorAction Stop
    Write-Info "Working directory diset ke: $WORKDIR"
} catch {
    Write-Fail "Gagal pindah ke folder pos-backend ($WORKDIR): $_"
    Write-Warn "Pastikan start-backend.ps1 berada DI DALAM folder pos-backend (bersama package.json)."
    pause
    exit 1
}

# ============================================================================
# 2. FUNGSI UTAMA: Cek Port 3001 → Kalau salah proses → HANYA kill PID itu
#    (100% PATUH POLICY — tidak pernah menyentuh process lain / node global)
# ============================================================================
function Resolve-Port3001DanBersihkanJikaSalah {
    param()
    Write-Header "STEP 1: CEK PORT $BACKEND_PORT APABILA SUDAH TERPAKAI"

    # 2a. Dapatkan PID yang LISTEN port 3001 (jika ada)
    $pidsOnPort = @()
    try {
        $connections = Get-NetTCPConnection -LocalPort $BACKEND_PORT -State Listen -ErrorAction Stop
        if ($connections -and $connections.Count -gt 0) {
            $pidsOnPort = @($connections | Select-Object -ExpandProperty OwningProcess -Unique)
        }
    } catch {
        $err = $_.Exception.Message
        if ($err -match "No matching MSFT_NetTCPConnection objects found") {
            Write-Info "Port $BACKEND_PORT KOSONG (belum ada process listen) — Lanjut start backend."
            return $true
        }
        Write-Warn "Gagal baca Get-NetTCPConnection port $BACKEND_PORT`: $err"
        Write-Warn "Lanjut dengan asumsi port bersih (tidak force kill apa-apa — safety policy)."
        return $true
    }

    if ($pidsOnPort.Count -eq 0) {
        Write-Info "Port $BACKEND_PORT KOSONG — tidak ada process listen. Lanjut start."
        return $true
    }

    # 2b. Ada PID yang listen — ambil nama process + cek /health
    foreach ($pidToCheck in $pidsOnPort) {
        $procName = "?"
        try {
            $proc = Get-Process -Id $pidToCheck -ErrorAction Stop
            $procName = $proc.ProcessName
        } catch {
            $procName = "PID-$pidToCheck (sudah mati / tidak dapat diakses)"
        }

        Write-Info "Port $BACKEND_PORT digunakan PID=$pidToCheck (process: $procName)."
        Write-Info "Mencoba verifikasi GET $HEALTH_URL (timeout ${HEALTH_TIMEOUT_MS}ms)..."

        # 2c. Coba panggil /health — JIKA 200 OK = process ini BENAR POS V2 backend
        $backendSudahBenarHidup = $false
        try {
            $resp = Invoke-RestMethod -Uri $HEALTH_URL `
                                      -Method Get `
                                      -TimeoutSec ([Math]::Max(1, [int]($HEALTH_TIMEOUT_MS/1000))) `
                                      -ErrorAction Stop
            if ($resp -and $resp.status -and $resp.status -ieq "ok") {
                $backendSudahBenarHidup = $true
                Write-OK "✅ PID $pidToCheck TERBUKTI BENAR POS Backend V2!"
                Write-OK "   /health → status=ok  (service=$($resp.service), version=$($resp.version))"
                Write-Info "Watchdog TIDAK melakukan kill apapun. Backend sudah OK."
            } else {
                Write-Warn "PID $pidToCheck jawab /health tapi status BUKAN 'ok' (status='$($resp.status)')."
                Write-Warn "Anggap ini PROSES SALAH yang nyangkut di port 3001 (bukan POS V2)."
                $backendSudahBenarHidup = $false
            }
        } catch {
            $httpErr = $_.Exception.Message
            Write-Warn "PID $pidToCheck TIDAK menjawab /health dalam ${HEALTH_TIMEOUT_MS}ms (error: $httpErr)."
            Write-Warn "⇒ PROSES INI SALAH / NYANGKUT — BUKAN POS Backend V2 yang benar."
            $backendSudahBenarHidup = $false
        }

        # 2d. JIKA SALAH = MATIKAN HANYA PID INI SAJA (POLICY — NEVER KILL GLOBAL)
        if (-not $backendSudahBenarHidup) {
            Write-Warn "AKAN MENGHENTIKAN PID=$pidToCheck SAJA (proses $procName)."
            Write-Warn "Policy diikuti 100% — TIDAK ADA kill global node.exe / process lain."
            try {
                Stop-Process -Id $pidToCheck -Force -ErrorAction Stop
                Start-Sleep -Milliseconds 800
                try { $proc = Get-Process -Id $pidToCheck -ErrorAction Stop } catch { $proc = $null }
                if (-not $proc) {
                    Write-OK "✅ PID $pidToCheck BERHASIL DIHENTIKAN. Port $BACKEND_PORT sekarang bersih."
                } else {
                    Write-Fail "❌ PID $pidToCheck MASIH HIDUP setelah Stop-Process dipanggil."
                    Write-Warn "Kemungkinan: process dijalankan sebagai ADMIN. Coba jalankan START_BACKEND.bat 'Run As Administrator' jika error berulang."
                    return $false
                }
            } catch {
                Write-Fail "Gagal hentikan PID=$pidToCheck`: $_"
                Write-Warn "Solusi: Tutup manual process PID $pidToCheck via Task Manager, atau jalankan BAT sebagai ADMIN."
                return $false
            }
        } else {
            # Backend SUDAH BENAR hidup. Return FALSE supaya watchdog TIDAK start lagi (dup port).
            Write-Header "BACKEND SUDAH HIDUP DAN BENAR"
            Write-Info "Kamu TIDAK PERLU double-click START_BACKEND.bat DUA KALI."
            Write-Info "Biarkan jendela ini terbuka — nanti kita pantau bersama process tsx watch yang sudah jalan."
            Write-Info "Flutter APP sekarang sudah bisa akses http://localhost:$BACKEND_PORT."
            return $false
        }
    }
    return $true
}

# ============================================================================
# 3. FUNGSI UTAMA: Jalankan Backend (npm run dev), PANTAU SAMPAI EXIT
#    (tsx watch src/index.ts — auto rebuild saat file berubah)
# ============================================================================
function Start-DanPantauBackend {
    param()
    Write-Header "STEP 2: JALANKAN BACKEND (npm run dev — tsx watch mode)"
    Write-Info "Command  : npm.cmd run dev"
    Write-Info "Mode     : watch (auto-reload jika file .ts diubah)"
    Write-Info "Port     : $BACKEND_PORT"
    Write-Info ""
    Write-Info "💡 Tips: Jika backend crash karena perubahan kode, baris MERAH akan muncul,"
    Write-Info "         lalu watchdog OTOMATIS nyalakan ulang setelah $CRASH_RESTART_COOLDOWN_SEC detik."
    Write-Host ""

    $exitCode = -1
    try {
        # Pakai npm.cmd agar dijalankan sebagai child-process yang stdout/stderr
        # langsung tampil ke terminal watchdog (tidak di-buffer).
        & npm.cmd run dev
        $exitCode = $LASTEXITCODE
    } catch {
        $exitCode = 9999
        Write-Fail "Exception saat jalankan npm run dev`: $_"
    }

    return [int]$exitCode
}

# ============================================================================
# 4. LOOP UTAMA WATCHDOG (FOREVER — sampai user tekan Ctrl+C / tutup jendela)
# ============================================================================
$restartCounter = 0
:WATCHDOG_LOOP while ($true) {
    Write-Host ""
    Write-Host "┌──────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Magenta
    Write-Host "│ 🔁 WATCHDOG CYCLE ke-$($restartCounter + 1)  —  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Magenta
    Write-Host "└──────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Magenta

    # 4a. Bersihkan port jika salah process nyangkut
    $bolehStartBackend = Resolve-Port3001DanBersihkanJikaSalah
    if (-not $bolehStartBackend) {
        # Kasus: Backend SUDAH benar hidup SEBELUM watchdog start (user double-click 2x)
        # ⇒ Jangan start lagi. Tunggu user Ctrl+C.
        Write-Info ""
        Write-Info "Watchdog masuk MODE PANTAU SAJA. Tekan Ctrl+C untuk keluar."
        while ($true) { Start-Sleep -Seconds 5 }
    }

    # 4b. Jalankan backend — BLOKIR SAMPAI BACKEND EXIT / CRASH / USER CTRL+C
    $exitCode = Start-DanPantauBackend
    $restartCounter++

    # 4c. Backend keluar (crash / user stop tsx). Log jelas warna MERAH.
    Write-Host ""
    Write-Fail "Backend BERHENTI (exit code = $exitCode). Jumlah restart otomatis: $restartCounter"
    Write-Warn "Auto-restart dalam $CRASH_RESTART_COOLDOWN_SEC detik..."
    Write-Warn "Jika ini ERROR YANG TIDAK MAU di-restart: Tekan Ctrl+C sekarang (dalam $CRASH_RESTART_COOLDOWN_SEC detik)."
    Write-Warn "Di Flutter APP: Klik 🔄 Coba Lagi beberapa detik setelah restart selesai."
    Write-Host ""

    # 4d. Countdown cooldown (tampilkan 3,2,1 biar user tahu kapan restart lagi)
    for ($i = $CRASH_RESTART_COOLDOWN_SEC; $i -gt 0; $i--) {
        Write-Host "   → Restart otomatis dalam $i detik... (Ctrl+C untuk BATALKAN restart)" -ForegroundColor DarkYellow
        Start-Sleep -Seconds 1
    }
    Write-Info "⏱️ Cooldown selesai. Mulai cycle watchdog baru (bersihkan port → start backend)."
    Write-Host ("─" * 74)
    continue WATCHDOG_LOOP
}
