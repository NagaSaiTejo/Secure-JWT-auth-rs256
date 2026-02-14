$BASE_URL = "http://localhost:8080"
Write-Host "Starting Auth Flow Test..." -ForegroundColor Cyan

# 1. Register a new user
Write-Host "---------------------------------------------------"
Write-Host "1. Registering new user..."
$TIMESTAMP = Get-Date -UFormat %s
$USERNAME = "user_$TIMESTAMP" -replace "[.,]", ""
$EMAIL = "$USERNAME@example.com"
$PASSWORD = "Password1!"

$BODY = @{
    username = $USERNAME
    email = $EMAIL
    password = $PASSWORD
} | ConvertTo-Json

try {
    $REGISTER_RESPONSE = Invoke-RestMethod -Uri "$BASE_URL/auth/register" -Method Post -Body $BODY -ContentType "application/json"
    Write-Host "Response: $($REGISTER_RESPONSE | ConvertTo-Json -Depth 2)"
    Write-Host "✅ Registration successful" -ForegroundColor Green
} catch {
    Write-Host "❌ Registration failed: $_" -ForegroundColor Red
    exit 1
}

# 2. Login
Write-Host "---------------------------------------------------"
Write-Host "2. Logging in..."
$LOGIN_BODY = @{
    username = $USERNAME
    password = $PASSWORD
} | ConvertTo-Json

try {
    $LOGIN_RESPONSE = Invoke-RestMethod -Uri "$BASE_URL/auth/login" -Method Post -Body $LOGIN_BODY -ContentType "application/json"
    Write-Host "Response: $($LOGIN_RESPONSE | ConvertTo-Json -Depth 2)"
    $ACCESS_TOKEN = $LOGIN_RESPONSE.access_token
    $REFRESH_TOKEN = $LOGIN_RESPONSE.refresh_token
    
    if (-not [string]::IsNullOrEmpty($ACCESS_TOKEN)) {
        Write-Host "✅ Login successful. Access Token received." -ForegroundColor Green
    } else {
        throw "No access token"
    }
} catch {
    Write-Host "❌ Login failed: $_" -ForegroundColor Red
    exit 1
}

# 3. Access Protected Route
Write-Host "---------------------------------------------------"
Write-Host "3. Accessing Protected Route (/api/profile)..."
try {
    $HEADERS = @{ Authorization = "Bearer $ACCESS_TOKEN" }
    $PROFILE_RESPONSE = Invoke-RestMethod -Uri "$BASE_URL/api/profile" -Method Get -Headers $HEADERS
    Write-Host "Response: $($PROFILE_RESPONSE | ConvertTo-Json -Depth 2)"

    if ($PROFILE_RESPONSE.username -eq $USERNAME) {
        Write-Host "✅ Profile access successful" -ForegroundColor Green
    } else {
        throw "Username mismatch"
    }
} catch {
    Write-Host "❌ Profile access failed: $_" -ForegroundColor Red
    exit 1
}

# 4. Verify Token
Write-Host "---------------------------------------------------"
Write-Host "4. Verifying Token (/api/verify-token)..."
try {
    $VERIFY_RESPONSE = Invoke-RestMethod -Uri "$BASE_URL/api/verify-token?token=$ACCESS_TOKEN" -Method Get
    Write-Host "Response: $($VERIFY_RESPONSE | ConvertTo-Json -Depth 2)"

    if ($VERIFY_RESPONSE.valid -eq $true) {
        Write-Host "✅ Token verification successful" -ForegroundColor Green
    } else {
        throw "Token invalid"
    }
} catch {
    Write-Host "❌ Token verification failed: $_" -ForegroundColor Red
    exit 1
}

# 5. Refresh Token
Write-Host "---------------------------------------------------"
Write-Host "5. Refreshing Token..."
$REFRESH_BODY = @{
    refresh_token = $REFRESH_TOKEN
} | ConvertTo-Json

try {
    $REFRESH_RESPONSE = Invoke-RestMethod -Uri "$BASE_URL/auth/refresh" -Method Post -Body $REFRESH_BODY -ContentType "application/json"
    Write-Host "Response: $($REFRESH_RESPONSE | ConvertTo-Json -Depth 2)"
    $NEW_ACCESS_TOKEN = $REFRESH_RESPONSE.access_token

    if (-not [string]::IsNullOrEmpty($NEW_ACCESS_TOKEN)) {
        Write-Host "✅ Token refresh successful" -ForegroundColor Green
    } else {
        throw "No new access token"
    }
} catch {
    Write-Host "❌ Token refresh failed: $_" -ForegroundColor Red
    exit 1
}

# 6. Access Protected Route with New Token
Write-Host "---------------------------------------------------"
Write-Host "6. Accessing Protected Route with NEW Token..."
try {
    $HEADERS_NEW = @{ Authorization = "Bearer $NEW_ACCESS_TOKEN" }
    $PROFILE_RESPONSE_2 = Invoke-RestMethod -Uri "$BASE_URL/api/profile" -Method Get -Headers $HEADERS_NEW
    Write-Host "Response: $($PROFILE_RESPONSE_2 | ConvertTo-Json -Depth 2)"

    if ($PROFILE_RESPONSE_2.username -eq $USERNAME) {
        Write-Host "✅ Profile access with new token successful" -ForegroundColor Green
    } else {
        throw "Username mismatch"
    }
} catch {
    Write-Host "❌ Profile access with new token failed: $_" -ForegroundColor Red
    exit 1
}

# 7. Logout
Write-Host "---------------------------------------------------"
Write-Host "7. Logging out..."
$LOGOUT_BODY = @{
    refresh_token = $REFRESH_TOKEN
} | ConvertTo-Json

try {
    Invoke-RestMethod -Uri "$BASE_URL/auth/logout" -Method Post -Body $LOGOUT_BODY -ContentType "application/json"
    Write-Host "✅ Logout successful (204 No Content)" -ForegroundColor Green
} catch {
    Write-Host "❌ Logout failed: $_" -ForegroundColor Red
    exit 1
}

# 8. Rate Limit Check
Write-Host "---------------------------------------------------"
Write-Host "8. Testing Rate Limit (5 attempts)..."
for ($i = 1; $i -le 6; $i++) {
    Write-Host "Attempt $i..."
    $BAD_LOGIN = @{ username = $USERNAME; password = "WrongPassword" } | ConvertTo-Json
    try {
        Invoke-RestMethod -Uri "$BASE_URL/auth/login" -Method Post -Body $BAD_LOGIN -ContentType "application/json"
    } catch {
        $STATUS = $_.Exception.Response.StatusCode.value__
        if ($STATUS -eq 429) {
            Write-Host "✅ Rate limit triggered on attempt $i (Status 429)" -ForegroundColor Green
            break
        }
        if ($i -eq 6) {
             Write-Host "❌ Rate limit NOT triggered after 6 attempts" -ForegroundColor Red
        }
    }
}

Write-Host "---------------------------------------------------"
Write-Host "Test Flow Completed Successfully!" -ForegroundColor Cyan
