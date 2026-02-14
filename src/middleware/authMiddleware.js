const jwt = require('jsonwebtoken');
const fs = require('fs');
const path = require('path');

// Read public key
const publicKeyPath = process.env.JWT_PUBLIC_KEY_PATH || './keys/public.pem';
// Ensure absolute path if needed, or relative to cwd. 
// In Docker, it's /app/keys/public.pem. Locally e:/.../keys/public.pem
// We'll try to read it. If it fails, we might need to resolve it.

let publicKey;
try {
    publicKey = fs.readFileSync(publicKeyPath, 'utf8');
} catch (err) {
    console.error('Error reading public key:', err.message);
    process.exit(1);
}

const verifyToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];

    if (!authHeader) {
        return res.status(401).json({ error: 'unauthorized', message: 'No token provided' });
    }

    const token = authHeader.split(' ')[1]; // Bearer <token>

    if (!token) {
        return res.status(401).json({ error: 'unauthorized', message: 'Malformed token' });
    }

    jwt.verify(token, publicKey, { algorithms: ['RS256'] }, (err, decoded) => {
        if (err) {
            if (err.name === 'TokenExpiredError') {
                return res.status(401).json({ error: 'token_expired', message: 'Access token has expired.' });
            }
            return res.status(401).json({ error: 'unauthorized', message: 'Invalid token' });
        }

        req.user = decoded;
        next();
    });
};

module.exports = { verifyToken, publicKey }; // Export publicKey for verify endpoint
