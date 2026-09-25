const express = require('express');
const Task = require('../models/Task');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();
router.use(requireAuth);

// GET /api/tasks — all of this user's non-deleted tasks, newest schedule first
router.get('/', async (req, res) => {
  const tasks = await Task.find({ userId: req.userId }).sort({ scheduledAt: 1 });
  res.json(
    tasks.map((t) => ({
      id: t.clientId,
      description: t.description,
      language: t.language,
      scheduledAt: t.scheduledAt.toISOString(),
      isCancelled: t.isCancelled,
    }))
  );
});

// POST /api/tasks — upsert (create or update) by clientId, so the mobile
// app can safely retry/re-sync without creating duplicates.
router.post('/', async (req, res) => {
  const { id, description, language, scheduledAt, isCancelled } = req.body;
  if (!id || !description || !scheduledAt) {
    return res.status(400).json({ error: 'id, description and scheduledAt are required' });
  }
  if (!['english', 'hindi'].includes(language)) {
    return res.status(400).json({ error: 'language must be "english" or "hindi"' });
  }

  const task = await Task.findOneAndUpdate(
    { userId: req.userId, clientId: id },
    {
      userId: req.userId,
      clientId: id,
      description,
      language,
      scheduledAt: new Date(scheduledAt),
      isCancelled: Boolean(isCancelled),
    },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );

  res.status(201).json({ id: task.clientId });
});

// DELETE /api/tasks/:id — cancels (soft-deletes) a task
router.delete('/:id', async (req, res) => {
  const result = await Task.findOneAndUpdate(
    { userId: req.userId, clientId: req.params.id },
    { isCancelled: true },
    { new: true }
  );
  if (!result) return res.status(404).json({ error: 'Task not found' });
  res.json({ ok: true });
});

module.exports = router;
