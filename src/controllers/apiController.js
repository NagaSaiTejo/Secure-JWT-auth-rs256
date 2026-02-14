const jwt = require('jsonwebtoken');
const fs = require('fs');

const publicKeyPath = process.env.JWT_PUBLIC_KEY_PATH || './keys/public.pem';
let publicKey;
try {
    publicKey = fs.readFileSync(publicKeyPath, 'utf8');
} catch (err) {
    // handled in authMiddleware usually
}


exports.getProfile = (req, res) => {
    // user is populated by authMiddleware
    const { sub, roles } = req.user;
    // We might want to fetch more details from DB if needed, 
    // but requirements say: "Success Response... id, username, email, roles"
    // The JWT contains sub (username), but maybe not email/id/roles unless we put them there.
    // Wait, Requirement 8 says claims: iss, sub, iat, exp, roles. 
    // It DOES NOT say email or id in JWT. 
    // So we probably need to fetch user from DB using 'sub' (username).

    const { query } = require('../db');

    query('SELECT id, username, email FROM users WHERE username = $1', [sub])
        .then(result => {
            if (result.rows.length === 0) {
                return res.status(404).json({ error: 'not_found', message: 'User not found' });
            }
            const user = result.rows[0];
            res.json({
                id: user.id,
                username: user.username,
                email: user.email,
                roles: roles || ['user']
            });
        })
        .catch(err => {
            console.error(err);
            res.status(500).json({ error: 'internal_server_error', message: 'Error fetching profile' });
        });
};

exports.verifyToken = (req, res) => {
    const { token } = req.query;

    if (!token) {
        return res.status(400).json({ valid: false, reason: 'Token is missing' });
    }

    jwt.verify(token, publicKey, { algorithms: ['RS256'] }, (err, decoded) => {
        if (err) {
            return res.json({ valid: false, reason: err.message });
        }

        res.json({
            valid: true,
            claims: decoded
        });
    });
};
