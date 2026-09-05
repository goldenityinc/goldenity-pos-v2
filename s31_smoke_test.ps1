$ErrorActionPreference = "Continue"
$base = "http://localhost:3001"

# Step 1 Login
$loginBody = @{ tenantSlug = "demo-fnb"; username = "admin"; password = "admin123" } | ConvertTo-Json
$loginRes = Invoke-RestMethod -Uri "$base/api/v1/auth/login" -Method Post -Body $loginBody -ContentType "application/json"
if (-not $loginRes.success) {
    "LOGIN_FAIL: $($loginRes.error)" | Out-File -FilePath "$env:TEMP\s31_smoke.log" -Append
    exit 1
}
$token = $loginRes.data.token
"LOGIN_OK token_len=$($token.Length)" | Out-File -FilePath "$env:TEMP\s31_smoke.log" -Force

$headers = @{ Authorization = "Bearer $token" }

# Step 2 Me
$meRes = Invoke-RestMethod -Uri "$base/api/v1/auth/me" -Method Get -Headers $headers -ContentType "application/json"
$branchIdValue = $meRes.data.user.branchId
$userIdValue = $meRes.data.user.userId
"ME_OK branch=$branchIdValue user=$userIdValue role=$($meRes.data.user.role)" | Out-File -FilePath "$env:TEMP\s31_smoke.log" -Append

# Step 3 Count Before
$listBefore = Invoke-RestMethod -Uri "$base/api/v1/sales/" -Method Get -Headers $headers -ContentType "application/json"
$countBefore = if ($listBefore.success -and $listBefore.data.sales) { $listBefore.data.sales.Count } else { 0 }
"COUNT_BEFORE=$countBefore" | Out-File -FilePath "$env:TEMP\s31_smoke.log" -Append

# Step 4 POST#1
$ref = [guid]::NewGuid().ToString()
"REF_ID=$ref" | Out-File -FilePath "$env:TEMP\s31_smoke.log" -Append

$salePayload = @{
    referenceId = $ref
    branchId = $branchIdValue
    orderType = "DINE_IN"
    items = @(
        @{
            productName = "TEST_PRODUCT_S31"
            qty = 2
            unitPrice = 15000
            lineTotal = 30000
            note = "smoke test s31"
        }
    )
    subtotal = 30000
    discountAmount = 0
    taxAmount = 3300
    serviceChargeAmount = 0
    serviceChargePercentage = $null
    total = 33300
    paymentMethod = "CASH"
    cashReceived = 35000
    cashChange = 1700
    status = "COMPLETED"
} | ConvertTo-Json -Depth 10

try {
    $post1 = Invoke-RestMethod -Uri "$base/api/v1/sales/" -Method Post -Body $salePayload -Headers $headers -ContentType "application/json"
    "POST1_SUCCESS success=$($post1.success) id=$($post1.data.sale.id) idempotent=$($post1.data.idempotent)" | Out-File -FilePath "$env:TEMP\s31_smoke.log" -Append
    "POST1_SC=201_ASSUMED" | Out-File -FilePath "$env:TEMP\s31_smoke.log" -Append
} catch {
    $status = $_.Exception.Response.StatusCode.value__
    "POST1_FAIL status=$status msg=$($_.Exception.Message)" | Out-File -FilePath "$env:TEMP\s31_smoke.log" -Append
    $_.Exception.Response | Out-File -FilePath "$env:TEMP\s31_smoke.log" -Append
}

# Step 5 POST#2 same ref - idempotent
try {
    $post2 = Invoke-RestMethod -Uri "$base/api/v1/sales/" -Method Post -Body $salePayload -Headers $headers -ContentType "application/json"
    "POST2_SUCCESS success=$($post2.success) id=$($post2.data.sale.id) idempotent=$($post2.data.idempotent)" | Out-File -FilePath "$env:TEMP\s31_smoke.log" -Append
} catch {
    $status2 = $_.Exception.Response.StatusCode.value__
    "POST2_FAIL status=$status2 msg=$($_.Exception.Message)" | Out-File -FilePath "$env:TEMP\s31_smoke.log" -Append
}

# Step 6 Count After
$listAfter = Invoke-RestMethod -Uri "$base/api/v1/sales/" -Method Get -Headers $headers -ContentType "application/json"
$countAfter = if ($listAfter.success -and $listAfter.data.sales) { $listAfter.data.sales.Count } else { 0 }
$delta = $countAfter - $countBefore
"COUNT_AFTER=$countAfter DELTA=$delta (EXPECTED=1)" | Out-File -FilePath "$env:TEMP\s31_smoke.log" -Append

# Step 7 test branch required (kirim tanpa branchId dan user punya branch tapi payload tanpa branchId - pakai user.branchId harus ok dulu)
$saleNoBranchPayload = @{
    referenceId = [guid]::NewGuid().ToString()
    orderType = "DINE_IN"
    items = @(
        @{
            productName = "TEST_NO_BRANCH"
            qty = 1
            unitPrice = 1000
            lineTotal = 1000
        }
    )
    subtotal = 1000
    discountAmount = 0
    taxAmount = 110
    serviceChargeAmount = 0
    serviceChargePercentage = $null
    total = 1110
    paymentMethod = "CASH"
    status = "COMPLETED"
} | ConvertTo-Json -Depth 10
try {
    $postBranchOk = Invoke-RestMethod -Uri "$base/api/v1/sales/" -Method Post -Body $saleNoBranchPayload -Headers $headers -ContentType "application/json"
    "POST_NO_BRANCH_IN_USER success=$($postBranchOk.success) branchId used=$($postBranchOk.data.sale.branchId)" | Out-File -FilePath "$env:TEMP\s31_smoke.log" -Append
} catch {
    $status3 = $_.Exception.Response.StatusCode.value__
    $body = $_.ErrorDetails.Message
    "POST_NO_BRANCH_IN_USER status=$status3 body=$body" | Out-File -FilePath "$env:TEMP\s31_smoke.log" -Append
}

# Step 8 last sale info include serviceCharge fields
if ($listAfter.success -and $listAfter.data.sales.Count -gt 0) {
    $last = $listAfter.data.sales[0]
    "LAST_SALE id=$($last.id) subtotal=$($last.subtotal) svcAmt=$($last.serviceChargeAmount) svcPct=$($last.serviceChargePercentage) total=$($last.total)" | Out-File -FilePath "$env:TEMP\s31_smoke.log" -Append
}

"DONE" | Out-File -FilePath "$env:TEMP\s31_smoke.log" -Append
exit 0
