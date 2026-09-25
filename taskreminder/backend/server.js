require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');

const taskRoutes = require('./routes/tasks');

const app = express();
app.use(helmet());
app.use(cors({ origin: process.env.CORS_ORIGIN || '*' }));
app.use(express.json({ limit: '256kb' }));
app.use(
  rateLimit({
    windowMs: 60 * 1000,
    max: 120, // per IP per minute — generous for a small personal-use API
  })
);

// --- Minimal device-based "auth" -------------------------------------------
// This is a placeholder identity scheme suitable for a single-user or
// small personal deployment: the app generates a random device id on first
// launch and exchanges it here for a long-lived JWT. Swap this route for a
// real login flow (email/OTP, Google/Apple Sign-In) before shipping to
// multiple untrusted users, since a bare device id has no real proof of
// identity.
app.post('/api/auth/device', (req, res) => {
  const deviceId = req.body?.deviceId || crypto.randomUUID();
  const token = jwt.sign({ userId: deviceId }, process.env.JWT_SECRET, {
    expiresIn: '365d',
  });
  res.json({ userId: deviceId, token });
});

app.use('/api/tasks', taskRoutes);

app.get('/health', (_req, res) => res.json({ status: 'ok' }));

const PORT = process.env.PORT || 4000;

mongoose
  .connect(process.env.MONGODB_URI)
  .then(() => {
    console.log('Connected to MongoDB');
    app.listen(PORT, () => console.log(`Task Reminder API listening on :${PORT}`));
  })
  .catch((err) => {
    console.error('MongoDB connection failed:', err.message);
    process.exit(1);
  });
