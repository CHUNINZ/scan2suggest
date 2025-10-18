const express = require('express');
const { body, validationResult } = require('express-validator');
const ScanResult = require('../models/ScanResult');
const Recipe = require('../models/Recipe');
const { auth } = require('../middleware/auth');
const upload = require('../middleware/upload');
const roboflowService = require('../services/roboflowService');
const recipeService = require('../services/enhancedRecipeService');
const ingredientDetectionService = require('../services/ingredientDetectionService');
const recipeSuggestionService = require('../services/recipeSuggestionService');
const mealDbRecipeService = require('../services/mealDbRecipeService');

const router = express.Router();

// @route   POST /api/scan/analyze
// @desc    Analyze uploaded image for food/ingredients
// @access  Private
router.post('/analyze', auth, upload.memoryUpload.single('scanImage'), [
  body('scanType')
    .isIn(['food', 'ingredient'])
    .withMessage('Scan type must be either food or ingredient')
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

    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'No image file provided'
      });
    }

    const { scanType } = req.body;
    const imageUrl = `${req.protocol}://${req.get('host')}/uploads/scans/${req.file.filename}`;

    // Create scan result record
    const scanResult = new ScanResult({
      userId: req.user._id,
      scanType,
      imageUrl: imageUrl,
      status: 'processing'
    });

    await scanResult.save();

    // Process image synchronously for immediate response
    try {
      const startTime = Date.now();
      const detectedItems = await roboflowService.analyzeFood(req.file.buffer, scanType);
      const processingTime = Date.now() - startTime;

      // If a food is detected, get recipe from TheMealDB
      let aiRecipe = null;
      if (detectedItems.length > 0 && detectedItems[0].name) {
        try {
          console.log(`🍽️ Getting recipe from TheMealDB: ${detectedItems[0].name}`);
          aiRecipe = await mealDbRecipeService.getRecipeForFood(detectedItems[0].name);
          console.log('✅ Recipe retrieved successfully');
        } catch(e) {
          console.error('❌ Recipe API error:', e.message);
          aiRecipe = { error: e.message };
        }
      }

      // Handle empty detection results
      if (detectedItems.length === 0) {
        // Update scan result with no items found
        scanResult.detectedItems = [];
        scanResult.suggestedRecipes = [];
        scanResult.processingTime = processingTime;
        scanResult.status = 'completed';
        await scanResult.save();

        // Return response indicating no items detected
        return res.json({
          success: true,
          message: 'No food items detected in the image',
          scanId: scanResult._id,
          status: 'completed',
          detectedItems: [{ name: 'No food detected. Try adjusting lighting or angle.', confidence: 0, category: 'info' }],
          suggestedRecipes: [],
          processingTime
        });
      }

      // Find suggested recipes based on detected items
      let suggestedRecipes = [];
      const itemNames = detectedItems.map(item => item.name);
      suggestedRecipes = await Recipe.find({
        $or: [
          { title: { $in: itemNames.map(name => new RegExp(name, 'i')) } },
          { 'ingredients.name': { $in: itemNames.map(name => new RegExp(name, 'i')) } },
          { tags: { $in: itemNames.map(name => new RegExp(name, 'i')) } }
        ],
        isPublished: true
      })
        .populate('creator', 'name profileImage')
        .limit(10)
        .sort({ averageRating: -1 });

      // Update scan result
      scanResult.detectedItems = detectedItems;
      scanResult.suggestedRecipes = suggestedRecipes.map(recipe => recipe._id);
      scanResult.processingTime = processingTime;
      scanResult.status = 'completed';
      await scanResult.save();

      // Return complete results immediately
      res.json({
        success: true,
        message: 'Image analyzed successfully',
        scanId: scanResult._id,
        status: 'completed',
        detectedItems,
        suggestedRecipes,
        processingTime,
        aiRecipe
      });

    } catch (processingError) {
      console.error('AI processing error:', processingError);
      
      // Update scan result with error
      scanResult.status = 'failed';
      scanResult.errorMessage = 'Failed to process image';
      await scanResult.save();

      // Return error response
      res.status(500).json({
        success: false,
        message: 'Failed to process image',
        scanId: scanResult._id,
        status: 'failed',
        detectedItems: [],
        error: processingError.message
      });
    }


  } catch (error) {
    console.error('Scan analyze error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error during image analysis'
    });
  }
});

// @route   GET /api/scan/result/:id
// @desc    Get scan result by ID
// @access  Private
router.get('/result/:id', auth, async (req, res) => {
  try {
    const scanResult = await ScanResult.findById(req.params.id)
      .populate('user', 'name profileImage')
      .populate('suggestedRecipes', 'title images category difficulty prepTime averageRating creator')
      .populate({
        path: 'suggestedRecipes',
        populate: {
          path: 'creator',
          select: 'name profileImage'
        }
      });

    if (!scanResult) {
      return res.status(404).json({
        success: false,
        message: 'Scan result not found'
      });
    }

    // Check if user owns this scan result
    if (scanResult.user._id.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to view this scan result'
      });
    }

    res.json({
      success: true,
      scanResult
    });
  } catch (error) {
    console.error('Get scan result error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   GET /api/scan/history
// @desc    Get user's scan history
// @access  Private
router.get('/history', auth, async (req, res) => {
  try {
    const { page = 1, limit = 10, scanType } = req.query;
    const skip = (page - 1) * limit;
    
    const query = { user: req.user._id };
    if (scanType) query.scanType = scanType;

    const scanResults = await ScanResult.find(query)
      .populate('suggestedRecipes', 'title images category')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await ScanResult.countDocuments(query);

    res.json({
      success: true,
      scanResults,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / limit)
      }
    });
  } catch (error) {
    console.error('Get scan history error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   DELETE /api/scan/result/:id
// @desc    Delete scan result
// @access  Private
router.delete('/result/:id', auth, async (req, res) => {
  try {
    const scanResult = await ScanResult.findById(req.params.id);

    if (!scanResult) {
      return res.status(404).json({
        success: false,
        message: 'Scan result not found'
      });
    }

    // Check if user owns this scan result
    if (scanResult.user.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to delete this scan result'
      });
    }

    await ScanResult.findByIdAndDelete(req.params.id);

    res.json({
      success: true,
      message: 'Scan result deleted successfully'
    });
  } catch (error) {
    console.error('Delete scan result error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   POST /api/scan/feedback
// @desc    Submit feedback on scan accuracy
// @access  Private
router.post('/feedback', auth, [
  body('scanId')
    .isMongoId()
    .withMessage('Valid scan ID is required'),
  body('accuracy')
    .isInt({ min: 1, max: 5 })
    .withMessage('Accuracy rating must be between 1 and 5'),
  body('feedback')
    .optional()
    .trim()
    .isLength({ max: 500 })
    .withMessage('Feedback must be less than 500 characters')
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

    const { scanId, accuracy, feedback } = req.body;

    const scanResult = await ScanResult.findById(scanId);
    if (!scanResult) {
      return res.status(404).json({
        success: false,
        message: 'Scan result not found'
      });
    }

    // Check if user owns this scan result
    if (scanResult.user.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to provide feedback for this scan'
      });
    }

    // Store feedback (you might want to create a separate Feedback model)
    scanResult.feedback = {
      accuracy,
      comment: feedback,
      submittedAt: new Date()
    };

    await scanResult.save();

    res.json({
      success: true,
      message: 'Feedback submitted successfully'
    });
  } catch (error) {
    console.error('Submit feedback error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   GET /api/scan/stats
// @desc    Get user's scanning statistics
// @access  Private
router.get('/stats', auth, async (req, res) => {
  try {
    const stats = await ScanResult.aggregate([
      { $match: { user: req.user._id } },
      {
        $group: {
          _id: null,
          totalScans: { $sum: 1 },
          foodScans: {
            $sum: { $cond: [{ $eq: ['$scanType', 'food'] }, 1, 0] }
          },
          ingredientScans: {
            $sum: { $cond: [{ $eq: ['$scanType', 'ingredient'] }, 1, 0] }
          },
          successfulScans: {
            $sum: { $cond: [{ $eq: ['$status', 'completed'] }, 1, 0] }
          },
          averageProcessingTime: { $avg: '$processingTime' }
        }
      }
    ]);

    const userStats = stats[0] || {
      totalScans: 0,
      foodScans: 0,
      ingredientScans: 0,
      successfulScans: 0,
      averageProcessingTime: 0
    };

    res.json({
      success: true,
      stats: userStats
    });
  } catch (error) {
    console.error('Get scan stats error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   GET /api/scan/test-roboflow
// @desc    Test Roboflow API connectivity
// @access  Private
router.get('/test-roboflow', auth, async (req, res) => {
  try {
    const testResult = await roboflowService.testConnection();
    
    res.json({
      success: testResult.success,
      message: testResult.message,
      apiConfigured: roboflowService.isConfigured,
      response: testResult.response || null
    });
  } catch (error) {
    console.error('Test Roboflow error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to test Roboflow connection',
      error: error.message
    });
  }
});

// @route   POST /api/scan/confirm
// @desc    Confirm detection result and get recipe
// @access  Private
router.post('/confirm', auth, [
  body('foodName')
    .notEmpty()
    .withMessage('Food name is required'),
  body('scanId')
    .notEmpty()
    .withMessage('Scan ID is required'),
  body('isCorrect')
    .isBoolean()
    .withMessage('isCorrect must be a boolean')
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

    const { foodName, scanId, isCorrect } = req.body;
    console.log(`🔍 Confirming detection: ${foodName}, correct: ${isCorrect}`);

    // Update scan result with confirmation
    const scanResult = await ScanResult.findById(scanId);
    if (!scanResult) {
      return res.status(404).json({
        success: false,
        message: 'Scan result not found'
      });
    }

    scanResult.confirmedFood = foodName;
    scanResult.isConfirmed = true;
    scanResult.detectionCorrect = isCorrect;
    await scanResult.save();

    // Get recipe for the confirmed food
    console.log(`🍳 Getting recipe for: ${foodName}`);
    const recipe = await recipeService.getRecipeByName(foodName);

    res.json({
      success: true,
      message: 'Detection confirmed and recipe generated',
      scanId: scanResult._id,
      confirmedFood: foodName,
      isCorrect: isCorrect,
      recipe: recipe
    });

  } catch (error) {
    console.error('Confirm detection error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   POST /api/scan/manual-input
// @desc    Manual food input when detection is wrong
// @access  Private
router.post('/manual-input', auth, [
  body('foodName')
    .notEmpty()
    .withMessage('Food name is required'),
  body('scanId')
    .optional()
    .isMongoId()
    .withMessage('Invalid scan ID')
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

    const { foodName, scanId } = req.body;
    console.log(`✏️ Manual food input: ${foodName}`);

    // Update scan result if scanId provided
    if (scanId) {
      const scanResult = await ScanResult.findById(scanId);
      if (scanResult) {
        scanResult.confirmedFood = foodName;
        scanResult.isConfirmed = true;
        scanResult.detectionCorrect = false;
        scanResult.manualInput = true;
        await scanResult.save();
      }
    }

    // Get recipe for the manually entered food
    console.log(`🍳 Getting recipe for manual input: ${foodName}`);
    const recipe = await recipeService.getRecipeByName(foodName);

    res.json({
      success: true,
      message: 'Manual food input processed and recipe generated',
      scanId: scanId || null,
      foodName: foodName,
      recipe: recipe
    });

  } catch (error) {
    console.error('Manual input error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   GET /api/scan/recipe/:foodName
// @desc    Get recipe for a specific food
// @access  Private
router.get('/recipe/:foodName', auth, async (req, res) => {
  try {
    const { foodName } = req.params;
    console.log(`🍳 Getting recipe for: ${foodName}`);

    const recipe = await recipeService.getRecipeByName(foodName);

    res.json({
      success: true,
      message: 'Recipe retrieved successfully',
      foodName: foodName,
      recipe: recipe
    });

  } catch (error) {
    console.error('Get recipe error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   GET /api/scan/random-recipe
// @desc    Get a random recipe
// @access  Private
router.get('/random-recipe', auth, async (req, res) => {
  try {
    console.log('🎲 Getting random recipe...');
    const recipe = await recipeService.getRandomRecipe();

    res.json({
      success: true,
      message: 'Random recipe retrieved successfully',
      recipe: recipe
    });

  } catch (error) {
    console.error('Get random recipe error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   POST /api/scan/ingredients
// @desc    Analyze uploaded image for ingredients and suggest recipes
// @access  Private
router.post('/ingredients', auth, upload.memoryUpload.single('scanImage'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'No image file provided'
      });
    }

    console.log('🥬 Starting ingredient detection...');
    
    // Create scan result record
    const scanResult = new ScanResult({
      userId: req.user._id,
      scanType: 'ingredient',
      imageUrl: `/uploads/scans/${req.file.filename}`,
      status: 'processing'
    });

    await scanResult.save();

    // Detect ingredients in the image
    const ingredientResult = await ingredientDetectionService.detectIngredients(
      req.file.buffer, 
      req.file.originalname
    );

    if (!ingredientResult.success || ingredientResult.ingredients.length === 0) {
      scanResult.status = 'completed';
      scanResult.detectedItems = [];
      await scanResult.save();

      return res.json({
        success: true,
        message: 'No ingredients detected in the image',
        scanId: scanResult._id,
        ingredients: [],
        recipeSuggestions: []
      });
    }

    console.log(`✅ Detected ${ingredientResult.ingredients.length} ingredients`);

    // Get recipe suggestions based on detected ingredients
    const suggestionResult = await recipeSuggestionService.suggestRecipesByIngredients(
      ingredientResult.ingredients
    );

    // Update scan result
    scanResult.detectedItems = ingredientResult.ingredients;
    scanResult.status = 'completed';
    await scanResult.save();

    res.json({
      success: true,
      message: 'Ingredients detected and recipes suggested successfully',
      scanId: scanResult._id,
      ingredients: ingredientResult.ingredients,
      recipeSuggestions: suggestionResult.suggestions || [],
      confidence: ingredientResult.confidence
    });

  } catch (error) {
    console.error('Ingredient scan error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error during ingredient analysis'
    });
  }
});

// @route   POST /api/scan/recipe-suggestions
// @desc    Get recipe suggestions based on provided ingredients
// @access  Private
router.post('/recipe-suggestions', auth, [
  body('ingredients')
    .isArray({ min: 1 })
    .withMessage('At least one ingredient is required'),
  body('ingredients.*.name')
    .notEmpty()
    .withMessage('Ingredient name is required')
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

    const { ingredients } = req.body;
    console.log(`🍳 Getting recipe suggestions for: ${ingredients.map(i => i.name).join(', ')}`);

    const suggestionResult = await recipeSuggestionService.suggestRecipesByIngredients(ingredients);

    res.json({
      success: true,
      message: 'Recipe suggestions retrieved successfully',
      ingredients: ingredients,
      recipeSuggestions: suggestionResult.suggestions || [],
      totalFound: suggestionResult.totalFound || 0
    });

  } catch (error) {
    console.error('Recipe suggestions error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   GET /api/scan/recipe-details/:recipeName
// @desc    Get full recipe details for a suggested recipe
// @access  Private
router.get('/recipe-details/:recipeName', auth, async (req, res) => {
  try {
    const { recipeName } = req.params;
    console.log(`📖 Getting full recipe details for: ${recipeName}`);

    const recipeResult = await recipeSuggestionService.getFullRecipeDetails(recipeName);

    if (!recipeResult.success) {
      return res.status(404).json({
        success: false,
        message: 'Recipe not found'
      });
    }

    res.json({
      success: true,
      message: 'Recipe details retrieved successfully',
      recipe: recipeResult.recipe
    });

  } catch (error) {
    console.error('Recipe details error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   POST /api/scan/shopping-list
// @desc    Generate shopping list for missing ingredients
// @access  Private
router.post('/shopping-list', auth, [
  body('selectedRecipes')
    .isArray({ min: 1 })
    .withMessage('At least one recipe must be selected'),
  body('userIngredients')
    .isArray()
    .withMessage('User ingredients must be an array')
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

    const { selectedRecipes, userIngredients } = req.body;
    
    const shoppingList = recipeSuggestionService.generateShoppingList(
      selectedRecipes, 
      userIngredients || []
    );

    res.json({
      success: true,
      message: 'Shopping list generated successfully',
      shoppingList: shoppingList,
      totalItems: shoppingList.length
    });

  } catch (error) {
    console.error('Shopping list error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

module.exports = router;
