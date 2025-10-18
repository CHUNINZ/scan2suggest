const express = require('express');
const { body, validationResult } = require('express-validator');
const Recipe = require('../models/Recipe');
const User = require('../models/User');
const { auth, optionalAuth } = require('../middleware/auth');
const upload = require('../middleware/upload');

const router = express.Router();

// @route   GET /api/recipes
// @desc    Get all recipes with filters
// @access  Public
router.get('/', optionalAuth, async (req, res) => {
  try {
    const {
      page = 1,
      limit = 10,
      category,
      difficulty,
      cuisine,
      search,
      sort = 'createdAt',
      order = 'desc',
      featured
    } = req.query;

    const skip = (page - 1) * limit;
    const query = { isPublished: true };

    // Apply filters
    if (category) query.category = category;
    if (difficulty) query.difficulty = difficulty;
    if (cuisine) query.cuisine = cuisine;
    if (featured === 'true') query.isFeatured = true;

    // Search functionality
    if (search) {
      query.$or = [
        { title: { $regex: search, $options: 'i' } },
        { description: { $regex: search, $options: 'i' } },
        { tags: { $in: [new RegExp(search, 'i')] } }
      ];
    }

    // Sort options
    const sortObj = {};
    sortObj[sort] = order === 'desc' ? -1 : 1;

    const recipes = await Recipe.find(query)
      .populate('creator', 'name profileImage')
      .sort(sortObj)
      .skip(skip)
      .limit(parseInt(limit));

    const total = await Recipe.countDocuments(query);

    // Add user interaction data if authenticated
    if (req.user) {
      recipes.forEach(recipe => {
        recipe._doc.isLiked = recipe.likes.includes(req.user._id);
        recipe._doc.isBookmarked = recipe.bookmarks.includes(req.user._id);
      });
    }

    res.json({
      success: true,
      recipes,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / limit)
      }
    });
  } catch (error) {
    console.error('Get recipes error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   GET /api/recipes/:id
// @desc    Get recipe by ID
// @access  Public
router.get('/:id', optionalAuth, async (req, res) => {
  try {
    const recipe = await Recipe.findById(req.params.id)
      .populate('creator', 'name profileImage bio')
      .populate('ratings.user', 'name profileImage');

    if (!recipe) {
      return res.status(404).json({
        success: false,
        message: 'Recipe not found'
      });
    }

    // Increment view count
    recipe.views += 1;
    await recipe.save();

    // Add user interaction data if authenticated
    if (req.user) {
      recipe._doc.isLiked = recipe.likes.includes(req.user._id);
      recipe._doc.isBookmarked = recipe.bookmarks.includes(req.user._id);
      recipe._doc.userRating = recipe.ratings.find(r => r.user._id.toString() === req.user._id.toString())?.rating || null;
    }

    res.json({
      success: true,
      recipe
    });
  } catch (error) {
    console.error('Get recipe error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   POST /api/recipes
// @desc    Create new recipe
// @access  Private
router.post('/', auth, upload.diskUpload.array('recipeImages', 5), [
  body('title')
    .trim()
    .isLength({ min: 3, max: 100 })
    .withMessage('Title must be between 3 and 100 characters'),
  body('description')
    .trim()
    .isLength({ min: 10, max: 500 })
    .withMessage('Description must be between 10 and 500 characters'),
  body('category')
    .isIn(['appetizer', 'main_course', 'dessert', 'beverage', 'snack', 'soup', 'salad', 'breakfast', 'lunch', 'dinner'])
    .withMessage('Invalid category'),
  body('difficulty')
    .isIn(['easy', 'medium', 'hard'])
    .withMessage('Invalid difficulty level'),
  body('prepTime')
    .isInt({ min: 1 })
    .withMessage('Prep time must be a positive integer'),
  body('cookTime')
    .isInt({ min: 1 })
    .withMessage('Cook time must be a positive integer'),
  body('servings')
    .isInt({ min: 1 })
    .withMessage('Servings must be a positive integer')
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

    const {
      title,
      description,
      category,
      cuisine,
      difficulty,
      prepTime,
      cookTime,
      servings,
      ingredients,
      instructions,
      nutrition,
      tags,
      spiceLevel,
      dietaryInfo
    } = req.body;

    // Process uploaded images
    const images = req.files ? req.files.map(file => `/uploads/recipes/${file.filename}`) : [];

    const recipe = new Recipe({
      title,
      description,
      creator: req.user._id,
      images,
      category,
      cuisine: cuisine || 'Filipino',
      difficulty,
      prepTime: parseInt(prepTime),
      cookTime: parseInt(cookTime),
      servings: parseInt(servings),
      ingredients: JSON.parse(ingredients || '[]'),
      instructions: JSON.parse(instructions || '[]'),
      nutrition: JSON.parse(nutrition || '{}'),
      tags: JSON.parse(tags || '[]'),
      spiceLevel,
      dietaryInfo: JSON.parse(dietaryInfo || '{}')
    });

    await recipe.save();

    // Update user stats
    await User.findByIdAndUpdate(req.user._id, {
      $inc: { 'stats.recipesCreated': 1 }
    });

    const populatedRecipe = await Recipe.findById(recipe._id)
      .populate('creator', 'name profileImage');

    res.status(201).json({
      success: true,
      message: 'Recipe created successfully',
      recipe: populatedRecipe
    });
  } catch (error) {
    console.error('Create recipe error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   PUT /api/recipes/:id
// @desc    Update recipe
// @access  Private
router.put('/:id', auth, upload.diskUpload.array('recipeImages', 5), async (req, res) => {
  try {
    const recipe = await Recipe.findById(req.params.id);

    if (!recipe) {
      return res.status(404).json({
        success: false,
        message: 'Recipe not found'
      });
    }

    // Check if user owns the recipe
    if (recipe.creator.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to update this recipe'
      });
    }

    const updateData = { ...req.body };

    // Process new images if uploaded
    if (req.files && req.files.length > 0) {
      const newImages = req.files.map(file => `/uploads/recipes/${file.filename}`);
      updateData.images = [...(recipe.images || []), ...newImages];
    }

    // Parse JSON fields
    if (updateData.ingredients) updateData.ingredients = JSON.parse(updateData.ingredients);
    if (updateData.instructions) updateData.instructions = JSON.parse(updateData.instructions);
    if (updateData.nutrition) updateData.nutrition = JSON.parse(updateData.nutrition);
    if (updateData.tags) updateData.tags = JSON.parse(updateData.tags);
    if (updateData.dietaryInfo) updateData.dietaryInfo = JSON.parse(updateData.dietaryInfo);

    const updatedRecipe = await Recipe.findByIdAndUpdate(
      req.params.id,
      updateData,
      { new: true, runValidators: true }
    ).populate('creator', 'name profileImage');

    res.json({
      success: true,
      message: 'Recipe updated successfully',
      recipe: updatedRecipe
    });
  } catch (error) {
    console.error('Update recipe error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   DELETE /api/recipes/:id
// @desc    Delete recipe
// @access  Private
router.delete('/:id', auth, async (req, res) => {
  try {
    const recipe = await Recipe.findById(req.params.id);

    if (!recipe) {
      return res.status(404).json({
        success: false,
        message: 'Recipe not found'
      });
    }

    // Check if user owns the recipe
    if (recipe.creator.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to delete this recipe'
      });
    }

    await Recipe.findByIdAndDelete(req.params.id);

    // Update user stats
    await User.findByIdAndUpdate(req.user._id, {
      $inc: { 'stats.recipesCreated': -1 }
    });

    res.json({
      success: true,
      message: 'Recipe deleted successfully'
    });
  } catch (error) {
    console.error('Delete recipe error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   POST /api/recipes/:id/like
// @desc    Like/unlike recipe
// @access  Private
router.post('/:id/like', auth, async (req, res) => {
  try {
    const recipe = await Recipe.findById(req.params.id);

    if (!recipe) {
      return res.status(404).json({
        success: false,
        message: 'Recipe not found'
      });
    }

    const userId = req.user._id;
    const isLiked = recipe.likes.includes(userId);

    if (isLiked) {
      // Unlike
      recipe.likes.pull(userId);
      await User.findByIdAndUpdate(userId, {
        $pull: { likedRecipes: recipe._id }
      });
    } else {
      // Like
      recipe.likes.push(userId);
      await User.findByIdAndUpdate(userId, {
        $addToSet: { likedRecipes: recipe._id }
      });

      // Send notification to recipe creator
      if (recipe.creator.toString() !== userId.toString()) {
        const io = req.app.get('io');
        io.to(`user_${recipe.creator}`).emit('notification', {
          type: 'like',
          message: `${req.user.name} liked your recipe "${recipe.title}"`,
          data: { recipeId: recipe._id },
          sender: {
            _id: req.user._id,
            name: req.user.name,
            profileImage: req.user.profileImage
          }
        });
      }
    }

    await recipe.save();

    res.json({
      success: true,
      message: isLiked ? 'Recipe unliked' : 'Recipe liked',
      isLiked: !isLiked,
      likesCount: recipe.likes.length
    });
  } catch (error) {
    console.error('Like recipe error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   POST /api/recipes/:id/bookmark
// @desc    Bookmark/unbookmark recipe
// @access  Private
router.post('/:id/bookmark', auth, async (req, res) => {
  try {
    const recipe = await Recipe.findById(req.params.id);

    if (!recipe) {
      return res.status(404).json({
        success: false,
        message: 'Recipe not found'
      });
    }

    const userId = req.user._id;
    const isBookmarked = recipe.bookmarks.includes(userId);

    if (isBookmarked) {
      // Remove bookmark
      recipe.bookmarks.pull(userId);
      await User.findByIdAndUpdate(userId, {
        $pull: { bookmarkedRecipes: recipe._id }
      });
    } else {
      // Add bookmark
      recipe.bookmarks.push(userId);
      await User.findByIdAndUpdate(userId, {
        $addToSet: { bookmarkedRecipes: recipe._id }
      });
    }

    await recipe.save();

    res.json({
      success: true,
      message: isBookmarked ? 'Bookmark removed' : 'Recipe bookmarked',
      isBookmarked: !isBookmarked,
      bookmarksCount: recipe.bookmarks.length
    });
  } catch (error) {
    console.error('Bookmark recipe error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   POST /api/recipes/:id/rate
// @desc    Rate recipe
// @access  Private
router.post('/:id/rate', auth, [
  body('rating')
    .isInt({ min: 1, max: 5 })
    .withMessage('Rating must be between 1 and 5'),
  body('review')
    .optional()
    .trim()
    .isLength({ max: 500 })
    .withMessage('Review must be less than 500 characters')
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

    const { rating, review } = req.body;
    const recipe = await Recipe.findById(req.params.id);

    if (!recipe) {
      return res.status(404).json({
        success: false,
        message: 'Recipe not found'
      });
    }

    // Check if user already rated this recipe
    const existingRatingIndex = recipe.ratings.findIndex(
      r => r.user.toString() === req.user._id.toString()
    );

    if (existingRatingIndex !== -1) {
      // Update existing rating
      recipe.ratings[existingRatingIndex].rating = rating;
      recipe.ratings[existingRatingIndex].review = review;
    } else {
      // Add new rating
      recipe.ratings.push({
        user: req.user._id,
        rating,
        review
      });
    }

    await recipe.save();

    const populatedRecipe = await Recipe.findById(recipe._id)
      .populate('ratings.user', 'name profileImage');

    res.json({
      success: true,
      message: 'Rating submitted successfully',
      averageRating: populatedRecipe.averageRating,
      ratingsCount: populatedRecipe.ratings.length
    });
  } catch (error) {
    console.error('Rate recipe error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   GET /api/recipes/categories/list
// @desc    Get all recipe categories
// @access  Public
router.get('/categories/list', async (req, res) => {
  try {
    const categories = [
      'appetizer',
      'main_course', 
      'dessert',
      'beverage',
      'snack',
      'soup',
      'salad',
      'breakfast',
      'lunch',
      'dinner'
    ];

    res.json({
      success: true,
      categories
    });
  } catch (error) {
    console.error('Get categories error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

module.exports = router;
