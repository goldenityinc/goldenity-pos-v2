$ErrorActionPreference = "SilentlyContinue"
$base = "http://localhost:3001"

$loginBody = @{ tenantSlug = "demo-fnb"; username = "admin"; password = "admin123" } | ConvertTo-Json
$loginRes = Invoke-RestMethod -Uri "$base/api/v1/auth/login" -Method Post -Body $loginBody -ContentType "application/json"
$t = $loginRes.data.token
$h = @{ Authorization = "Bearer $t" }

$meRes = Invoke-RestMethod -Uri "$base/api/v1/auth/me" -Method Get -Headers $h -ContentType "application/json"
$branch = $meRes.data.user.branchId
"BRANCH=$branch" | Out-File "$env:TEMP\s31_status.log" -Force

$ref = [guid]::NewGuid().ToString()
"REF=$ref" | Out-File "$env:TEMP\s31_status.log" -Append

$payload = @{
    referenceId = $ref
    branchId = $branch
    orderType = "DINE_IN"
    items = @(
        @{
            productName = "STATUS_CHECK_PROD"
            qty = 1
            unitPrice = 20000
            lineTotal = 20000
        }
    )
    subtotal = 20000
    discountAmount = 0
    taxAmount = 2200
    serviceChargeAmount = 1000
    serviceChargePercentage = 5
    total = 23200
    paymentMethod = "QRIS"
    status = "COMPLETED"
} | ConvertTo-Json -Depth 10

# POST#1 actual status code
try {
    $resp1 = Invoke-WebRequest -Uri "$base/api/v1/sales/" -Method Post -Body $payload -Headers $h -ContentType "application/json" -UseBasicParsing
    $sc1 = [int]$resp1.StatusCode
    $body1 = $resp1.Content | ConvertFrom-Json
    "POST1_STATUS=$sc1 IDEMPOTENT=$($body1.data.idempotent)" | Out-File "$env:TEMP\s31_status.log" -Append
} catch {
    $err = $_.Exception.Response
    $statusCode = [int]$err.StatusCode
    $rbody = New-Object System.IO.StreamReader($err.GetResponseStream())
    $content = $rbody.ReadToEnd()
    "POST1_FAIL_STATUS=$statusCode BODY=$content" | Out-File "$env:TEMP\s31_status.log" -Append
}

# POST#2 SAME REF
try {
    $resp2 = Invoke-WebRequest -Uri "$base/api/v1/sales/" -Method Post -Body $payload -Headers $h -ContentType "application/json" -UseBasicParsing
    $sc2 = [int]$resp2.StatusCode
    $body2 = $resp2.Content | ConvertFrom-Json
    "POST2_STATUS=$sc2 IDEMPOTENT=$($body2.data.idempotent)" | Out-File "$env:TEMP\s31_status.log" -Append
} catch {
    $err2 = $_.Exception.Response
    $statusCode2 = [int]$err2.StatusCode
    "POST2_FAIL_STATUS=$statusCode2" | Out-File "$env:TEMP\s31_status.log" -Append
}

# Check service charge value tersimpan
$list = Invoke-RestMethod -Uri "$base/api/v1/sales/" -Method Get -Headers $h -ContentType "application/json"
$top = $list.data.sales[0]
"LAST_RECORD svcAmt=$($top.serviceChargeAmount) svcPct=$($top.serviceChargePercentage) subtotal=$($top.subtotal) total=$($top.total)" | Out-File "$env:TEMP\s31_status.log" -Append
"FORMULA_CHECK: subtotal-discount+tax+svc = $($top.subtotal) - 0 + $($top.taxAmount) + $($top.serviceChargeAmount) = $([decimal]$top.subtotal - 0 + [decimal]$top.taxAmount + [decimal]$top.serviceChargeAmount) == total=$($top.total)" | Out-File "$env:TEMP\s31_status.log" -Append

"DONE" | Out-File "$env:TEMP\s31_status.log" -Append
