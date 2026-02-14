const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const fs = require('fs');
const { query } = require('../db');

// Read keys
const privateKeyPath = process.env.JWT_PRIVATE_KEY_PATH || './keys/private.pem';
let privateKey;
try {
    privateKey = fs.readFileSync(privateKeyPath, 'utf8');
} catch (err) {
    console.error('Error reading private key:', err.message);
    process.exit(1);
}

const generateAccessToken = (user) => {
    return jwt.sign(
        {
            iss: 'jwt-auth-service',
            sub: user.username,
            roles: ['user'] // Default role
        },
        privateKey,
        { algorithm: 'RS256', expiresIn: '15m' }
    );
};

const generateRefreshToken = () => {
    // Random string or signed JWT? Requirement says "securely generated".
    // A random hex string is secure enough for opaque token, 
    // but if we want it to be stateless or contain data we can use JWT.
    // Requirement says: "Refresh tokens must be securely generated... valid for 7 days."
    // And "Success Response... refresh_token: string".
    // And "verify... expires_at timestamp is 7 days in the future."
    // Let's use crypto random string for opacity and store in DB.

    const crypto = require('crypto');
    return crypto.randomBytes(40).toString('hex');
};

exports.register = async (req, res) => {
    const { username, email, password } = req.body;

    // Validation
    if (!username || !email || !password) {
        return res.status(400).json({ error: 'bad_request', message: 'Missing fields' });
    }

    // Password strength check (1 number, 1 special char, min 8)
    const passwordRegex = /^(?=.*[0-9])(?=.*[!@#$%^&*])[a-zA-Z0-9!@#$%^&*]{8,}$/;
    if (!passwordRegex.test(password)) {
        return res.status(400).json({ error: 'bad_request', message: 'Password must be at least 8 characters with 1 number and 1 special character.' });
    }

    try {
        const hashedPassword = await bcrypt.hash(password, 10);

        // Insert user
        const result = await query(
            'INSERT INTO users (username, email, password_hash) VALUES ($1, $2, $3) RETURNING id, username',
            [username, email, hashedPassword]
        );

        res.status(201).json({
            id: result.rows[0].id,
            username: result.rows[0].username,
            message: 'User registered successfully'
        });
    } catch (err) {
        if (err.code === '23505') { // Unique violation
            return res.status(409).json({ error: 'conflict', message: 'Username or email already exists' });
        }
        console.error(err);
        res.status(500).json({ error: 'internal_server_error', message: 'Registration failed' });
    }
};

exports.login = async (req, res) => {
    const { username, password } = req.body;

    try {
        const result = await query('SELECT * FROM users WHERE username = $1', [username]);
        if (result.rows.length === 0) {
            return res.status(401).json({ error: 'unauthorized', message: 'Invalid username or password' });
        }

        const user = result.rows[0];
        const match = await bcrypt.compare(password, user.password_hash);

        if (!match) {
            return res.status(401).json({ error: 'unauthorized', message: 'Invalid username or password' });
        }

        const accessToken = generateAccessToken(user);
        const refreshToken = generateRefreshToken();
        const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days

        await query(
            'INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES ($1, $2, $3)',
            [user.id, refreshToken, expiresAt]
        );

        res.json({
            token_type: 'Bearer',
            access_token: accessToken,
            expires_in: 900,
            refresh_token: refreshToken
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'internal_server_error', message: 'Login failed' });
    }
};

exports.refresh = async (req, res) => {
    const { refresh_token } = req.body;

    if (!refresh_token) {
        return res.status(401).json({ error: 'unauthorized', message: 'Refresh token required' });
    }

    try {
        const result = await query('SELECT * FROM refresh_tokens WHERE token = $1', [refresh_token]);

        if (result.rows.length === 0) {
            return res.status(401).json({ error: 'unauthorized', message: 'Invalid refresh token' });
        }

        const tokenRecord = result.rows[0];
        if (new Date() > tokenRecord.expires_at) {
            // Clean up expired token
            await query('DELETE FROM refresh_tokens WHERE id = $1', [tokenRecord.id]);
            return res.status(401).json({ error: 'unauthorized', message: 'Refresh token expired' });
        }

        // Get user details
        const userResult = await query('SELECT * FROM users WHERE id = $1', [tokenRecord.user_id]);
        if (userResult.rows.length === 0) {
            return res.status(401).json({ error: 'unauthorized', message: 'User not found' });
        }
        const user = userResult.rows[0];

        // Issue new access token
        const newAccessToken = generateAccessToken(user);

        // Optional: Rotate refresh token here if desired (not strictly required but good practice)
        // Requirement says: "Refresh tokens... must be valid for 7 days."
        // It doesn't explicitly mandate rotation, but FAQ mentions it.
        // We will stick to simple refresh for now as per core requirement 9.

        res.json({
            token_type: 'Bearer',
            access_token: newAccessToken,
            expires_in: 900
        });

    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'internal_server_error', message: 'Refresh failed' });
    }
};

exports.logout = async (req, res) => {
    const { refresh_token } = req.body;

    if (!refresh_token) {
        return res.status(400).json({ error: 'bad_request', message: 'Refresh token required' });
    }

    try {
        await query('DELETE FROM refresh_tokens WHERE token = $1', [refresh_token]);
        res.status(204).send();
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'internal_server_error', message: 'Logout failed' });
    }
};
