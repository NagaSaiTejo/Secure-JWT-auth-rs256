# Secure JWT Authentication Service

A secure, stateless authentication API using JSON Web Tokens (JWTs) with RSA asymmetric encryption, built with Node.js, Express, and PostgreSQL.

## Features
- **Secure Authentication**: RSA-2048 specific JWTs.
- **Token Management**: Access tokens (15m) and Refresh tokens (7d).
- **Security**: 
    - Password hashing with `bcrypt`.
    - Rate limiting on login (5 attempts/min).
    - HttpOnly-ready token structure (though API returns JSON).
- **Containerization**: Fully dockerized with `docker-compose`.
- **Database**: PostgreSQL with automatic schema initialization.

## Prerequisites
- Docker & Docker Compose
- OpenSSL (for key generation)

## Setup & Run

1. **Generate Keys**
   The application requires RSA keys to sign and verify tokens.
   ```bash
   sh generate-keys.sh
   # Or manually:
   # mkdir keys
   # openssl genrsa -out keys/private.pem 2048
   # openssl rsa -in keys/private.pem -pubout -out keys/public.pem
   ```

2. **Configuration**
   Copy the example environment file:
   ```bash
   cp .env.example .env
   ```
   Modify `.env` if needed (defaults function with Docker).

3. **Start Application**
   Build and run the services:
   ```bash
   docker-compose up --build
   ```
   The API will be available at `http://localhost:8080`.

## API Endpoints

### Auth
- `POST /auth/register`: Register a new user.
- `POST /auth/login`: Login to receive Access and Refresh tokens.
- `POST /auth/refresh`: Get a new Access token using a Refresh token.
- `POST /auth/logout`: Revoke a Refresh token.

### API
- `GET /api/profile`: Protected route (requires valid Access token).
- `GET /api/verify-token`: Publicly verify a token's validity.

## Testing

A script is provided to test the full authentication flow:
### Linux/Mac/Git Bash
```bash
sh test-auth-flow.sh
```

### Windows (PowerShell)
```powershell
.\test-auth-flow.ps1
```
Ensure `jq` and `curl` are installed for the shell script. The PowerShell script uses native cmdlets.

## Project Structure
- `src/`: Source code
  - `controllers/`: Request handlers
  - `middleware/`: Auth and Rate Limit middleware
  - `db/`: Database connection and schema
- `keys/`: Generated RSA keys (not in git)
- `docker-compose.yml`: Docker services orchestration
