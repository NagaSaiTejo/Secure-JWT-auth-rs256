#!/bin/bash
# Create keys directory if it doesn't exist
mkdir -p keys

# Generate private key (2048 bits)
openssl genrsa -out keys/private.pem 2048

# Extract public key
openssl rsa -in keys/private.pem -pubout -out keys/public.pem

# Set permissions (optional on Windows standard fs, but good practice for scripts)
chmod 600 keys/private.pem
chmod 644 keys/public.pem

echo "Keys generated in keys/"
