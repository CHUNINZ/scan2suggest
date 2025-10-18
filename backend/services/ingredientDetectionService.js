const axios = require('axios');

class IngredientDetectionService {
  constructor() {
    this.roboflowUrl = 'https://serverless.roboflow.com/food_test-rufh3/2';
    this.roboflowApiKey = 'sK6jDsSmdvh6aQ5a0Ea9';
  }

  async detectIngredients(imageBuffer, filename) {
    try {
      console.log('🔍 Starting ingredient detection...');

      // Use only Roboflow for ingredient detection
      const roboflowResults = await this.detectWithRoboflow(imageBuffer);

      if (roboflowResults.length === 0) {
        return {
          success: false,
          error: 'No ingredients detected in the image',
          ingredients: []
        };
      }

      console.log(`✅ Detected ${roboflowResults.length} ingredients`);
      return {
        success: true,
        ingredients: roboflowResults,
        confidence: this.calculateOverallConfidence(roboflowResults)
      };

    } catch (error) {
      console.error('❌ Ingredient detection error:', error.message);
      return {
        success: false,
        error: error.message,
        ingredients: []
      };
    }
  }

  async detectWithRoboflow(imageBuffer) {
    try {
      console.log('🤖 Using Roboflow for ingredient detection...');

      // Convert buffer to base64 for the new Roboflow API
      const base64Image = imageBuffer.toString('base64');

      const response = await axios({
        method: "POST",
        url: this.roboflowUrl,
        params: {
          api_key: this.roboflowApiKey
        },
        data: base64Image,
        headers: {
          "Content-Type": "application/x-www-form-urlencoded"
        },
        timeout: 30000
      });

      console.log('🔍 Roboflow response received');
      console.log('📊 Roboflow raw response:', JSON.stringify(response.data, null, 2));

      if (response.data && response.data.predictions) {
        const detections = [];

        // Process Roboflow predictions (direct model response)
        for (const prediction of response.data.predictions) {
          if (prediction.class && prediction.confidence) {
            detections.push({
              name: this.normalizeIngredientName(prediction.class),
              confidence: prediction.confidence,
              source: 'Roboflow',
              category: this.categorizeIngredient(prediction.class),
              boundingBox: prediction.x && prediction.y ? {
                x: prediction.x,
                y: prediction.y,
                width: prediction.width,
                height: prediction.height
              } : null
            });
          }
        }

        console.log(`✅ Roboflow detected ${detections.length} ingredients`);
        return detections.filter(detection => detection.confidence > 0.1);
      }

      return [];
    } catch (error) {
      console.error('❌ Roboflow detection failed:', error.message);
      if (error.response && error.response.data) {
        console.error('❌ Roboflow error details:', JSON.stringify(error.response.data, null, 2));
      }
      throw error; // Throw error instead of returning empty array
    }
  }






  normalizeIngredientName(name) {
    // Clean and normalize ingredient names
    return name
      .toLowerCase()
      .replace(/[^a-z\s]/g, '')
      .replace(/\s+/g, ' ')
      .trim()
      .split(' ')
      .map(word => word.charAt(0).toUpperCase() + word.slice(1))
      .join(' ');
  }

  categorizeIngredient(name) {
    const categories = {
      vegetable: ['tomato', 'onion', 'garlic', 'carrot', 'potato', 'cabbage', 'lettuce', 'spinach', 'broccoli'],
      fruit: ['apple', 'banana', 'orange', 'mango', 'pineapple', 'coconut', 'lemon', 'lime'],
      meat: ['chicken', 'pork', 'beef', 'fish', 'shrimp', 'crab', 'lamb'],
      grain: ['rice', 'wheat', 'corn', 'oats', 'quinoa', 'barley'],
      dairy: ['milk', 'cheese', 'butter', 'yogurt', 'cream', 'coconut milk'],
      spice: ['salt', 'pepper', 'ginger', 'turmeric', 'cumin', 'paprika', 'chili'],
      condiment: ['soy sauce', 'vinegar', 'fish sauce', 'oyster sauce', 'ketchup'],
      oil: ['olive oil', 'vegetable oil', 'coconut oil', 'sesame oil']
    };

    const lowerName = name.toLowerCase();
    for (const [category, items] of Object.entries(categories)) {
      if (items.some(item => lowerName.includes(item))) {
        return category;
      }
    }

    return 'other';
  }

  calculateOverallConfidence(ingredients) {
    if (ingredients.length === 0) return 0;

    const avgConfidence = ingredients.reduce((sum, ing) => sum + ing.confidence, 0) / ingredients.length;
    return Math.round(avgConfidence * 100) / 100;
  }
}

module.exports = new IngredientDetectionService();
