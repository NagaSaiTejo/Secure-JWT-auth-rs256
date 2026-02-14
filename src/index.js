const express = require('express');
const dotenv = require('dotenv');
const morgan = require('morgan');
const { createTables } = require('./db');

dotenv.config();

const app = express();
const PORT = process.env.API_PORT || 8080;

app.use(express.json());
app.use(morgan('combined'));

// Health check endpoint
app.get('/health', (req, res) => {
    res.status(200).send('OK');
});

const authController = require('./controllers/authController');
const apiController = require('./controllers/apiController');
const { verifyToken } = require('./middleware/authMiddleware');
const loginRateLimiter = require('./middleware/rateLimitMiddleware');

// Auth Routes
app.post('/auth/register', authController.register);
app.post('/auth/login', loginRateLimiter, authController.login);
app.post('/auth/refresh', authController.refresh);
app.post('/auth/logout', authController.logout);

// API Routes
app.get('/api/profile', verifyToken, apiController.getProfile);
app.get('/api/verify-token', apiController.verifyToken);

// Error handling middleware
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({ error: 'internal_server_error', message: 'Something went wrong!' });
});

// Start server
const startServer = async () => {
    await createTables();
    app.listen(PORT, () => {
        console.log(`Server is running on port ${PORT}`);
    });
};

startServer();
