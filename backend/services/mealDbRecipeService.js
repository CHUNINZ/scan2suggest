const axios = require('axios');

class MealDbRecipeService {
  constructor() {
    // TheMealDB free API - no key required
    this.apiUrl = 'https://www.themealdb.com/api/json/v1/1';
    console.log('✅ TheMealDB Recipe service initialized (Free API)');
  }

  async getRecipeForFood(foodName) {
    try {
      console.log(`🍽️ Searching TheMealDB for recipe: ${foodName}`);
      
      // Search for the meal by name
      const searchResponse = await axios.get(
        `${this.apiUrl}/search.php`,
        {
          params: { s: foodName },
          timeout: 10000
        }
      );

      if (searchResponse.data && searchResponse.data.meals && searchResponse.data.meals.length > 0) {
        const meal = searchResponse.data.meals[0];
        console.log(`✅ Found recipe for: ${meal.strMeal}`);
        
        // Format the recipe
        return this.formatRecipe(meal);
      }

      // If exact match not found, try searching for partial matches
      console.log('🔍 Exact match not found, trying partial search...');
      const words = foodName.split(' ');
      for (const word of words) {
        if (word.length > 3) { // Skip small words
          const partialResponse = await axios.get(
            `${this.apiUrl}/search.php`,
            {
              params: { s: word },
              timeout: 10000
            }
          );

          if (partialResponse.data && partialResponse.data.meals && partialResponse.data.meals.length > 0) {
            const meal = partialResponse.data.meals[0];
            console.log(`✅ Found similar recipe: ${meal.strMeal}`);
            return this.formatRecipe(meal);
          }
        }
      }

      // If still no results, generate a generic Filipino recipe format
      console.log('⚠️ No recipe found in database, generating generic format');
      return this.generateGenericRecipe(foodName);

    } catch (error) {
      console.error('❌ MealDB API error:', error.message);
      // Return a generic recipe on error
      return this.generateGenericRecipe(foodName);
    }
  }

  formatRecipe(meal) {
    // Extract ingredients
    const ingredients = [];
    for (let i = 1; i <= 20; i++) {
      const ingredient = meal[`strIngredient${i}`];
      const measure = meal[`strMeasure${i}`];
      
      if (ingredient && ingredient.trim()) {
        const formattedIngredient = measure && measure.trim() 
          ? `${measure.trim()} ${ingredient.trim()}`
          : ingredient.trim();
        ingredients.push(`- ${formattedIngredient}`);
      }
    }

    // Extract instructions
    const instructions = meal.strInstructions
      .split(/\r?\n/)
      .filter(line => line.trim())
      .map((line, index) => `${index + 1}. ${line.trim()}`);

    // Format as text similar to AI response
    const recipeText = `Ingredients:
${ingredients.join('\n')}

Instructions:
${instructions.join('\n')}`;

    // Return in format compatible with AI Recipe page
    return {
      candidates: [{
        content: {
          parts: [{
            text: recipeText
          }]
        }
      }]
    };
  }

  generateGenericRecipe(foodName) {
    // Generate a generic Filipino-style recipe template
    const recipeText = `Ingredients:
- 1 kg ${foodName.includes('Chicken') ? 'chicken' : foodName.includes('Pork') ? 'pork' : foodName.includes('Beef') ? 'beef' : 'meat'}, cut into pieces
- 3 cloves garlic, minced
- 1 medium onion, chopped
- 2 tablespoons cooking oil
- 1 cup water or broth
- 2 tablespoons soy sauce
- 1 tablespoon vinegar
- Salt and pepper to taste
- Bay leaves
- Optional: vegetables of your choice

Instructions:
1. Heat oil in a large pan over medium heat.
2. Sauté garlic and onions until fragrant and golden.
3. Add the main ingredient and cook until lightly browned on all sides.
4. Pour in the soy sauce, vinegar, and water or broth.
5. Add bay leaves and season with salt and pepper.
6. Bring to a boil, then reduce heat and simmer for 30-40 minutes until tender.
7. Add vegetables if using and cook until tender.
8. Adjust seasoning to taste.
9. Serve hot with steamed rice.
10. Enjoy your ${foodName}!

Note: This is a basic recipe template. Cooking times and ingredients may vary based on your preferences.`;

    return {
      candidates: [{
        content: {
          parts: [{
            text: recipeText
          }]
        }
      }]
    };
  }
}

module.exports = new MealDbRecipeService();

