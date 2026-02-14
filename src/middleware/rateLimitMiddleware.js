const { RateLimiterMemory } = require('rate-limiter-flexible');

const rateLimiter = new RateLimiterMemory({
    points: 5, // 5 requests
    duration: 60, // per 60 seconds (1 minute)
});

const loginRateLimiter = (req, res, next) => {
    rateLimiter.consume(req.ip)
        .then(() => {
            next();
        })
        .catch((rateLimiterRes) => {
            res.status(429).set({
                'Retry-After': Math.round(rateLimiterRes.msBeforeNext / 1000),
                'X-RateLimit-Limit': 5,
                'X-RateLimit-Remaining': rateLimiterRes.remainingPoints,
                'X-RateLimit-Reset': new Date(Date.now() + rateLimiterRes.msBeforeNext)
            }).json({
                error: 'too_many_requests',
                message: 'Too many login attempts. Please try again later.'
            });
        });
};

module.exports = loginRateLimiter;
