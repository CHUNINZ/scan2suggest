const express = require('express');
const { body, validationResult } = require('express-validator');
const Notification = require('../models/Notification');
const { auth } = require('../middleware/auth');

const router = express.Router();

// @route   GET /api/notifications
// @desc    Get user's notifications
// @access  Private
router.get('/', auth, async (req, res) => {
  try {
    const { page = 1, limit = 20, unreadOnly = false } = req.query;
    const skip = (page - 1) * limit;

    const query = { 
      recipient: req.user._id,
      isDeleted: false
    };

    if (unreadOnly === 'true') {
      query.isRead = false;
    }

    const notifications = await Notification.find(query)
      .populate('sender', 'name profileImage')
      .populate('data.recipeId', 'title images')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await Notification.countDocuments(query);
    const unreadCount = await Notification.countDocuments({
      recipient: req.user._id,
      isRead: false,
      isDeleted: false
    });

    res.json({
      success: true,
      notifications,
      unreadCount,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / limit)
      }
    });
  } catch (error) {
    console.error('Get notifications error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   PUT /api/notifications/:id/read
// @desc    Mark notification as read
// @access  Private
router.put('/:id/read', auth, async (req, res) => {
  try {
    const notification = await Notification.findById(req.params.id);

    if (!notification) {
      return res.status(404).json({
        success: false,
        message: 'Notification not found'
      });
    }

    // Check if user owns this notification
    if (notification.recipient.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to modify this notification'
      });
    }

    notification.isRead = true;
    notification.readAt = new Date();
    await notification.save();

    res.json({
      success: true,
      message: 'Notification marked as read'
    });
  } catch (error) {
    console.error('Mark notification read error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   PUT /api/notifications/read-all
// @desc    Mark all notifications as read
// @access  Private
router.put('/read-all', auth, async (req, res) => {
  try {
    await Notification.updateMany(
      { 
        recipient: req.user._id,
        isRead: false,
        isDeleted: false
      },
      { 
        isRead: true,
        readAt: new Date()
      }
    );

    res.json({
      success: true,
      message: 'All notifications marked as read'
    });
  } catch (error) {
    console.error('Mark all notifications read error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   DELETE /api/notifications/:id
// @desc    Delete notification
// @access  Private
router.delete('/:id', auth, async (req, res) => {
  try {
    const notification = await Notification.findById(req.params.id);

    if (!notification) {
      return res.status(404).json({
        success: false,
        message: 'Notification not found'
      });
    }

    // Check if user owns this notification
    if (notification.recipient.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to delete this notification'
      });
    }

    // Soft delete
    notification.isDeleted = true;
    notification.deletedAt = new Date();
    await notification.save();

    res.json({
      success: true,
      message: 'Notification deleted successfully'
    });
  } catch (error) {
    console.error('Delete notification error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   DELETE /api/notifications
// @desc    Delete all notifications
// @access  Private
router.delete('/', auth, async (req, res) => {
  try {
    await Notification.updateMany(
      { 
        recipient: req.user._id,
        isDeleted: false
      },
      { 
        isDeleted: true,
        deletedAt: new Date()
      }
    );

    res.json({
      success: true,
      message: 'All notifications deleted successfully'
    });
  } catch (error) {
    console.error('Delete all notifications error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   POST /api/notifications/send
// @desc    Send notification to user (admin only or system)
// @access  Private
router.post('/send', auth, [
  body('recipient')
    .isMongoId()
    .withMessage('Valid recipient ID is required'),
  body('type')
    .isIn(['like', 'comment', 'follow', 'recipe', 'system', 'share'])
    .withMessage('Invalid notification type'),
  body('title')
    .trim()
    .isLength({ min: 1, max: 100 })
    .withMessage('Title must be between 1 and 100 characters'),
  body('message')
    .trim()
    .isLength({ min: 1, max: 500 })
    .withMessage('Message must be between 1 and 500 characters')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        message: 'Validation failed',
        errors: errors.array()
      });
    }

    const { recipient, type, title, message, data } = req.body;

    const notification = new Notification({
      recipient,
      sender: req.user._id,
      type,
      title,
      message,
      data
    });

    await notification.save();

    // Populate sender info for real-time notification
    await notification.populate('sender', 'name profileImage');

    // Send real-time notification
    const io = req.app.get('io');
    io.to(`user_${recipient}`).emit('notification', {
      _id: notification._id,
      type,
      title,
      message,
      data,
      sender: notification.sender,
      createdAt: notification.createdAt
    });

    res.status(201).json({
      success: true,
      message: 'Notification sent successfully',
      notification
    });
  } catch (error) {
    console.error('Send notification error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   GET /api/notifications/stats
// @desc    Get notification statistics
// @access  Private
router.get('/stats', auth, async (req, res) => {
  try {
    const stats = await Notification.aggregate([
      { $match: { recipient: req.user._id, isDeleted: false } },
      {
        $group: {
          _id: null,
          total: { $sum: 1 },
          unread: {
            $sum: { $cond: [{ $eq: ['$isRead', false] }, 1, 0] }
          },
          byType: {
            $push: {
              type: '$type',
              isRead: '$isRead'
            }
          }
        }
      }
    ]);

    const userStats = stats[0] || { total: 0, unread: 0, byType: [] };

    // Group by type
    const typeStats = {};
    userStats.byType.forEach(item => {
      if (!typeStats[item.type]) {
        typeStats[item.type] = { total: 0, unread: 0 };
      }
      typeStats[item.type].total += 1;
      if (!item.isRead) {
        typeStats[item.type].unread += 1;
      }
    });

    res.json({
      success: true,
      stats: {
        total: userStats.total,
        unread: userStats.unread,
        read: userStats.total - userStats.unread,
        byType: typeStats
      }
    });
  } catch (error) {
    console.error('Get notification stats error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   PUT /api/notifications/settings
// @desc    Update notification preferences
// @access  Private
router.put('/settings', auth, [
  body('emailNotifications')
    .optional()
    .isBoolean()
    .withMessage('Email notifications must be boolean'),
  body('pushNotifications')
    .optional()
    .isBoolean()
    .withMessage('Push notifications must be boolean'),
  body('notificationTypes')
    .optional()
    .isArray()
    .withMessage('Notification types must be an array')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        message: 'Validation failed',
        errors: errors.array()
      });
    }

    const { emailNotifications, pushNotifications, notificationTypes } = req.body;

    // Update user's notification preferences
    const updateData = {};
    if (emailNotifications !== undefined) {
      updateData['preferences.notifications.email'] = emailNotifications;
    }
    if (pushNotifications !== undefined) {
      updateData['preferences.notifications.push'] = pushNotifications;
    }
    if (notificationTypes !== undefined) {
      updateData['preferences.notifications.types'] = notificationTypes;
    }

    const User = require('../models/User');
    await User.findByIdAndUpdate(req.user._id, updateData);

    res.json({
      success: true,
      message: 'Notification settings updated successfully'
    });
  } catch (error) {
    console.error('Update notification settings error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

module.exports = router;
