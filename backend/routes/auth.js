const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');
const User = require('../models/User');
const { auth } = require('../middleware/auth');
const crypto = require('crypto');
const emailService = require('../services/emailService');

const router = express.Router();

// Generate JWT token
const generateToken = (userId) => {
  return jwt.sign({ userId }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '7d'
  });
};

// @route   POST /api/auth/register
// @desc    Send email verification for new user registration
// @access  Public
router.post('/register', [
  body('name')
    .trim()
    .isLength({ min: 2, max: 50 })
    .withMessage('Name must be between 2 and 50 characters'),
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Please provide a valid email'),
  body('password')
    .isLength({ min: 6 })
    .withMessage('Password must be at least 6 characters long')
], async (req, res) => {
  try {
    // Check validation errors
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        message: 'Validation failed',
        errors: errors.array()
      });
    }

    const { name, email, password } = req.body;

    // Check if user already exists
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      // If user exists but email is not verified, allow re-registration
      if (!existingUser.isEmailVerified) {
        // Generate new verification code
        const verificationCode = Math.floor(100000 + Math.random() * 900000).toString();
        
        // Update existing unverified user with new details and code
        existingUser.name = name;
        existingUser.password = password;
        existingUser.emailVerificationCode = verificationCode;
        existingUser.emailVerificationExpires = Date.now() + 10 * 60 * 1000; // 10 minutes
        await existingUser.save();

        console.log(`📧 Re-registration for unverified account: ${email}`);
        console.log(`📧 New verification code: ${verificationCode}`);
        
        // Send verification code via email
        const emailResult = await emailService.sendEmailVerificationCode(email, verificationCode);
        
        console.log(`📧 Email service result:`, emailResult);

        return res.status(201).json({
          success: true,
          message: 'Verification code sent to your email. Please verify to complete registration.',
          verificationCode: process.env.NODE_ENV === 'development' ? verificationCode : undefined,
          emailSent: emailResult.success && !emailResult.fallback,
          email: email
        });
      } else {
        // User exists and is verified
        return res.status(409).json({
          success: false,
          message: 'An account with this email already exists. Please sign in instead.'
        });
      }
    }

    // Generate 6-digit verification code
    const verificationCode = Math.floor(100000 + Math.random() * 900000).toString();
    
    // Create unverified user with verification code
    const user = new User({
      name,
      email,
      password,
      isEmailVerified: false,
      emailVerificationCode: verificationCode,
      emailVerificationExpires: Date.now() + 10 * 60 * 1000 // 10 minutes
    });

    await user.save();

    console.log(`📧 Registration verification requested for: ${email}`);
    console.log(`📧 Verification code: ${verificationCode}`);
    
    // Send verification code via email
    const emailResult = await emailService.sendEmailVerificationCode(email, verificationCode);
    
    console.log(`📧 Email service result:`, emailResult);

    res.status(201).json({
      success: true,
      message: 'Verification code sent to your email. Please verify to complete registration.',
      // Include verification code in development mode for testing
      verificationCode: process.env.NODE_ENV === 'development' ? verificationCode : undefined,
      emailSent: emailResult.success && !emailResult.fallback,
      email: email
    });

  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error during registration'
    });
  }
});

// @route   POST /api/auth/resend-verification
// @desc    Resend email verification code
// @access  Public
router.post('/resend-verification', [
  body('email').isEmail().withMessage('Please provide a valid email')
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

    const { email } = req.body;

    // Find user by email
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found with this email'
      });
    }

    // Check if already verified
    if (user.isEmailVerified) {
      return res.status(400).json({
        success: false,
        message: 'Email is already verified'
      });
    }

    // Generate new verification code
    const verificationCode = Math.floor(100000 + Math.random() * 900000).toString();
    
    // Update user with new code and expiry
    user.emailVerificationCode = verificationCode;
    user.emailVerificationExpires = Date.now() + 10 * 60 * 1000; // 10 minutes
    await user.save();

    console.log(`📧 Resend verification requested for: ${email}`);
    console.log(`📧 New verification code: ${verificationCode}`);
    
    // Send verification code via email
    const emailResult = await emailService.sendEmailVerificationCode(email, verificationCode);
    
    console.log(`📧 Email service result:`, emailResult);

    res.json({
      success: true,
      message: 'Verification code sent again. Please check your email.',
      emailSent: emailResult.success && !emailResult.fallback
    });

  } catch (error) {
    console.error('Resend verification error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error occurred while resending verification code'
    });
  }
});

// @route   POST /api/auth/verify-email
// @desc    Verify email and complete registration
// @access  Public
router.post('/verify-email', [
  body('email').isEmail().withMessage('Please provide a valid email'),
  body('code').isLength({ min: 6, max: 6 }).withMessage('Verification code must be 6 digits')
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

    const { email, code } = req.body;

    // Find user with valid verification code
    const user = await User.findOne({
      email: email,
      emailVerificationCode: code,
      emailVerificationExpires: { $gt: Date.now() },
      isEmailVerified: false
    });

    if (!user) {
      return res.status(400).json({
        success: false,
        message: 'Invalid or expired verification code'
      });
    }

    // Verify the user
    user.isEmailVerified = true;
    user.emailVerificationCode = undefined;
    user.emailVerificationExpires = undefined;
    await user.save();

    // Generate JWT token
    const token = generateToken(user._id);

    // Return user data without password
    const userData = user.toObject();
    delete userData.password;

    res.json({
      success: true,
      message: 'Email verified successfully! Welcome to Scan2Suggest.',
      token,
      user: userData
    });

  } catch (error) {
    console.error('Email verification error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error during email verification'
    });
  }
});

// @route   POST /api/auth/login
// @desc    Login user
// @access  Public
router.post('/login', [
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Please provide a valid email'),
  body('password')
    .notEmpty()
    .withMessage('Password is required')
], async (req, res) => {
  try {
    // Check validation errors
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        message: 'Validation failed',
        errors: errors.array()
      });
    }

    const { email, password } = req.body;

    // Find user by email
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Account not found. Please check your email or create a new account.'
      });
    }

    // Check if email is verified
    if (!user.isEmailVerified) {
      return res.status(403).json({
        success: false,
        message: 'Please verify your email address before signing in. Check your inbox for the verification code.',
        requiresEmailVerification: true,
        email: user.email
      });
    }

    // Check password
    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: 'Incorrect password. Please try again.'
      });
    }

    // Update last active
    user.lastActive = new Date();
    await user.save();

    // Generate token
    const token = generateToken(user._id);

    // Return user data without password
    const userData = user.toObject();
    delete userData.password;

    res.json({
      success: true,
      message: 'Login successful',
      token,
      user: userData
    });

  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error during login'
    });
  }
});

// @route   GET /api/auth/me
// @desc    Get current user
// @access  Private
router.get('/me', auth, async (req, res) => {
  try {
    const user = await User.findById(req.user._id)
      .select('-password')
      .populate('bookmarkedRecipes', 'title images category')
      .populate('likedRecipes', 'title images category');

    res.json({
      success: true,
      user
    });
  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   GET /api/auth/liked-recipes
// @desc    Get user's liked recipes with full details
// @access  Private
router.get('/liked-recipes', auth, async (req, res) => {
  try {
    const Recipe = require('../models/Recipe');
    
    const user = await User.findById(req.user._id).select('likedRecipes');
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    // Get full recipe details for liked recipes
    const likedRecipes = await Recipe.find({
      _id: { $in: user.likedRecipes },
      isPublished: true
    })
      .populate('creator', 'name profileImage')
      .sort({ createdAt: -1 });

    // Add user interaction flags
    likedRecipes.forEach(recipe => {
      recipe._doc.isLiked = true; // All these recipes are liked
      recipe._doc.isBookmarked = user.bookmarkedRecipes?.includes(recipe._id) || false;
    });

    res.json({
      success: true,
      recipes: likedRecipes,
      total: likedRecipes.length
    });
  } catch (error) {
    console.error('Get liked recipes error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   POST /api/auth/refresh
// @desc    Refresh JWT token
// @access  Private
router.post('/refresh', auth, async (req, res) => {
  try {
    const token = generateToken(req.user._id);
    
    res.json({
      success: true,
      token
    });
  } catch (error) {
    console.error('Token refresh error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   POST /api/auth/logout
// @desc    Logout user (client-side token removal)
// @access  Private
router.post('/logout', auth, async (req, res) => {
  try {
    // Update user's last active time
    await User.findByIdAndUpdate(req.user._id, {
      lastActive: new Date()
    });

    res.json({
      success: true,
      message: 'Logged out successfully'
    });
  } catch (error) {
    console.error('Logout error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   POST /api/auth/forgot-password
// @desc    Send password reset email
// @access  Public
router.post('/forgot-password', [
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Please provide a valid email')
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

    const { email } = req.body;
    const user = await User.findOne({ email });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found with this email'
      });
    }

    // Generate 6-digit verification code
    const resetCode = Math.floor(100000 + Math.random() * 900000).toString();
    
    // Set reset code and expiry (10 minutes)
    user.passwordResetCode = resetCode;
    user.passwordResetExpires = Date.now() + 10 * 60 * 1000;
    await user.save();

    console.log(`Password reset requested for: ${email}`);
    console.log(`Verification code: ${resetCode}`);
    
    // Send verification code via email
    const emailResult = await emailService.sendVerificationCode(email, resetCode);
    
    res.json({
      success: true,
      message: 'Verification code sent to your email',
      // Remove this in production - only for development
      verificationCode: process.env.NODE_ENV === 'development' ? resetCode : undefined,
      emailSent: emailResult.success
    });

  } catch (error) {
    console.error('Forgot password error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   POST /api/auth/verify-reset-code
// @desc    Verify reset code and reset password
// @access  Public
router.post('/verify-reset-code', [
  body('email')
    .isEmail()
    .withMessage('Please provide a valid email'),
  body('code')
    .isLength({ min: 6, max: 6 })
    .withMessage('Verification code must be 6 digits'),
  body('newPassword')
    .isLength({ min: 6 })
    .withMessage('Password must be at least 6 characters long')
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

    const { email, code, newPassword } = req.body;

    // Find user with valid reset code
    const user = await User.findOne({
      email: email,
      passwordResetCode: code,
      passwordResetExpires: { $gt: Date.now() }
    });

    if (!user) {
      return res.status(400).json({
        success: false,
        message: 'Invalid or expired verification code'
      });
    }

    // Update password and clear reset code
    user.password = newPassword;
    user.passwordResetCode = undefined;
    user.passwordResetExpires = undefined;
    await user.save();

    // Generate new JWT token
    const jwtToken = generateToken(user._id);

    res.json({
      success: true,
      message: 'Password reset successful',
      token: jwtToken
    });

  } catch (error) {
    console.error('Verify reset code error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   POST /api/auth/reset-password/:token
// @desc    Reset password
// @access  Public
router.post('/reset-password/:token', [
  body('password')
    .isLength({ min: 6 })
    .withMessage('Password must be at least 6 characters long')
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

    const { token } = req.params;
    const { password } = req.body;

    // Hash the token to compare with stored hash
    const resetTokenHash = crypto.createHash('sha256').update(token).digest('hex');

    // Find user with valid reset token
    const user = await User.findOne({
      passwordResetToken: resetTokenHash,
      passwordResetExpires: { $gt: Date.now() }
    });

    if (!user) {
      return res.status(400).json({
        success: false,
        message: 'Invalid or expired reset token'
      });
    }

    // Update password
    user.password = password;
    user.passwordResetToken = undefined;
    user.passwordResetExpires = undefined;
    await user.save();

    // Generate new JWT token
    const jwtToken = generateToken(user._id);

    res.json({
      success: true,
      message: 'Password reset successful',
      token: jwtToken
    });

  } catch (error) {
    console.error('Reset password error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

module.exports = router;
