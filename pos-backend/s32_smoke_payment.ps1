$UBP = @{ UseBasicParsing = $true }
$BASE = "http://localhost:3001/api/v1"
$SCRIPT_OK = 0
$SCRIPT_FAIL = 0
$ASSERTIONS = @()

function Write-Assert {
    param([string]$name, [bool]$pass, [string]$detail)
    $global:ASSERTIONS += [pscustomobject]@{ Name = $name; Pass = $pass; Detail = $detail }
    if ($pass) { $global:SCRIPT_OK++; Write-Host ("  [OK] " + $name) -ForegroundColor Green }
    else { $global:SCRIPT_FAIL++; Write-Host ("  [FAIL] " + $name + " | " + $detail) -ForegroundColor Red }
}

function Invoke-Api {
    param(
        [string]$Method,
        [string]$Uri,
        [string]$Body,
        [hashtable]$Headers,
        [ref]$StatusCodeOut,
        [ref]$BodyOut
    )
    $localStatus = 0
    $localBody = $null
    try {
        $params = @{
            Uri = $Uri
            Method = $Method
            UseBasicParsing = $true
        }
        if ($Body) { $params.Body = $Body; $params.ContentType = "application/json" }
        if ($Headers) { $params.Headers = $Headers }
        $resp = Invoke-WebRequest @params
        $localStatus = [int]$resp.StatusCode
        $localBody = $resp.Content | ConvertFrom-Json
    } catch {
        if ($_.Exception.Response) {
            $localStatus = [int]$_.Exception.Response.StatusCode.value__
            $respText = ""
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $respText = $reader.ReadToEnd()
                $reader.Close()
                $stream.Close()
                Write-Host ("    [Invoke-Api DEBUG HTTP " + $localStatus + " RAW:] " + $respText) -ForegroundColor DarkGray
                if ($respText) {
                    try {
                        $localBody = $respText | ConvertFrom-Json -ErrorAction Stop
                    } catch {
                        Write-Host ("    [Invoke-Api DEBUG JSON PARSE FAIL:] Use raw text as error message. Inner: " + $_.Exception.Message) -ForegroundColor Magenta
                        $localBody = [pscustomobject]@{ success = $false; error = $respText }
                    }
                } else {
                    $localBody = [pscustomobject]@{ success = $false; error = "EMPTY RESPONSE BODY" }
                }
            } catch {
                $localBody = [pscustomobject]@{ success = $false; error = ("READ STREAM FAIL: " + $_.Exception.Message) }
            }
        } else {
            $localStatus = -1
            $localBody = [pscustomobject]@{ success = $false; error = ("NO RESPONSE: " + $_.Exception.Message) }
        }
    }
    $StatusCodeOut.Value = $localStatus
    $BodyOut.Value = $localBody
}

Write-Host "=== S3.2 PAYMENT SMOKE: 6 ASSERTIONS START ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/6] Login kasir untuk token..." -ForegroundColor Yellow
$LOGIN_BODY = @{ tenantSlug = "demo-fnb"; username = "kasir"; password = "kasir123" } | ConvertTo-Json
$LOGIN_SC = 0; $LOGIN_DATA = $null
Invoke-Api -Method Post -Uri ($BASE + "/auth/login") -Body $LOGIN_BODY -StatusCodeOut ([ref]$LOGIN_SC) -BodyOut ([ref]$LOGIN_DATA)
if ($LOGIN_SC -eq 200 -and $LOGIN_DATA.success) {
    $TOKEN = $LOGIN_DATA.data.token
    $BRANCH_ID = $LOGIN_DATA.data.user.branchId
    $TENANT_ID = $LOGIN_DATA.data.user.tenantId
    if (-not $TOKEN -or -not $BRANCH_ID) { Write-Host ("  Login FAIL: token/branch null") -ForegroundColor Red; exit 1 }
    Write-Host ("  Login OK: tenant=" + $TENANT_ID + " branch=" + $BRANCH_ID + " tokenLen=" + $TOKEN.Length) -ForegroundColor Green
} else {
    Write-Host ("  Login FAIL: SC=" + $LOGIN_SC + " msg=" + $LOGIN_DATA.error) -ForegroundColor Red
    exit 1
}
$HEADERS = @{ Authorization = ("Bearer " + $TOKEN) }

Write-Host "  Mengambil daftar produk dari DB untuk mendapatkan productId valid..." -ForegroundColor Gray
$PROD_SC = 0; $PROD_DATA = $null
Invoke-Api -Method Get -Uri ($BASE + "/products") -Headers $HEADERS -StatusCodeOut ([ref]$PROD_SC) -BodyOut ([ref]$PROD_DATA)
if ($PROD_SC -ne 200 -or -not $PROD_DATA.success) {
    Write-Host ("  FAIL: Tidak bisa mengambil produk. SC=" + $PROD_SC + " msg=" + $PROD_DATA.error) -ForegroundColor Red
    exit 1
}
$PROD_LIST = $PROD_DATA.data.products
if (-not $PROD_LIST -or $PROD_LIST.Count -lt 2) {
    Write-Host ("  FAIL: Produk kurang dari 2, count=" + $PROD_LIST.Count) -ForegroundColor Red
    exit 1
}
$PROD1 = $PROD_LIST[0]
$PROD2 = $PROD_LIST[1]
Write-Host ("  Produk valid: #1 id=" + $PROD1.id + " name=" + $PROD1.name + " price=" + $PROD1.price) -ForegroundColor Gray
Write-Host ("  Produk valid: #2 id=" + $PROD2.id + " name=" + $PROD2.name + " price=" + $PROD2.price) -ForegroundColor Gray

function Make-StandardPayload {
    param([string]$pm, [object]$ref, [guid]$refId)
    $QTY1 = 2; $QTY2 = 2
    $PRICE1 = [double]$PROD1.price; $PRICE2 = [double]$PROD2.price
    $LINE1 = $QTY1 * $PRICE1; $LINE2 = $QTY2 * $PRICE2
    $SUB = $LINE1 + $LINE2
    $DISC = 0
    $TAX = [math]::Round($SUB * 0.11, 2)
    $SC_AMT = 0; $SC_PCT = 0
    $GRAND = $SUB - $DISC + $TAX + $SC_AMT
    $ITEMS = @(
        @{ productId = $PROD1.id; productName = $PROD1.name; qty = $QTY1; unitPrice = $PRICE1; lineTotal = $LINE1 },
        @{ productId = $PROD2.id; productName = $PROD2.name; qty = $QTY2; unitPrice = $PRICE2; lineTotal = $LINE2 }
    )
    return [ordered]@{
        referenceId = $refId.ToString()
        orderType = "DINE_IN"
        paymentMethod = $pm
        subtotal = $SUB
        discountAmount = $DISC
        taxAmount = $TAX
        serviceChargeAmount = $SC_AMT
        serviceChargePercentage = $SC_PCT
        total = $GRAND
        items = $ITEMS
        cashierId = $LOGIN_DATA.data.user.id
        branchId = $BRANCH_ID
        paymentReferenceNumber = $ref
        cashReceived = $GRAND
        cashChange = 0
    }
}

Write-Host ""
Write-Host "[2/6] Scenario 1: CASH paymentReferenceNumber = null -> 201 Created" -ForegroundColor Yellow
$REF1 = [guid]::NewGuid()
$P1 = Make-StandardPayload -pm "CASH" -ref $null -refId $REF1
$B1 = $P1 | ConvertTo-Json -Depth 10
$SC1 = 0; $D1 = $null
Invoke-Api -Method Post -Uri ($BASE + "/sales") -Body $B1 -Headers $HEADERS -StatusCodeOut ([ref]$SC1) -BodyOut ([ref]$D1)
Write-Host "  [DEBUG] Scenario1 response JSON:" -ForegroundColor Gray
$D1 | ConvertTo-Json -Depth 6 | Out-String | Write-Host -ForegroundColor Gray
Write-Assert -name "S32-AC4-1 CASH ref=null HTTP 201" -pass ($SC1 -eq 201) -detail ("actual=" + $SC1 + " msg=" + $D1.error)
$ID1 = $null
if ($SC1 -eq 201 -and $D1.success) {
    $ID1 = $D1.data.sale.id
    Write-Assert -name "S32-AC4-1 CASH paymentMethod=CASH" -pass ($D1.data.sale.paymentMethod -eq "CASH") -detail ("actual=" + $D1.data.sale.paymentMethod)
    Write-Assert -name "S32-AC4-1 CASH paymentReferenceNumber=null" -pass ($null -eq $D1.data.sale.paymentReferenceNumber -or $D1.data.sale.paymentReferenceNumber -eq "") -detail ("actual=" + $D1.data.sale.paymentReferenceNumber)
}

Write-Host ""
Write-Host "[3/6] Scenario 2: QRIS ref=null -> reject 400 message QRIS" -ForegroundColor Yellow
$REF2 = [guid]::NewGuid()
$P2 = Make-StandardPayload -pm "QRIS" -ref $null -refId $REF2
$B2 = $P2 | ConvertTo-Json -Depth 10
$SC2 = 0; $D2 = $null
Invoke-Api -Method Post -Uri ($BASE + "/sales") -Body $B2 -Headers $HEADERS -StatusCodeOut ([ref]$SC2) -BodyOut ([ref]$D2)
Write-Host "  [DEBUG] Scenario2 raw object:" -ForegroundColor Gray
if ($D2 -eq $null) { Write-Host "  [DEBUG] D2 IS NULL" -ForegroundColor Red } else { $D2 | Out-String | Write-Host -ForegroundColor Gray }
Write-Assert -name "S32-AC4-2 QRIS ref=null HTTP 400" -pass ($SC2 -eq 400) -detail ("actual=" + $SC2)
if ($SC2 -eq 400) {
    if ($D2 -and $D2.error) {
        $MSG2 = $D2.error
    } else {
        $MSG2 = "EMPTY_OBJECT"
    }
    Write-Assert -name "S32-AC4-2 QRIS message ada 'Nomor referensi QRIS'" -pass ($MSG2 -like "*Nomor referensi QRIS*") -detail ("msg=" + $MSG2)
}

Write-Host ""
Write-Host "[4/6] Scenario 3: QRIS ref=QRIS-TRX-00123 -> 201 persist" -ForegroundColor Yellow
$REF3 = [guid]::NewGuid()
$EXPECTED_REF3 = "QRIS-TRX-00123"
$P3 = Make-StandardPayload -pm "QRIS" -ref $EXPECTED_REF3 -refId $REF3
$B3 = $P3 | ConvertTo-Json -Depth 10
$SC3 = 0; $D3 = $null
Invoke-Api -Method Post -Uri ($BASE + "/sales") -Body $B3 -Headers $HEADERS -StatusCodeOut ([ref]$SC3) -BodyOut ([ref]$D3)
Write-Assert -name "S32-AC4-3 QRIS ref=value HTTP 201" -pass ($SC3 -eq 201) -detail ("actual=" + $SC3 + " msg=" + $D3.error)
if ($SC3 -eq 201 -and $D3.success) {
    Write-Assert -name "S32-AC4-3 QRIS paymentMethod=QRIS" -pass ($D3.data.sale.paymentMethod -eq "QRIS") -detail ("actual=" + $D3.data.sale.paymentMethod)
    Write-Assert -name ("S32-AC4-3 QRIS paymentReferenceNumber=" + $EXPECTED_REF3) -pass ($D3.data.sale.paymentReferenceNumber -eq $EXPECTED_REF3) -detail ("actual=" + $D3.data.sale.paymentReferenceNumber)
}

Write-Host ""
Write-Host "[5/6] Scenario 4: CREDIT_CARD ref='' empty -> reject 400 message CC" -ForegroundColor Yellow
$REF4 = [guid]::NewGuid()
$P4 = Make-StandardPayload -pm "CREDIT_CARD" -ref "" -refId $REF4
$B4 = $P4 | ConvertTo-Json -Depth 10
$SC4 = 0; $D4 = $null
Invoke-Api -Method Post -Uri ($BASE + "/sales") -Body $B4 -Headers $HEADERS -StatusCodeOut ([ref]$SC4) -BodyOut ([ref]$D4)
Write-Assert -name "S32-AC4-4 CC ref=empty HTTP 400" -pass ($SC4 -eq 400) -detail ("actual=" + $SC4)
if ($SC4 -eq 400) {
    if ($D4 -and $D4.error) {
        $MSG4 = $D4.error
    } else {
        $MSG4 = "EMPTY_OBJECT"
    }
    Write-Assert -name "S32-AC4-4 CC message ada 'kartu kredit'" -pass ($MSG4 -like "*kartu kredit*") -detail ("msg=" + $MSG4)
}

Write-Host ""
Write-Host "[6/6] Scenario 5: Idempotent POST#2 same UUID scenario#1 -> 200 OK" -ForegroundColor Yellow
$P5 = Make-StandardPayload -pm "CASH" -ref $null -refId $REF1
$B5 = $P5 | ConvertTo-Json -Depth 10
$SC5 = 0; $D5 = $null
Invoke-Api -Method Post -Uri ($BASE + "/sales") -Body $B5 -Headers $HEADERS -StatusCodeOut ([ref]$SC5) -BodyOut ([ref]$D5)
Write-Assert -name "S32-AC4-5 Idempotent POST#2 HTTP 200" -pass ($SC5 -eq 200) -detail ("actual=" + $SC5 + " msg=" + $D5.error)
if ($SC5 -eq 200 -and $D5.success -and $ID1) {
    Write-Assert -name "S32-AC4-5 Idempotent POST#2 id sama POST#1 (delta=1)" -pass ($D5.data.sale.id -eq $ID1) -detail ("id1=" + $ID1 + " id2=" + $D5.data.sale.id)
}

Write-Host ""
Write-Host "[7/7] Scenario 6: Invalid enum GO-PAY not in {CASH,QRIS,CREDIT_CARD} -> reject 4xx" -ForegroundColor Yellow
$REF6 = [guid]::NewGuid()
$P6 = Make-StandardPayload -pm "GO-PAY" -ref "GOPAY-001" -refId $REF6
$B6 = $P6 | ConvertTo-Json -Depth 10
$SC6 = 0; $D6 = $null
Invoke-Api -Method Post -Uri ($BASE + "/sales") -Body $B6 -Headers $HEADERS -StatusCodeOut ([ref]$SC6) -BodyOut ([ref]$D6)
Write-Assert -name "S32-AC4-6 Invalid enum GO-PAY HTTP 4xx reject" -pass ($SC6 -ge 400 -and $SC6 -lt 500) -detail ("actual=" + $SC6 + " msg=" + $D6.error)

Write-Host ""
Write-Host "=== S3.2 PAYMENT SMOKE: SUMMARY ===" -ForegroundColor Cyan
$ASSERTIONS | Format-Table -AutoSize | Out-String | Write-Host
Write-Host ("PASS: " + $SCRIPT_OK + " / FAIL: " + $SCRIPT_FAIL)
if ($SCRIPT_FAIL -gt 0) {
    Write-Host "RESULT: FAIL" -ForegroundColor Red
    exit 1
} else {
    Write-Host ("RESULT: ALL " + $ASSERTIONS.Count + " ASSERTIONS PASS - OK") -ForegroundColor Green
    exit 0
}
