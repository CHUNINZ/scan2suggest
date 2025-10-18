 const axios = require('axios');

class EnhancedRecipeService {
  constructor() {
    this.apiNinjasKey = process.env.API_NINJAS_KEY;
    this.mealDbUrl = 'https://www.themealdb.com/api/json/v1/1';
    this.spoonacularUrl = 'https://api.spoonacular.com/recipes';
    this.edamamUrl = 'https://api.edamam.com/search';
    this.recipePuppyUrl = 'http://www.recipepuppy.com/api';
  }

  async getRecipeByName(foodName) {
    try {
      console.log(`🍳 Searching for recipe: ${foodName}`);
      
      // First check if it's a Filipino dish we have detailed recipes for
      const filipinoRecipe = this.getDetailedFilipinoRecipe(foodName);
      if (filipinoRecipe) {
        console.log('✅ Found detailed Filipino recipe');
        return filipinoRecipe;
      }
      
      // Try TheMealDB first (free, comprehensive)
      const mealDbResult = await this.searchMealDB(foodName);
      if (mealDbResult) {
        console.log('✅ Found recipe in TheMealDB');
        return mealDbResult;
      }

      // Try Recipe Puppy (free API)
      const recipePuppyResult = await this.searchRecipePuppy(foodName);
      if (recipePuppyResult) {
        console.log('✅ Found recipe in Recipe Puppy');
        return recipePuppyResult;
      }

      // Try Edamam Recipe Search (free tier)
      const edamamResult = await this.searchEdamam(foodName);
      if (edamamResult) {
        console.log('✅ Found recipe in Edamam');
        return edamamResult;
      }

      // Fallback to API Ninjas if available
      if (this.apiNinjasKey) {
        const apiNinjasResult = await this.searchApiNinjas(foodName);
        if (apiNinjasResult) {
          console.log('✅ Found recipe in API Ninjas');
          return apiNinjasResult;
        }
      }

      // Generate enhanced basic recipe
      console.log('📝 Generating enhanced basic recipe');
      return this.generateEnhancedBasicRecipe(foodName);

    } catch (error) {
      console.error('❌ Recipe search error:', error.message);
      return this.generateEnhancedBasicRecipe(foodName);
    }
  }

  getDetailedFilipinoRecipe(foodName) {
    const name = foodName.toLowerCase().replace(/[^a-z\s]/g, '').trim();
    
    const filipinoRecipes = {
      'chicken adobo': {
        title: 'Chicken Adobo',
        ingredients: [
          '1 kg chicken pieces (thighs and drumsticks)',
          '1/2 cup soy sauce',
          '1/4 cup white vinegar',
          '6-8 cloves garlic, minced',
          '3 bay leaves',
          '1 tsp whole black peppercorns',
          '1 medium onion, sliced',
          '2 tbsp cooking oil',
          '1 tbsp brown sugar (optional)',
          'Salt to taste'
        ],
        instructions: [
          'Marinate chicken in soy sauce and vinegar for at least 30 minutes.',
          'Heat oil in a heavy-bottomed pot over medium heat.',
          'Sauté garlic and onion until fragrant and golden.',
          'Add marinated chicken and cook until browned on all sides.',
          'Pour in the marinade, add bay leaves and peppercorns.',
          'Bring to a boil, then reduce heat and simmer covered for 25-30 minutes.',
          'Remove lid and simmer for another 10 minutes to reduce sauce.',
          'Add brown sugar if desired for a slightly sweet taste.',
          'Season with salt and serve hot with steamed rice.'
        ],
        prepTime: 45,
        cookTime: 45,
        servings: 4,
        difficulty: 'Easy'
      },
      
      'adobo': {
        title: 'Chicken Adobo',
        ingredients: [
          '1 kg chicken pieces (thighs and drumsticks)',
          '1/2 cup soy sauce',
          '1/4 cup white vinegar',
          '6-8 cloves garlic, minced',
          '3 bay leaves',
          '1 tsp whole black peppercorns',
          '1 medium onion, sliced',
          '2 tbsp cooking oil',
          '1 tbsp brown sugar (optional)',
          'Salt to taste'
        ],
        instructions: [
          'Marinate chicken in soy sauce and vinegar for at least 30 minutes.',
          'Heat oil in a heavy-bottomed pot over medium heat.',
          'Sauté garlic and onion until fragrant and golden.',
          'Add marinated chicken and cook until browned on all sides.',
          'Pour in the marinade, add bay leaves and peppercorns.',
          'Bring to a boil, then reduce heat and simmer covered for 25-30 minutes.',
          'Remove lid and simmer for another 10 minutes to reduce sauce.',
          'Add brown sugar if desired for a slightly sweet taste.',
          'Season with salt and serve hot with steamed rice.'
        ],
        prepTime: 45,
        cookTime: 45,
        servings: 4,
        difficulty: 'Easy'
      },

      'sinigang': {
        title: 'Sinigang na Baboy',
        ingredients: [
          '1 kg pork ribs or pork belly, cut into pieces',
          '2-3 tbsp tamarind paste or 1 packet sinigang mix',
          '2 medium tomatoes, quartered',
          '1 large onion, quartered',
          '2 cups kangkong (water spinach) leaves',
          '1 medium radish (labanos), sliced',
          '2-3 pieces green chili (siling haba)',
          '1 medium eggplant, sliced',
          '2 tbsp fish sauce (patis)',
          '8-10 cups water',
          'Salt to taste'
        ],
        instructions: [
          'In a large pot, boil pork in water for 1 hour or until tender.',
          'Add tomatoes and onions, cook for 5 minutes until soft.',
          'Add tamarind paste or sinigang mix, stir well to dissolve.',
          'Add radish and eggplant, cook for 5 minutes.',
          'Add green chili and cook for 2 minutes.',
          'Season with fish sauce and salt to taste.',
          'Add kangkong leaves last and cook for 1-2 minutes.',
          'Serve hot with steamed rice.'
        ],
        prepTime: 15,
        cookTime: 75,
        servings: 6,
        difficulty: 'Easy'
      },

      'kare kare': {
        title: 'Kare-Kare',
        ingredients: [
          '1.5 kg oxtail, cut into pieces',
          '1 cup peanut butter (smooth)',
          '1/4 cup rice flour or ground rice',
          '2 medium eggplants, sliced',
          '1 bundle string beans (sitaw), cut into 2-inch pieces',
          '1 banana heart (puso ng saging), sliced',
          '3-4 tbsp shrimp paste (bagoong alamang)',
          '2 tbsp annatto seeds or annatto powder',
          '1 medium onion, chopped',
          '4 cloves garlic, minced',
          '2 tbsp cooking oil',
          'Salt and pepper to taste'
        ],
        instructions: [
          'Boil oxtail in water for 2-3 hours until very tender.',
          'Reserve the broth and set aside the meat.',
          'Soak annatto seeds in 1/4 cup warm water, strain to get the color.',
          'Heat oil in a large pot, sauté garlic and onion.',
          'Add peanut butter and rice flour, mix well.',
          'Gradually add the reserved broth while stirring continuously.',
          'Add annatto water for color and bring to a boil.',
          'Add the cooked oxtail and simmer for 10 minutes.',
          'Add vegetables starting with the hardest (eggplant, then string beans).',
          'Season with salt and pepper.',
          'Serve hot with steamed rice and shrimp paste on the side.'
        ],
        prepTime: 30,
        cookTime: 180,
        servings: 6,
        difficulty: 'Medium'
      },

      'lechon': {
        title: 'Lechon Kawali',
        ingredients: [
          '1 kg pork belly, skin on',
          '2 tbsp salt',
          '1 tsp black pepper',
          '4 bay leaves',
          '1 tsp peppercorns',
          '4 cloves garlic',
          'Water for boiling',
          'Oil for deep frying'
        ],
        instructions: [
          'Rub pork belly with salt and pepper, let it sit for 30 minutes.',
          'In a large pot, boil water with bay leaves, peppercorns, and garlic.',
          'Add pork belly and boil for 45 minutes until tender.',
          'Remove pork and let it cool and dry completely (preferably overnight).',
          'Heat oil in a deep pan for frying.',
          'Deep fry the pork belly until skin is golden and crispy.',
          'Drain on paper towels and let it rest for 5 minutes.',
          'Chop into serving pieces and serve with lechon sauce or liver sauce.'
        ],
        prepTime: 60,
        cookTime: 60,
        servings: 4,
        difficulty: 'Medium'
      },

      'lumpia': {
        title: 'Fresh Lumpia (Lumpiang Sariwa)',
        ingredients: [
          '20 pieces lumpia wrapper',
          '2 cups cooked shrimp, chopped',
          '2 cups lettuce leaves, chopped',
          '1 cup carrots, julienned',
          '1 cup bean sprouts',
          '1 cup jicama (singkamas), julienned',
          '2 hard-boiled eggs, sliced',
          '1/4 cup peanuts, crushed',
          '2 cloves garlic, minced',
          '2 tbsp cooking oil'
        ],
        instructions: [
          'Heat oil in a pan and sauté garlic until fragrant.',
          'Add shrimp and cook for 2 minutes.',
          'Add vegetables (except lettuce) and stir-fry for 3-4 minutes.',
          'Season with salt and pepper, let cool.',
          'Place lettuce on lumpia wrapper, add filling mixture.',
          'Add egg slices and crushed peanuts.',
          'Roll tightly and serve with sweet and sour sauce.',
          'Garnish with additional crushed peanuts if desired.'
        ],
        prepTime: 30,
        cookTime: 15,
        servings: 4,
        difficulty: 'Easy'
      },

      'pancit': {
        title: 'Pancit Canton',
        ingredients: [
          '500g pancit canton noodles',
          '200g pork, sliced thin',
          '200g chicken breast, sliced',
          '100g shrimp, peeled',
          '2 cups cabbage, chopped',
          '1 cup carrots, julienned',
          '1 cup snow peas',
          '4 cloves garlic, minced',
          '1 medium onion, sliced',
          '3 tbsp soy sauce',
          '2 tbsp oyster sauce',
          '3 cups chicken broth',
          '2 tbsp cooking oil'
        ],
        instructions: [
          'Soak pancit canton noodles in warm water until soft.',
          'Heat oil in a large wok or pan.',
          'Sauté garlic and onion until fragrant.',
          'Add pork and chicken, cook until no longer pink.',
          'Add shrimp and cook for 2 minutes.',
          'Add hard vegetables (carrots) first, then softer ones.',
          'Add drained noodles and mix gently.',
          'Pour soy sauce, oyster sauce, and broth gradually.',
          'Toss everything together and cook for 5-7 minutes.',
          'Serve hot with lemon wedges and fish sauce.'
        ],
        prepTime: 20,
        cookTime: 20,
        servings: 6,
        difficulty: 'Easy'
      }
    };

    const recipe = filipinoRecipes[name];
    if (recipe) {
      return {
        ...recipe,
        category: 'Filipino Cuisine',
        area: 'Philippines',
        image: null,
        source: 'Authentic Filipino Recipe'
      };
    }

    return null;
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

  async searchRecipePuppy(foodName) {
    try {
      const response = await axios.get(`${this.recipePuppyUrl}?q=${encodeURIComponent(foodName)}`);
      
      if (response.data.results && response.data.results.length > 0) {
        const recipe = response.data.results[0];
        return this.formatRecipePuppyResponse(recipe);
      }
      
      return null;
    } catch (error) {
      console.error('❌ Recipe Puppy search failed:', error.message);
      return null;
    }
  }

  async searchEdamam(foodName) {
    try {
      // Note: Edamam requires API key, but has a free tier
      if (!process.env.EDAMAM_APP_ID || !process.env.EDAMAM_APP_KEY) {
        return null;
      }

      const response = await axios.get(`${this.edamamUrl}?q=${encodeURIComponent(foodName)}&app_id=${process.env.EDAMAM_APP_ID}&app_key=${process.env.EDAMAM_APP_KEY}&from=0&to=1`);
      
      if (response.data.hits && response.data.hits.length > 0) {
        const recipe = response.data.hits[0].recipe;
        return this.formatEdamamResponse(recipe);
      }
      
      return null;
    } catch (error) {
      console.error('❌ Edamam search failed:', error.message);
      return null;
    }
  }

  async searchApiNinjas(foodName) {
    try {
      const response = await axios.get(`https://api.api-ninjas.com/v1/recipe?query=${encodeURIComponent(foodName)}`, {
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
        ingredients.push({
          name: ingredient.trim(),
          amount: measure ? measure.trim() : ''
        });
      }
    }

    // Split instructions into clear step-by-step format
    const instructions = meal.strInstructions
      ? this.formatInstructionsIntoSteps(meal.strInstructions)
      : [];

    return {
      title: meal.strMeal,
      ingredients: ingredients,
      instructions: instructions,
      prepTime: 15,
      cookTime: 30,
      servings: 4,
      difficulty: 'Medium',
      category: meal.strCategory || 'Main Course',
      area: meal.strArea || 'International',
      image: meal.strMealThumb,
      source: 'TheMealDB'
    };
  }

  formatRecipePuppyResponse(recipe) {
    // Recipe Puppy has limited data, so we enhance it
    const ingredients = recipe.ingredients 
      ? recipe.ingredients.split(',').map(ing => ({
          name: ing.trim(),
          amount: ''
        }))
      : [];

    // Generate detailed cooking steps based on the recipe title
    const detailedSteps = this.generateDetailedStepsForDish(recipe.title, ingredients);

    return {
      title: recipe.title,
      ingredients: ingredients,
      instructions: detailedSteps,
      prepTime: 15,
      cookTime: 30,
      servings: 4,
      difficulty: 'Medium',
      category: 'Main Course',
      area: 'International',
      image: recipe.thumbnail,
      source: 'Recipe Puppy'
    };
  }

  formatEdamamResponse(recipe) {
    const ingredients = recipe.ingredientLines.map(line => ({
      name: line,
      amount: ''
    }));

    // Generate detailed steps based on recipe type
    const detailedSteps = this.generateDetailedStepsForDish(recipe.label, ingredients);

    return {
      title: recipe.label,
      ingredients: ingredients,
      instructions: detailedSteps,
      prepTime: Math.round(recipe.totalTime / 2) || 15,
      cookTime: Math.round(recipe.totalTime / 2) || 30,
      servings: recipe.yield || 4,
      difficulty: 'Medium',
      category: recipe.dishType?.[0] || 'Main Course',
      area: recipe.cuisineType?.[0] || 'International',
      image: recipe.image,
      source: 'Edamam'
    };
  }

  formatApiNinjasResponse(recipe) {
    const ingredients = recipe.ingredients 
      ? recipe.ingredients.split('|').map(ing => ({
          name: ing.trim(),
          amount: ''
        }))
      : [];

    // Format instructions properly or generate detailed steps
    let instructions = [];
    if (recipe.instructions) {
      instructions = this.formatInstructionsIntoSteps(recipe.instructions);
    } else {
      instructions = this.generateDetailedStepsForDish(recipe.title, ingredients);
    }

    return {
      title: recipe.title,
      ingredients: ingredients,
      instructions: instructions,
      prepTime: 15,
      cookTime: 30,
      servings: recipe.servings || 4,
      difficulty: 'Medium',
      category: 'Main Course',
      area: 'International',
      image: null,
      source: 'API Ninjas'
    };
  }

  generateEnhancedBasicRecipe(foodName) {
    const name = foodName.toLowerCase();
    
    // Enhanced basic recipes for common foods
    const basicRecipes = {
      'fried rice': {
        ingredients: [
          { name: 'Cooked rice (preferably day-old)', amount: '4 cups' },
          { name: 'Eggs', amount: '2-3 pieces' },
          { name: 'Garlic', amount: '3 cloves, minced' },
          { name: 'Onion', amount: '1 medium, diced' },
          { name: 'Soy sauce', amount: '3 tbsp' },
          { name: 'Cooking oil', amount: '3 tbsp' },
          { name: 'Green onions', amount: '2 stalks, chopped' },
          { name: 'Salt and pepper', amount: 'to taste' }
        ]
      },
      'pasta': {
        ingredients: [
          { name: 'Pasta', amount: '500g' },
          { name: 'Garlic', amount: '4 cloves, minced' },
          { name: 'Olive oil', amount: '3 tbsp' },
          { name: 'Onion', amount: '1 medium, diced' },
          { name: 'Salt and pepper', amount: 'to taste' },
          { name: 'Parmesan cheese', amount: '1/2 cup, grated' }
        ]
      },
      'steak': {
        ingredients: [
          { name: 'Beef steak', amount: '4 pieces' },
          { name: 'Salt', amount: '1 tsp' },
          { name: 'Black pepper', amount: '1/2 tsp' },
          { name: 'Garlic', amount: '2 cloves, minced' },
          { name: 'Butter', amount: '2 tbsp' },
          { name: 'Cooking oil', amount: '2 tbsp' }
        ]
      }
    };

    // Get ingredients or use default
    const ingredients = basicRecipes[name]?.ingredients || [
      { name: 'Main ingredient', amount: 'as needed' },
      { name: 'Garlic', amount: '2-3 cloves' },
      { name: 'Onion', amount: '1 medium' },
      { name: 'Salt and pepper', amount: 'to taste' },
      { name: 'Cooking oil', amount: '2 tbsp' }
    ];

    // Generate detailed cooking steps based on food type
    const instructions = this.generateDetailedStepsForDish(foodName, ingredients);

    return {
      title: this.capitalizeWords(foodName),
      ingredients: ingredients,
      instructions: instructions,
      prepTime: 15,
      cookTime: 30,
      servings: 4,
      difficulty: 'Medium',
      category: 'Main Course',
      area: 'International',
      image: null,
      source: 'Generated Recipe'
    };
  }

  capitalizeWords(str) {
    return str.replace(/\b\w/g, l => l.toUpperCase());
  }

  // Format raw instructions into clear step-by-step cooking instructions
  formatInstructionsIntoSteps(rawInstructions) {
    if (!rawInstructions) return [];

    // Split by common delimiters and clean up
    let steps = rawInstructions
      .split(/\r\n\r\n|\n\n|\d+\.\s*|Step \d+:?/gi)
      .filter(step => step.trim().length > 10)
      .map(step => step.trim())
      .filter(step => !step.match(/^(ingredients?|method|instructions?):?$/i));

    // If no clear steps found, split by sentences and group logically
    if (steps.length <= 1) {
      steps = rawInstructions
        .split(/\.\s+(?=[A-Z])/g)
        .filter(step => step.trim().length > 15)
        .map(step => step.trim().replace(/\.$/, ''));
    }

    // Format each step with cooking action words and clear instructions
    return steps.map((step, index) => {
      let instruction = step.trim();
      
      // Ensure step starts with an action word
      if (!instruction.match(/^(heat|add|cook|stir|mix|boil|fry|bake|season|serve|prepare|cut|chop|slice|dice|sauté|simmer|bring|remove|drain|pour|place|cover|let|allow|combine|whisk|blend)/i)) {
        // Add appropriate cooking action based on content
        if (instruction.match(/oil|pan|pot/i)) {
          instruction = `Heat ${instruction.toLowerCase()}`;
        } else if (instruction.match(/ingredient|add/i)) {
          instruction = `Add ${instruction.toLowerCase()}`;
        } else if (instruction.match(/cook|minute|hour/i)) {
          instruction = `Cook ${instruction.toLowerCase()}`;
        } else {
          instruction = `${instruction.charAt(0).toUpperCase()}${instruction.slice(1)}`;
        }
      } else {
        instruction = `${instruction.charAt(0).toUpperCase()}${instruction.slice(1)}`;
      }

      // Ensure instruction ends with proper punctuation
      if (!instruction.match(/[.!]$/)) {
        instruction += '.';
      }

      return {
        step: index + 1,
        instruction: instruction
      };
    });
  }

  // Generate detailed cooking steps for common dishes
  generateDetailedStepsForDish(dishName, ingredients) {
    const name = dishName.toLowerCase();
    
    // Common cooking patterns for different types of dishes
    if (name.includes('pasta') || name.includes('spaghetti') || name.includes('noodle')) {
      return [
        { step: 1, instruction: 'Bring a large pot of salted water to boil.' },
        { step: 2, instruction: 'Add pasta and cook according to package directions until al dente.' },
        { step: 3, instruction: 'Heat oil in a large pan over medium heat.' },
        { step: 4, instruction: 'Sauté garlic and onions until fragrant and golden.' },
        { step: 5, instruction: 'Add other ingredients and cook until tender.' },
        { step: 6, instruction: 'Drain pasta and add to the pan with sauce.' },
        { step: 7, instruction: 'Toss everything together and cook for 2-3 minutes.' },
        { step: 8, instruction: 'Season with salt and pepper to taste.' },
        { step: 9, instruction: 'Serve hot with grated cheese if desired.' }
      ];
    }
    
    if (name.includes('soup') || name.includes('broth') || name.includes('stew')) {
      return [
        { step: 1, instruction: 'Heat oil in a large pot over medium heat.' },
        { step: 2, instruction: 'Sauté onions and garlic until fragrant.' },
        { step: 3, instruction: 'Add meat (if using) and brown on all sides.' },
        { step: 4, instruction: 'Add vegetables starting with the hardest ones first.' },
        { step: 5, instruction: 'Pour in broth or water to cover ingredients.' },
        { step: 6, instruction: 'Bring to a boil, then reduce heat and simmer.' },
        { step: 7, instruction: 'Cook for 30-45 minutes until all ingredients are tender.' },
        { step: 8, instruction: 'Season with salt, pepper, and herbs to taste.' },
        { step: 9, instruction: 'Serve hot with bread or rice.' }
      ];
    }
    
    if (name.includes('rice') || name.includes('fried')) {
      return [
        { step: 1, instruction: 'Heat oil in a large wok or pan over high heat.' },
        { step: 2, instruction: 'Beat eggs and scramble them, then set aside.' },
        { step: 3, instruction: 'Add garlic and onions to the pan, stir-fry until fragrant.' },
        { step: 4, instruction: 'Add rice and stir-fry, breaking up any clumps.' },
        { step: 5, instruction: 'Add soy sauce and other seasonings, mix well.' },
        { step: 6, instruction: 'Add vegetables and protein, stir-fry for 3-4 minutes.' },
        { step: 7, instruction: 'Return scrambled eggs to the pan and mix gently.' },
        { step: 8, instruction: 'Garnish with green onions and serve hot.' }
      ];
    }
    
    if (name.includes('chicken') || name.includes('meat') || name.includes('pork') || name.includes('beef')) {
      return [
        { step: 1, instruction: 'Season the meat with salt and pepper.' },
        { step: 2, instruction: 'Heat oil in a large pan over medium-high heat.' },
        { step: 3, instruction: 'Sear the meat until browned on all sides.' },
        { step: 4, instruction: 'Add onions and garlic, cook until fragrant.' },
        { step: 5, instruction: 'Add other vegetables and seasonings.' },
        { step: 6, instruction: 'Add liquid (broth, wine, or water) as needed.' },
        { step: 7, instruction: 'Cover and simmer until meat is tender.' },
        { step: 8, instruction: 'Adjust seasoning and serve hot with rice or vegetables.' }
      ];
    }
    
    // Default detailed cooking steps
    return [
      { step: 1, instruction: 'Prepare all ingredients by washing, chopping, and measuring as needed.' },
      { step: 2, instruction: 'Heat oil in a large pan or pot over medium heat.' },
      { step: 3, instruction: 'Sauté aromatics (garlic, onions, ginger) until fragrant.' },
      { step: 4, instruction: 'Add main ingredients and cook according to their cooking times.' },
      { step: 5, instruction: 'Season with salt, pepper, and other spices to taste.' },
      { step: 6, instruction: 'Add liquid if needed and bring to appropriate temperature.' },
      { step: 7, instruction: 'Cook until all ingredients are tender and flavors are well combined.' },
      { step: 8, instruction: 'Taste and adjust seasoning as needed.' },
      { step: 9, instruction: 'Serve hot with appropriate accompaniments.' }
    ];
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
    
    return this.generateEnhancedBasicRecipe('Filipino Dish');
  }
}

module.exports = new EnhancedRecipeService();
