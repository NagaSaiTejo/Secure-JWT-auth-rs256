#!/bin/bash

BASE_URL="http://localhost:8080"
echo "Starting Auth Flow Test..."

# 1. Register a new user
echo "---------------------------------------------------"
echo "1. Registering new user..."
USERNAME="user_$(date +%s)"
EMAIL="${USERNAME}@example.com"
PASSWORD="Password1!"

REGISTER_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"$USERNAME\", \"email\": \"$EMAIL\", \"password\": \"$PASSWORD\"}")

echo "Response: $REGISTER_RESPONSE"

# Check if registration was successful
if echo "$REGISTER_RESPONSE" | grep -q "User registered successfully"; then
  echo "✅ Registration successful"
else
  echo "❌ Registration failed"
  exit 1
fi

# 2. Login
echo "---------------------------------------------------"
echo "2. Logging in..."
LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"$USERNAME\", \"password\": \"$PASSWORD\"}")

echo "Response: $LOGIN_RESPONSE"

ACCESS_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.access_token')
REFRESH_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.refresh_token')

if [ "$ACCESS_TOKEN" != "null" ] && [ "$ACCESS_TOKEN" != "" ]; then
  echo "✅ Login successful. Access Token received."
else
  echo "❌ Login failed"
  exit 1
fi

# 3. Access Protected Route
echo "---------------------------------------------------"
echo "3. Accessing Protected Route (/api/profile)..."
PROFILE_RESPONSE=$(curl -s -X GET "$BASE_URL/api/profile" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

echo "Response: $PROFILE_RESPONSE"

if echo "$PROFILE_RESPONSE" | grep -q "$USERNAME"; then
  echo "✅ Profile access successful"
else
  echo "❌ Profile access failed"
  exit 1
fi

# 4. Verification Endpoint
echo "---------------------------------------------------"
echo "4. Verifying Token (/api/verify-token)..."
VERIFY_RESPONSE=$(curl -s -X GET "$BASE_URL/api/verify-token?token=$ACCESS_TOKEN")

echo "Response: $VERIFY_RESPONSE"

if echo "$VERIFY_RESPONSE" | grep -q "true"; then
  echo "✅ Token verification successful"
else
  echo "❌ Token verification failed"
  exit 1
fi

# 5. Refresh Token
echo "---------------------------------------------------"
echo "5. Refreshing Token..."
REFRESH_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/refresh" \
  -H "Content-Type: application/json" \
  -d "{\"refresh_token\": \"$REFRESH_TOKEN\"}")

echo "Response: $REFRESH_RESPONSE"

NEW_ACCESS_TOKEN=$(echo "$REFRESH_RESPONSE" | jq -r '.access_token')

if [ "$NEW_ACCESS_TOKEN" != "null" ] && [ "$NEW_ACCESS_TOKEN" != "" ]; then
  echo "✅ Token refresh successful"
else
  echo "❌ Token refresh failed"
  exit 1
fi

# 6. Access Protected Route with New Token
echo "---------------------------------------------------"
echo "6. Accessing Protected Route with NEW Token..."
PROFILE_RESPONSE_2=$(curl -s -X GET "$BASE_URL/api/profile" \
  -H "Authorization: Bearer $NEW_ACCESS_TOKEN")

echo "Response: $PROFILE_RESPONSE_2"

if echo "$PROFILE_RESPONSE_2" | grep -q "$USERNAME"; then
  echo "✅ Profile access with new token successful"
else
  echo "❌ Profile access with new token failed"
  exit 1
fi

# 7. Logout
echo "---------------------------------------------------"
echo "7. Logging out..."
LOGOUT_RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null -X POST "$BASE_URL/auth/logout" \
  -H "Content-Type: application/json" \
  -d "{\"refresh_token\": \"$REFRESH_TOKEN\"}")

echo "Response Code: $LOGOUT_RESPONSE"

if [ "$LOGOUT_RESPONSE" == "204" ]; then
  echo "✅ Logout successful"
else
  echo "❌ Logout failed"
  exit 1
fi

# 8. Rate Limit Check (Optional Demo)
echo "---------------------------------------------------"
echo "8. Testing Rate Limit (5 attempts)..."
for i in {1..6}; do
  echo "Attempt $i..."
  start_time=$(date +%s%N)
  # Wrong password to trigger login failure
  RESP=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\": \"$USERNAME\", \"password\": \"WrongPass\"}")
  
  if [ "$RESP" == "429" ]; then
    echo "✅ Rate limit triggered on attempt $i (Status 429)"
    break
  elif [ "$i" -eq 6 ]; then
     echo "❌ Rate limit NOT triggered after 6 attempts"
  fi
done

echo "---------------------------------------------------"
echo "Test Flow Completed Successfully!"