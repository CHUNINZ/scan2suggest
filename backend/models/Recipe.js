const mongoose = require('mongoose');

const ingredientSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true
  },
  amount: {
    type: String,
    required: true
  },
  unit: {
    type: String,
    default: ''
  },
  notes: {
    type: String,
    default: ''
  }
});

const instructionSchema = new mongoose.Schema({
  step: {
    type: Number,
    required: true
  },
  instruction: {
    type: String,
    required: true
  },
  image: {
    type: String,
    default: null
  },
  duration: {
    type: Number, // in minutes
    default: 0
  }
});

const nutritionSchema = new mongoose.Schema({
  calories: Number,
  protein: String,
  carbs: String,
  fat: String,
  fiber: String,
  sugar: String,
  sodium: String
});

const recipeSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
    trim: true,
    maxlength: 100
  },
  description: {
    type: String,
    required: true,
    maxlength: 500
  },
  creator: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  images: [{
    type: String
  }],
  category: {
    type: String,
    required: true,
    enum: ['appetizer', 'main_course', 'dessert', 'beverage', 'snack', 'soup', 'salad', 'breakfast', 'lunch', 'dinner']
  },
  cuisine: {
    type: String,
    default: 'Filipino'
  },
  difficulty: {
    type: String,
    enum: ['easy', 'medium', 'hard'],
    default: 'medium'
  },
  prepTime: {
    type: Number, // in minutes
    required: true
  },
  cookTime: {
    type: Number, // in minutes
    required: true
  },
  totalTime: {
    type: Number // calculated field
  },
  servings: {
    type: Number,
    required: true,
    min: 1
  },
  ingredients: [ingredientSchema],
  instructions: [instructionSchema],
  nutrition: nutritionSchema,
  tags: [String],
  spiceLevel: {
    type: String,
    enum: ['mild', 'medium', 'spicy'],
    default: 'medium'
  },
  dietaryInfo: {
    isVegetarian: { type: Boolean, default: false },
    isVegan: { type: Boolean, default: false },
    isGlutenFree: { type: Boolean, default: false },
    isDairyFree: { type: Boolean, default: false }
  },
  ratings: [{
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User'
    },
    rating: {
      type: Number,
      min: 1,
      max: 5
    },
    review: String,
    createdAt: {
      type: Date,
      default: Date.now
    }
  }],
  likes: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  }],
  bookmarks: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  }],
  views: {
    type: Number,
    default: 0
  },
  isPublished: {
    type: Boolean,
    default: true
  },
  isFeatured: {
    type: Boolean,
    default: false
  },
  source: {
    type: String,
    enum: ['user_created', 'scanned', 'imported'],
    default: 'user_created'
  },
  scanData: {
    confidence: Number,
    detectedIngredients: [String],
    originalImage: String
  }
}, {
  timestamps: true
});

// Indexes for search and performance
recipeSchema.index({ title: 'text', description: 'text', tags: 'text' });
recipeSchema.index({ category: 1 });
recipeSchema.index({ creator: 1 });
recipeSchema.index({ createdAt: -1 });
recipeSchema.index({ 'ratings.rating': 1 });

// Calculate total time before saving
recipeSchema.pre('save', function(next) {
  this.totalTime = this.prepTime + this.cookTime;
  next();
});

// Virtual for average rating
recipeSchema.virtual('averageRating').get(function() {
  if (!this.ratings || this.ratings.length === 0) return 0;
  const sum = this.ratings.reduce((acc, rating) => acc + rating.rating, 0);
  return Math.round((sum / this.ratings.length) * 10) / 10;
});

// Virtual for likes count
recipeSchema.virtual('likesCount').get(function() {
  return this.likes ? this.likes.length : 0;
});

// Virtual for bookmarks count
recipeSchema.virtual('bookmarksCount').get(function() {
  return this.bookmarks ? this.bookmarks.length : 0;
});

// Virtual for ratings count
recipeSchema.virtual('ratingsCount').get(function() {
  return this.ratings ? this.ratings.length : 0;
});

// Ensure virtual fields are serialized
recipeSchema.set('toJSON', { virtuals: true });

module.exports = mongoose.model('Recipe', recipeSchema);
