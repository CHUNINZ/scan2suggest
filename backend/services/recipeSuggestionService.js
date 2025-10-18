const axios = require('axios');
const recipeService = require('./enhancedRecipeService');

class RecipeSuggestionService {
  constructor() {
    this.mealDbUrl = 'https://www.themealdb.com/api/json/v1/1';
    this.spoonacularUrl = 'https://api.spoonacular.com/recipes';
    this.recipePuppyUrl = 'http://www.recipepuppy.com/api';
  }

  async suggestRecipesByIngredients(ingredients) {
    try {
      console.log(`🍳 Finding recipes for ingredients: ${ingredients.map(i => i.name).join(', ')}`);
      
      // Get recipe suggestions from multiple sources
      const suggestions = await Promise.allSettled([
        this.getFilipinoDishSuggestions(ingredients),
        this.getMealDBSuggestions(ingredients),
        this.getRecipePuppySuggestions(ingredients),
        this.getSpoonacularSuggestions(ingredients)
      ]);

      // Combine and rank suggestions
      const allSuggestions = this.combineSuggestions(suggestions);
      const rankedSuggestions = this.rankSuggestionsByIngredientMatch(allSuggestions, ingredients);

      console.log(`✅ Found ${rankedSuggestions.length} recipe suggestions`);
      
      return {
        success: true,
        suggestions: rankedSuggestions.slice(0, 10), // Top 10 suggestions
        ingredientsUsed: ingredients,
        totalFound: rankedSuggestions.length
      };

    } catch (error) {
      console.error('❌ Recipe suggestion error:', error.message);
      return {
        success: false,
        error: error.message,
        suggestions: []
      };
    }
  }

  getFilipinoDishSuggestions(ingredients) {
    const ingredientNames = ingredients.map(i => i.name.toLowerCase());
    
    // Filipino recipes with their key ingredients
    const filipinoRecipes = [
      {
        name: 'Chicken Adobo',
        keyIngredients: ['chicken', 'soy sauce', 'vinegar', 'garlic', 'onion'],
        description: 'Classic Filipino braised chicken in soy sauce and vinegar',
        difficulty: 'Easy',
        cookTime: 45,
        servings: 4,
        category: 'Main Course',
        image: null,
        source: 'Filipino Traditional'
      },
      {
        name: 'Sinigang na Baboy',
        keyIngredients: ['pork', 'tomato', 'onion', 'kangkong', 'radish', 'tamarind'],
        description: 'Sour Filipino soup with pork and vegetables',
        difficulty: 'Easy',
        cookTime: 75,
        servings: 6,
        category: 'Soup',
        image: null,
        source: 'Filipino Traditional'
      },
      {
        name: 'Vegetable Lumpia',
        keyIngredients: ['cabbage', 'carrot', 'bean sprouts', 'onion', 'garlic'],
        description: 'Fresh Filipino spring rolls with vegetables',
        difficulty: 'Medium',
        cookTime: 30,
        servings: 4,
        category: 'Appetizer',
        image: null,
        source: 'Filipino Traditional'
      },
      {
        name: 'Fried Rice',
        keyIngredients: ['rice', 'egg', 'garlic', 'onion', 'soy sauce'],
        description: 'Filipino-style fried rice with vegetables',
        difficulty: 'Easy',
        cookTime: 15,
        servings: 4,
        category: 'Main Course',
        image: null,
        source: 'Filipino Traditional'
      },
      {
        name: 'Ginisang Gulay',
        keyIngredients: ['cabbage', 'carrot', 'green beans', 'onion', 'garlic', 'tomato'],
        description: 'Sautéed mixed vegetables Filipino style',
        difficulty: 'Easy',
        cookTime: 20,
        servings: 4,
        category: 'Vegetable',
        image: null,
        source: 'Filipino Traditional'
      },
      {
        name: 'Chicken Tinola',
        keyIngredients: ['chicken', 'ginger', 'onion', 'chili leaves', 'papaya'],
        description: 'Filipino chicken soup with ginger and vegetables',
        difficulty: 'Easy',
        cookTime: 45,
        servings: 4,
        category: 'Soup',
        image: null,
        source: 'Filipino Traditional'
      },
      {
        name: 'Pancit Canton',
        keyIngredients: ['noodles', 'chicken', 'shrimp', 'cabbage', 'carrot', 'soy sauce'],
        description: 'Filipino stir-fried noodles with meat and vegetables',
        difficulty: 'Medium',
        cookTime: 25,
        servings: 6,
        category: 'Noodles',
        image: null,
        source: 'Filipino Traditional'
      }
    ];

    // Calculate match score for each recipe
    return filipinoRecipes.map(recipe => {
      const matchScore = this.calculateIngredientMatchScore(ingredientNames, recipe.keyIngredients);
      return {
        ...recipe,
        matchScore,
        matchedIngredients: recipe.keyIngredients.filter(ing => 
          ingredientNames.some(userIng => userIng.includes(ing) || ing.includes(userIng))
        ),
        missingIngredients: recipe.keyIngredients.filter(ing => 
          !ingredientNames.some(userIng => userIng.includes(ing) || ing.includes(userIng))
        )
      };
    }).filter(recipe => recipe.matchScore > 0);
  }

  async getMealDBSuggestions(ingredients) {
    try {
      const suggestions = [];
      
      // Search by main ingredients
      for (const ingredient of ingredients.slice(0, 3)) { // Limit to top 3 ingredients
        try {
          const response = await axios.get(
            `${this.mealDbUrl}/filter.php?i=${encodeURIComponent(ingredient.name)}`
          );
          
          if (response.data.meals) {
            const meals = response.data.meals.slice(0, 5).map(meal => ({
              name: meal.strMeal,
              description: `${meal.strCategory} dish featuring ${ingredient.name}`,
              difficulty: 'Medium',
              cookTime: 30,
              servings: 4,
              category: meal.strCategory,
              image: meal.strMealThumb,
              source: 'TheMealDB',
              matchScore: ingredient.confidence,
              matchedIngredients: [ingredient.name],
              missingIngredients: []
            }));
            
            suggestions.push(...meals);
          }
        } catch (error) {
          console.error(`❌ MealDB search failed for ${ingredient.name}:`, error.message);
        }
      }
      
      return suggestions;
    } catch (error) {
      console.error('❌ MealDB suggestions failed:', error.message);
      return [];
    }
  }

  async getRecipePuppySuggestions(ingredients) {
    try {
      const mainIngredients = ingredients.slice(0, 3).map(i => i.name).join(',');
      
      const response = await axios.get(
        `${this.recipePuppyUrl}?i=${encodeURIComponent(mainIngredients)}`
      );
      
      if (response.data.results) {
        return response.data.results.slice(0, 5).map(recipe => ({
          name: recipe.title,
          description: `Recipe featuring ${mainIngredients}`,
          difficulty: 'Medium',
          cookTime: 30,
          servings: 4,
          category: 'Main Course',
          image: recipe.thumbnail,
          source: 'Recipe Puppy',
          matchScore: 0.7,
          matchedIngredients: ingredients.slice(0, 3).map(i => i.name),
          missingIngredients: []
        }));
      }
      
      return [];
    } catch (error) {
      console.error('❌ Recipe Puppy suggestions failed:', error.message);
      return [];
    }
  }

  async getSpoonacularSuggestions(ingredients) {
    try {
      // Spoonacular requires API key - return empty if not configured
      if (!process.env.SPOONACULAR_API_KEY) {
        return [];
      }

      const ingredientList = ingredients.map(i => i.name).join(',');
      
      const response = await axios.get(
        `${this.spoonacularUrl}/findByIngredients?ingredients=${encodeURIComponent(ingredientList)}&number=5&apiKey=${process.env.SPOONACULAR_API_KEY}`
      );
      
      if (response.data) {
        return response.data.map(recipe => ({
          name: recipe.title,
          description: `Recipe using ${recipe.usedIngredientCount} of your ingredients`,
          difficulty: 'Medium',
          cookTime: 30,
          servings: 4,
          category: 'Main Course',
          image: recipe.image,
          source: 'Spoonacular',
          matchScore: recipe.usedIngredientCount / ingredients.length,
          matchedIngredients: recipe.usedIngredients?.map(i => i.name) || [],
          missingIngredients: recipe.missedIngredients?.map(i => i.name) || []
        }));
      }
      
      return [];
    } catch (error) {
      console.error('❌ Spoonacular suggestions failed:', error.message);
      return [];
    }
  }

  combineSuggestions(suggestionResults) {
    const allSuggestions = [];
    
    suggestionResults.forEach(result => {
      if (result.status === 'fulfilled' && Array.isArray(result.value)) {
        allSuggestions.push(...result.value);
      }
    });

    // Remove duplicates based on recipe name
    const uniqueSuggestions = [];
    const seenNames = new Set();
    
    allSuggestions.forEach(suggestion => {
      const normalizedName = suggestion.name.toLowerCase().trim();
      if (!seenNames.has(normalizedName)) {
        seenNames.add(normalizedName);
        uniqueSuggestions.push(suggestion);
      }
    });

    return uniqueSuggestions;
  }

  rankSuggestionsByIngredientMatch(suggestions, userIngredients) {
    const userIngredientNames = userIngredients.map(i => i.name.toLowerCase());
    
    return suggestions
      .map(suggestion => {
        // Recalculate match score if not already set
        if (!suggestion.matchScore && suggestion.keyIngredients) {
          suggestion.matchScore = this.calculateIngredientMatchScore(
            userIngredientNames, 
            suggestion.keyIngredients
          );
        }
        
        return suggestion;
      })
      .sort((a, b) => {
        // Sort by match score (higher is better)
        if (b.matchScore !== a.matchScore) {
          return b.matchScore - a.matchScore;
        }
        
        // Then by number of matched ingredients
        const aMatched = a.matchedIngredients?.length || 0;
        const bMatched = b.matchedIngredients?.length || 0;
        if (bMatched !== aMatched) {
          return bMatched - aMatched;
        }
        
        // Finally by fewer missing ingredients
        const aMissing = a.missingIngredients?.length || 0;
        const bMissing = b.missingIngredients?.length || 0;
        return aMissing - bMissing;
      });
  }

  calculateIngredientMatchScore(userIngredients, recipeIngredients) {
    if (!recipeIngredients || recipeIngredients.length === 0) return 0;
    
    let matches = 0;
    const totalRecipeIngredients = recipeIngredients.length;
    
    recipeIngredients.forEach(recipeIng => {
      const recipeIngLower = recipeIng.toLowerCase();
      const hasMatch = userIngredients.some(userIng => 
        userIng.includes(recipeIngLower) || recipeIngLower.includes(userIng)
      );
      if (hasMatch) matches++;
    });
    
    return matches / totalRecipeIngredients;
  }

  async getFullRecipeDetails(recipeName) {
    try {
      console.log(`📖 Getting full recipe details for: ${recipeName}`);
      
      // Use the enhanced recipe service to get complete recipe
      const recipe = await recipeService.getRecipeByName(recipeName);
      
      if (recipe) {
        return {
          success: true,
          recipe: recipe
        };
      }
      
      throw new Error('Recipe not found');
      
    } catch (error) {
      console.error(`❌ Error getting recipe details for ${recipeName}:`, error.message);
      return {
        success: false,
        error: error.message
      };
    }
  }

  // Generate shopping list for missing ingredients
  generateShoppingList(selectedRecipes, userIngredients) {
    const userIngredientNames = userIngredients.map(i => i.name.toLowerCase());
    const shoppingList = new Set();
    
    selectedRecipes.forEach(recipe => {
      if (recipe.missingIngredients) {
        recipe.missingIngredients.forEach(ingredient => {
          const ingredientLower = ingredient.toLowerCase();
          if (!userIngredientNames.some(userIng => 
            userIng.includes(ingredientLower) || ingredientLower.includes(userIng)
          )) {
            shoppingList.add(ingredient);
          }
        });
      }
    });
    
    return Array.from(shoppingList).sort();
  }
}

module.exports = new RecipeSuggestionService();
