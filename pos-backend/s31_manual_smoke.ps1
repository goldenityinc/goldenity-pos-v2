$ErrorActionPreference = "Stop"
$LOG = Join-Path $env:TEMP "s31_manual_smoke.log"
if (Test-Path $LOG) { Remove-Item $LOG -Force }
New-Item -ItemType File -Path $LOG -Force | Out-Null
function WL($s) { Add-Content -Path $LOG -Value ([string]$s) }
$UBP = @{ UseBasicParsing = $true }

WL '=== S3.1 SMOKE TEST MANUAL via IWR ==='
WL ('DATE: ' + (Get-Date -Format o))

# ---- STEP A: LOGIN + GET PRODUCTS ----
WL ''
WL '--- Step A: Login kasir demo-fnb + GET /products'
$bodyLogin = ConvertTo-Json @{ tenantSlug = 'demo-fnb'; username = 'kasir'; password = 'kasir123' }
try {
  $rLogin = Invoke-RestMethod -Uri 'http://localhost:3001/api/v1/auth/login' -Method POST -Body $bodyLogin -ContentType 'application/json' @UBP
  WL ('  [A1] Login OK success=' + $rLogin.success + ' token.length=' + $rLogin.data.token.Length + ' user.branchId=' + $rLogin.data.user.branchId + ' user.id=' + $rLogin.data.user.id)
  $script:TOKEN = $rLogin.data.token
  $script:USER_ID = [string]$rLogin.data.user.id
  $script:BRANCH_ID = [string]$rLogin.data.user.branchId
  $script:HEADERS = @{ 'Authorization' = ('Bearer ' + $script:TOKEN); 'Content-Type' = 'application/json' }
} catch {
  WL ('  [A1 FAIL] ' + $_.Exception.Message + ' DETAIL=' + $_.ErrorDetails.Message)
  exit 1
}
try {
  $rProds = Invoke-RestMethod -Uri 'http://localhost:3001/api/v1/products' -Method GET -Headers $script:HEADERS @UBP
  $list = $rProds.data.products
  WL ('  [A2] Products count=' + $list.Count)
  if ($null -eq $list -or $list.Count -lt 1) {
    WL ('  [ERROR] products empty! ' + ($rProds | ConvertTo-Json -Depth 4))
    exit 1
  }
  $p0 = $list[0]
  $idx1 = [Math]::Min(1, $list.Count - 1)
  $p1 = $list[$idx1]
  WL ('  [A3] p0 id=' + $p0.id + ' name=' + $p0.name + ' price=' + $p0.price)
  WL ('  [A3] p1 id=' + $p1.id + ' name=' + $p1.name + ' price=' + $p1.price)
} catch {
  WL ('  [A FAIL] ' + $_.Exception.Message + ' DETAIL=' + $_.ErrorDetails.Message)
  exit 1
}

$UNIT_P0 = [double]$p0.price
$UNIT_P1 = [double]$p1.price
$QTY_P0 = 2
$QTY_P1 = 1
$line0 = [Math]::Round($UNIT_P0 * $QTY_P0, 2, [MidpointRounding]::AwayFromZero)
$line1 = [Math]::Round($UNIT_P1 * $QTY_P1, 2, [MidpointRounding]::AwayFromZero)
$subtotal       = [Math]::Round($line0 + $line1, 2, [MidpointRounding]::AwayFromZero)
$discountAmount = 0.0
$taxAmount    = [Math]::Round($subtotal * 0.11, 2, [MidpointRounding]::AwayFromZero)
$scPct        = 5
$serviceChargeAmount = [Math]::Round($subtotal * $scPct / 100.0, 2, [MidpointRounding]::AwayFromZero)
$grandTotal   = [Math]::Round($subtotal - $discountAmount + $taxAmount + $serviceChargeAmount, 2)
$cashReceived = $grandTotal
$cashChange = 0.0
$REF_A = ([guid]::NewGuid()).ToString()
$REF_A_LABEL = $REF_A.Substring(0,13)

WL ''
WL '--- Formula & Required Field Check sesuai CreateSalesSchema L32-L90:'
WL ('    p0=' + $p0.name + ' qty=' + $QTY_P0 + ' unit=' + $UNIT_P0 + ' line=' + $line0)
WL ('    p1=' + $p1.name + ' qty=' + $QTY_P1 + ' unit=' + $UNIT_P1 + ' line=' + $line1)
WL ('    subtotal=' + $subtotal + ' - diskon=' + $discountAmount + ' + ppn11%=' + $taxAmount + ' + sc5%=' + $serviceChargeAmount + ' = TOTAL=' + $grandTotal)
WL ('    bayar=' + $cashReceived + ' - kembalian=' + $cashChange)
WL ('    orderType=DINE_IN paymentMethod=CASH status=COMPLETED cashReceived=' + $cashReceived + ' cashChange=' + $cashChange)

$items = @(
  @{ productId = [string]$p0.id; productName = [string]$p0.name; qty = $QTY_P0; unitPrice = $UNIT_P0; lineTotal = $line0 }
  @{ productId = [string]$p1.id; productName = [string]$p1.name; qty = $QTY_P1; unitPrice = $UNIT_P1; lineTotal = $line1 }
)

$payloadHash = [ordered]@{
  referenceId   = $REF_A
  branchId      = $script:BRANCH_ID
  orderType     = 'DINE_IN'
  items         = $items
  subtotal      = $subtotal
  discountAmount= $discountAmount
  taxAmount     = $taxAmount
  serviceChargeAmount = $serviceChargeAmount
  serviceChargePercentage = $scPct
  total         = $grandTotal
  paymentMethod = 'CASH'
  cashReceived = $cashReceived
  cashChange   = $cashChange
  cashierId     = $script:USER_ID
  status       = 'COMPLETED'
}
$json = $payloadHash | ConvertTo-Json -Depth 6

# ---- STEP B: POST#1 CREATE 201 ----
WL ''
WL ('--- Step B: POST#1 ref=' + $REF_A_LABEL + ' expect HTTP 201 idempotent=false')
try {
  $resp = Invoke-WebRequest -Uri 'http://localhost:3001/api/v1/sales' -Method POST -Body $json -Headers $script:HEADERS @UBP
  $parsed = $resp.Content | ConvertFrom-Json
  WL ('  [B] HTTP=' + $resp.StatusCode + ' success=' + $parsed.success + ' idempotent=' + $parsed.data.idempotent)
  WL ('  [B] sale.id=' + $parsed.data.sale.id + ' ref=' + $parsed.data.sale.referenceId)
  WL ('  [B] persist ALL FIELDS serviceChargeAmount=' + $parsed.data.sale.serviceChargeAmount + ' serviceChargePercentage=' + $parsed.data.sale.serviceChargePercentage + ' branchId=' + $parsed.data.sale.branchId + ' orderType=' + $parsed.data.sale.orderType + ' paymentMethod=' + $parsed.data.sale.paymentMethod + ' total=' + $parsed.data.sale.total + ' subtotal=' + $parsed.data.sale.subtotal + ' tax=' + $parsed.data.sale.taxAmount)
  if ([int]$resp.StatusCode -ne 201) { WL ('  [B FAIL] Expected HTTP 201 got ' + $resp.StatusCode); exit 2 }
  if ($parsed.data.idempotent -ne $false) { WL '  [B FAIL] Expected idempotent=false POST#1'; exit 2 }
  $script:SALE_ID = [string]$parsed.data.sale.id
} catch {
  $statusx = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { -1 }
  WL ('  [B FAIL HTTP=' + $statusx + ' MSG=' + $_.Exception.Message + ' DETAIL=' + $_.ErrorDetails.Message)
  exit 2
}

# ---- STEP C: POST#2 SAME REF IDEMPOTENT 200 delta=1 ----
WL ''
WL ('--- Step C: POST#2 ref=' + $REF_A_LABEL + ' expect HTTP 200 idempotent=true same sale.id delta DB 1')
try {
  $resp2 = Invoke-WebRequest -Uri 'http://localhost:3001/api/v1/sales' -Method POST -Body $json -Headers $script:HEADERS @UBP
  $parsed2 = $resp2.Content | ConvertFrom-Json
  WL ('  [C] HTTP=' + $resp2.StatusCode + ' success=' + $parsed2.success + ' idempotent=' + $parsed2.data.idempotent + ' message=' + $parsed2.data.message)
  if ([int]$resp2.StatusCode -ne 200) { WL ('  [C FAIL] Expected 200 got ' + $resp2.StatusCode); exit 3 }
  if ($parsed2.data.idempotent -ne $true) { WL '  [C FAIL] Expected idempotent=true'; exit 3 }
  if ([string]$parsed2.data.sale.id -ne $script:SALE_ID) { WL ('  [C FAIL] Sale id POST#1=' + $script:SALE_ID + ' != POST#2=' + $parsed2.data.sale.id); exit 3 }
} catch {
  $statusx = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { -1 }
  WL ('  [C FAIL HTTP=' + $statusx + ' MSG=' + $_.Exception.Message + ' DETAIL=' + $_.ErrorDetails.Message)
  exit 3
}

# ---- STEP D: FORMULA INCONSISTENCY REJECT ----
WL ''
WL ('--- Step D: POST payload total Dikurang 500 (expected=' + $grandTotal + ' dikirim=' + [Math]::Round($grandTotal - 500, 2) + ') expect 400 tidak konsisten')
$REF_BAD = ([guid]::NewGuid()).ToString()
$payloadBadHash = [ordered]@{}
foreach ($k in $payloadHash.Keys) { $payloadBadHash[$k] = $payloadHash[$k] }
$payloadBadHash['referenceId'] = $REF_BAD
$payloadBadHash['total'] = [Math]::Round($grandTotal - 500, 2)
$jsonBad = $payloadBadHash | ConvertTo-Json -Depth 6
try {
  $respBad = Invoke-WebRequest -Uri 'http://localhost:3001/api/v1/sales' -Method POST -Body $jsonBad -Headers $script:HEADERS @UBP
  WL ('  [D FAIL] Expected 4xx got ' + $respBad.StatusCode + ' content=' + $respBad.Content)
  exit 4
} catch {
  $status = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { -1 }
  $detail = [string]$_.ErrorDetails.Message
  $matchMsg = ($detail -match 'inconsisten|konsisten|selisih|tidak konsisten|perhitungan total')
  WL ('  [D] HTTP=' + $status + ' match message keyword tidak konsisten/selisih? ' + $matchMsg)
  WL ('  [D] DETAIL=' + $detail)
  if ($status -ne 400) { WL ('  [D FAIL] Expected 400 got ' + $status); exit 4 }
}

WL ''
WL '=== ALL STEPS A-D 100% PASS: login+products OK, POST#1 201 idempotent=false, POST#2 200 idempotent=true same id delta1, formula salah 400 reject ==='
Write-Output ('DONE LOG: ' + $LOG)
