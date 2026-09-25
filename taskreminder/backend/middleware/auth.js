const jwt = require('jsonwebtoken');

/**
 * Minimal bearer-token auth. In production, replace the token issuance
 * (currently a placeholder in server.js's /api/auth/device route) with your
 * real login flow (email/OTP, Google/Apple sign-in, etc.). The rest of the
 * API only cares that req.userId is populated by the time it runs.
 */
function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    return res.status(401).json({ error: 'Missing bearer token' });
  }
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    req.userId = payload.userId;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

module.exports = { requireAuth };
