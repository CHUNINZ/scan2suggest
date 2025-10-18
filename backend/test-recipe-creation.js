const axios = require('axios');
const FormData = require('form-data');
const fs = require('fs');
const path = require('path');

const BASE_URL = 'http://192.168.194.185:5001/api';

async function testRecipeCreation() {
  try {
    console.log('🧪 Testing Recipe Creation and Retrieval...\n');

    // Step 1: Login or use existing token
    console.log('📝 Step 1: Logging in...');
    const loginResponse = await axios.post(`${BASE_URL}/auth/login`, {
      email: 'test@example.com',
      password: 'password123'
    });

    if (!loginResponse.data.success) {
      console.error('❌ Login failed:', loginResponse.data.message);
      return;
    }

    const token = loginResponse.data.token;
    console.log('✅ Login successful');
    console.log('Token:', token.substring(0, 20) + '...\n');

    // Step 2: Create a recipe
    console.log('📝 Step 2: Creating a recipe...');
    
    const recipeData = {
      title: 'Chicken Adobo',
      description: 'The most iconic Filipino dish. Chicken braised in soy sauce, vinegar, garlic, and spices until tender and flavorful.',
      category: 'main_course',
      difficulty: 'easy',
      prepTime: 15,
      cookTime: 45,
      servings: 6,
      ingredients: JSON.stringify([
        { name: 'Chicken pieces', quantity: '1', unit: 'kg' },
        { name: 'Soy sauce', quantity: '1/2', unit: 'cup' },
        { name: 'White vinegar', quantity: '1/4', unit: 'cup' },
        { name: 'Garlic cloves, minced', quantity: '8', unit: 'pieces' },
        { name: 'Bay leaves', quantity: '3', unit: 'pieces' },
        { name: 'Black peppercorns', quantity: '1', unit: 'tsp' },
        { name: 'Onion, sliced', quantity: '1', unit: 'piece' },
        { name: 'Brown sugar', quantity: '1', unit: 'tbsp' }
      ]),
      instructions: JSON.stringify([
        { stepNumber: 1, instruction: 'In a bowl, combine chicken with soy sauce, vinegar, garlic, bay leaves, and peppercorns. Marinate for at least 30 minutes.' },
        { stepNumber: 2, instruction: 'Heat oil in a large pot over medium-high heat. Remove chicken from marinade (reserve the marinade) and brown on all sides.' },
        { stepNumber: 3, instruction: 'Add the onions and sauté until softened.' },
        { stepNumber: 4, instruction: 'Pour in the reserved marinade and add enough water to almost cover the chicken. Bring to a boil.' },
        { stepNumber: 5, instruction: 'Reduce heat to low, cover, and simmer for 30-40 minutes until chicken is tender.' },
        { stepNumber: 6, instruction: 'Remove lid and simmer uncovered until sauce thickens slightly. Add brown sugar and adjust seasoning.' },
        { stepNumber: 7, instruction: 'Serve hot with steamed rice. Enjoy!' }
      ]),
      tags: JSON.stringify(['filipino', 'chicken', 'adobo', 'traditional', 'savory']),
      nutrition: JSON.stringify({
        calories: 380,
        carbs: '8g',
        fat: '28g',
        protein: '32g'
      })
    };

    const form = new FormData();
    Object.keys(recipeData).forEach(key => {
      form.append(key, recipeData[key]);
    });

    const createResponse = await axios.post(`${BASE_URL}/recipes`, form, {
      headers: {
        ...form.getHeaders(),
        'Authorization': `Bearer ${token}`
      }
    });

    if (!createResponse.data.success) {
      console.error('❌ Recipe creation failed:', createResponse.data.message);
      return;
    }

    console.log('✅ Recipe created successfully!');
    console.log('Recipe ID:', createResponse.data.recipe._id);
    console.log('Recipe Title:', createResponse.data.recipe.title);
    console.log('Recipe Category:', createResponse.data.recipe.category);
    console.log('Recipe Difficulty:', createResponse.data.recipe.difficulty, '\n');

    // Step 3: Fetch all recipes
    console.log('📝 Step 3: Fetching all recipes...');
    const recipesResponse = await axios.get(`${BASE_URL}/recipes?limit=10`);

    if (!recipesResponse.data.success) {
      console.error('❌ Fetch recipes failed:', recipesResponse.data.message);
      return;
    }

    console.log('✅ Recipes fetched successfully!');
    console.log('Total recipes:', recipesResponse.data.pagination.total);
    console.log('\nRecipes:');
    recipesResponse.data.recipes.forEach((recipe, index) => {
      console.log(`  ${index + 1}. ${recipe.title}`);
      console.log(`     - Creator: ${recipe.creator.name}`);
      console.log(`     - Category: ${recipe.category}`);
      console.log(`     - Difficulty: ${recipe.difficulty}`);
      console.log(`     - Time: ${recipe.prepTime + recipe.cookTime} mins`);
      console.log('');
    });

    console.log('🎉 All tests completed successfully!');

  } catch (error) {
    console.error('❌ Error:', error.message);
    if (error.response) {
      console.error('Response data:', error.response.data);
    }
  }
}

testRecipeCreation();

