const mongoose = require('mongoose');

/**
 * Server-side mirror of the client's TaskModel. The server does NOT own
 * scheduling — reminders are scheduled and spoken entirely on-device — this
 * collection exists purely so a user's tasks are backed up and can sync
 * across multiple devices logged into the same account.
 */
const taskSchema = new mongoose.Schema(
  {
    // Client-generated uuid, kept as the primary lookup key so the mobile
    // app never has to reconcile server-assigned vs local IDs.
    clientId: { type: String, required: true, index: true },
    userId: { type: String, required: true, index: true },
    description: { type: String, required: true, trim: true, maxlength: 1000 },
    language: { type: String, enum: ['english', 'hindi'], required: true },
    scheduledAt: { type: Date, required: true },
    isCancelled: { type: Boolean, default: false },
  },
  { timestamps: true }
);

taskSchema.index({ userId: 1, clientId: 1 }, { unique: true });

module.exports = mongoose.model('Task', taskSchema);
