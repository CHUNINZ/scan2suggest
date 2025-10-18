const axios = require('axios');

class RecipeService {
  constructor() {
    this.apiNinjasKey = process.env.API_NINJAS_KEY;
    this.mealDbUrl = 'https://www.themealdb.com/api/json/v1/1';
    this.apiNinjasUrl = 'https://api.api-ninjas.com/v2';
  }

  async getRecipeByName(foodName) {
    try {
      console.log(`🍳 Searching for recipe: ${foodName}`);
      
      // Try TheMealDB first (free, comprehensive)
      const mealDbResult = await this.searchMealDB(foodName);
      if (mealDbResult) {
        return mealDbResult;
      }

      // Fallback to API Ninjas if available
      if (this.apiNinjasKey) {
        const apiNinjasResult = await this.searchApiNinjas(foodName);
        if (apiNinjasResult) {
          return apiNinjasResult;
        }
      }

      // Generate basic recipe if no API results
      return this.generateBasicRecipe(foodName);

    } catch (error) {
      console.error('❌ Recipe search error:', error.message);
      return this.generateBasicRecipe(foodName);
    }
  }

  async searchMealDB(foodName) {
    try {
      const response = await axios.get(`${this.mealDbUrl}/search.php?s=${encodeURIComponent(foodName)}`);
      
      if (response.data.meals && response.data.meals.length > 0) {
        const meal = response.data.meals[0];
        return this.formatMealDBResponse(meal);
      }
      
      return null;
    } catch (error) {
      console.error('❌ MealDB search failed:', error.message);
      return null;
    }
  }

  async searchApiNinjas(foodName) {
    try {
      const response = await axios.get(`${this.apiNinjasUrl}/recipe?title=${encodeURIComponent(foodName)}`, {
        headers: {
          'X-Api-Key': this.apiNinjasKey
        }
      });

      if (response.data && response.data.length > 0) {
        return this.formatApiNinjasResponse(response.data[0]);
      }

      return null;
    } catch (error) {
      console.error('❌ API Ninjas search failed:', error.message);
      return null;
    }
  }

  formatMealDBResponse(meal) {
    // Extract ingredients from MealDB format
    const ingredients = [];
    for (let i = 1; i <= 20; i++) {
      const ingredient = meal[`strIngredient${i}`];
      const measure = meal[`strMeasure${i}`];
      if (ingredient && ingredient.trim()) {
        ingredients.push(`${measure ? measure.trim() + ' ' : ''}${ingredient.trim()}`);
      }
    }

    // Split instructions into steps
    const instructions = meal.strInstructions
      ? meal.strInstructions.split(/\d+\.|\r\n|\n/).filter(step => step.trim().length > 0)
      : [];

    return {
      title: meal.strMeal,
      ingredients: ingredients,
      instructions: instructions.map((step, index) => `${index + 1}. ${step.trim()}`),
      servings: "4 servings", // MealDB doesn't provide servings
      cookingTime: "30-45 minutes", // Estimated
      difficulty: "Medium",
      category: meal.strCategory || "Main Course",
      area: meal.strArea || "International",
      image: meal.strMealThumb,
      source: "TheMealDB"
    };
  }

  formatApiNinjasResponse(recipe) {
    return {
      title: recipe.title,
      ingredients: recipe.ingredients || [],
      instructions: recipe.instructions ? recipe.instructions.split(/\d+\./).filter(step => step.trim().length > 0).map((step, index) => `${index + 1}. ${step.trim()}`) : [],
      servings: recipe.servings || "4 servings",
      cookingTime: "30-45 minutes", // Estimated
      difficulty: "Medium",
      category: "Main Course",
      area: "International",
      image: null,
      source: "API Ninjas"
    };
  }

  generateBasicRecipe(foodName) {
    // Generate a basic recipe structure for Filipino dishes
    const filipinoRecipes = {
      'adobo': {
        ingredients: [
          '1 kg chicken or pork, cut into pieces',
          '1/2 cup soy sauce',
          '1/4 cup vinegar',
          '4 cloves garlic, minced',
          '2 bay leaves',
          '1 tsp black peppercorns',
          '2 tbsp cooking oil',
          'Salt to taste'
        ],
        instructions: [
          '1. Heat oil in a pan and sauté garlic until fragrant',
          '2. Add meat and cook until browned on all sides',
          '3. Pour soy sauce and vinegar, add bay leaves and peppercorns',
          '4. Bring to boil, then simmer for 30-40 minutes until tender',
          '5. Season with salt and serve hot with rice'
        ]
      },
      'sinigang': {
        ingredients: [
          '1 kg pork ribs or beef',
          '1 packet sinigang mix',
          '2 tomatoes, quartered',
          '1 onion, quartered',
          '2 cups kangkong leaves',
          '1 radish, sliced',
          '2 green chili peppers',
          'Salt and fish sauce to taste'
        ],
        instructions: [
          '1. Boil meat in water until tender (about 1 hour)',
          '2. Add tomatoes and onions, cook for 5 minutes',
          '3. Add sinigang mix and stir well',
          '4. Add radish and cook for 3 minutes',
          '5. Add kangkong and chili, season with salt and fish sauce',
          '6. Serve hot with rice'
        ]
      }
    };

    const recipe = filipinoRecipes[foodName.toLowerCase()] || {
      ingredients: [
        'Main ingredients as needed',
        'Seasonings (salt, pepper, garlic)',
        'Cooking oil',
        'Water or broth as needed'
      ],
      instructions: [
        '1. Prepare and clean all ingredients',
        '2. Heat oil in a pan or pot',
        '3. Cook ingredients according to traditional method',
        '4. Season to taste',
        '5. Serve hot with rice'
      ]
    };

    return {
      title: this.capitalizeWords(foodName),
      ingredients: recipe.ingredients,
      instructions: recipe.instructions,
      servings: "4-6 servings",
      cookingTime: "30-60 minutes",
      difficulty: "Medium",
      category: "Filipino Cuisine",
      area: "Philippines",
      image: null,
      source: "Generated Recipe"
    };
  }

  capitalizeWords(str) {
    return str.replace(/\b\w/g, l => l.toUpperCase());
  }

  async getRandomRecipe() {
    try {
      const response = await axios.get(`${this.mealDbUrl}/random.php`);
      if (response.data.meals && response.data.meals.length > 0) {
        return this.formatMealDBResponse(response.data.meals[0]);
      }
    } catch (error) {
      console.error('❌ Random recipe fetch failed:', error.message);
    }
    
    return this.generateBasicRecipe('Filipino Dish');
  }
}

module.exports = new RecipeService();
