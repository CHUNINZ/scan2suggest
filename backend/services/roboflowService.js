const axios = require('axios');

class RoboflowService {
  constructor() {
    this.apiKey = process.env.ROBOFLOW_API_KEY || 'Wh2lwtFofEq4R0pgNmiw';
    this.apiUrl = 'https://serverless.roboflow.com/filipino-food-datasets-kd7d6/1';
    this.isConfigured = !!this.apiKey;
    
    if (!this.isConfigured) {
      console.error('❌ ROBOFLOW_API_KEY not configured. Food detection will fail.');
    } else {
      console.log('✅ Roboflow AI service initialized with API key');
    }
  }

  async analyzeFood(imageBuffer, scanType) {
    // Use Roboflow API, send base64 buffer in body, api_key as url param
    try {
      const base64Image = imageBuffer.toString('base64');
      console.log('[Roboflow] (base64 POST) Sending image to Roboflow API, length:', base64Image.length);
      const response = await axios({
        method: 'POST',
        url: 'https://serverless.roboflow.com/filipino-food-datasets-kd7d6/1',
        params: {
          api_key: 'Wh2lwtFofEq4R0pgNmiw'
        },
        data: base64Image,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        }
      });
      return this.formatRoboflowResponse(response.data, scanType);
    } catch (error) {
      console.error('❌ Roboflow API error (base64 POST):', error.message);
      throw new Error(`Roboflow API failed: ${error.message}`);
    }
  }

  formatRoboflowResponse(roboflowData, scanType) {
    console.log('🔍 Formatting Roboflow response:', JSON.stringify(roboflowData, null, 2));
    
    if (!roboflowData || !roboflowData.predictions || !Array.isArray(roboflowData.predictions)) {
      console.warn('⚠️ Invalid Roboflow response format');
      return [];
    }

    // Roboflow returns predictions with class, confidence, and bounding box info
    const formattedItems = roboflowData.predictions
      .filter(item => item.confidence > 0.1) // Filter out low confidence predictions
      .map((item) => ({
        name: this.formatFoodName(item.class || 'Unknown Food'),
        confidence: Math.round(item.confidence * 100) / 100,
        category: this.categorizeFood(item.class || 'food'),
        boundingBox: {
          x: item.x || 0,
          y: item.y || 0,
          width: item.width || 150,
          height: item.height || 100
        }
      }))
      .slice(0, 5); // Limit to top 5 predictions
    
    console.log('✨ Formatted Roboflow predictions:', formattedItems);
    
    return formattedItems;
  }

  formatFoodName(className) {
    // Convert class names to user-friendly format
    const nameMap = {
      'adobo': 'Chicken Adobo',
      'lechon': 'Lechon',
      'sinigang': 'Sinigang',
      'lumpia': 'Lumpia',
      'pancit': 'Pancit',
      'rice': 'Rice',
      'kare_kare': 'Kare-Kare',
      'kare-kare': 'Kare-Kare',
      'sisig': 'Sisig',
      'bicol_express': 'Bicol Express',
      'bicol-express': 'Bicol Express',
      'dinuguan': 'Dinuguan',
      'fried_rice': 'Fried Rice',
      'chicken_curry': 'Chicken Curry',
      'beef_stew': 'Beef Stew',
      'pork_chop': 'Pork Chop',
      'fish_fillet': 'Fish Fillet',
      'vegetable_salad': 'Vegetable Salad',
      'noodle_soup': 'Noodle Soup',
      'grilled_chicken': 'Grilled Chicken',
      'steamed_fish': 'Steamed Fish',
      'tomato': 'Tomato',
      'onion': 'Onion',
      'garlic': 'Garlic',
      'carrot': 'Carrot',
      'potato': 'Potato',
      'cabbage': 'Cabbage',
      'lettuce': 'Lettuce',
      'spinach': 'Spinach',
      'broccoli': 'Broccoli',
      'apple': 'Apple',
      'banana': 'Banana',
      'orange': 'Orange',
      'mango': 'Mango',
      'pineapple': 'Pineapple',
      'coconut': 'Coconut',
      'lemon': 'Lemon',
      'lime': 'Lime',
      'chicken': 'Chicken',
      'pork': 'Pork',
      'beef': 'Beef',
      'fish': 'Fish',
      'shrimp': 'Shrimp',
      'crab': 'Crab'
    };
    
    const cleanName = className.toLowerCase().replace(/[_-]/g, '_');
    return nameMap[cleanName] || this.capitalizeWords(className);
  }

  capitalizeWords(str) {
    return str.replace(/\b\w/g, l => l.toUpperCase()).replace(/[_-]/g, ' ');
  }

  categorizeFood(className) {
    const categories = {
      'adobo': 'dish',
      'lechon': 'dish', 
      'sinigang': 'dish',
      'lumpia': 'dish',
      'pancit': 'dish',
      'rice': 'food',
      'kare_kare': 'dish',
      'kare-kare': 'dish',
      'sisig': 'dish',
      'bicol_express': 'dish',
      'bicol-express': 'dish',
      'dinuguan': 'dish',
      'fried_rice': 'dish',
      'chicken_curry': 'dish',
      'beef_stew': 'dish',
      'pork_chop': 'dish',
      'fish_fillet': 'dish',
      'vegetable_salad': 'dish',
      'noodle_soup': 'dish',
      'grilled_chicken': 'dish',
      'steamed_fish': 'dish',
      'tomato': 'vegetable',
      'onion': 'vegetable',
      'garlic': 'vegetable',
      'carrot': 'vegetable',
      'potato': 'vegetable',
      'cabbage': 'vegetable',
      'lettuce': 'vegetable',
      'spinach': 'vegetable',
      'broccoli': 'vegetable',
      'apple': 'fruit',
      'banana': 'fruit',
      'orange': 'fruit',
      'mango': 'fruit',
      'pineapple': 'fruit',
      'coconut': 'fruit',
      'lemon': 'fruit',
      'lime': 'fruit',
      'chicken': 'meat',
      'pork': 'meat',
      'beef': 'meat',
      'fish': 'meat',
      'shrimp': 'meat',
      'crab': 'meat'
    };
    
    const cleanName = className.toLowerCase().replace(/[_-]/g, '_');
    return categories[cleanName] || 'food';
  }

  // Test method to verify API connectivity
  async testConnection() {
    if (!this.isConfigured) {
      return { success: false, message: 'Roboflow API key not configured' };
    }

    try {
      // Test with a request using a tiny placeholder image URL
      const testImageUrl = 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a3/June_odd-eyed-cat.jpg/320px-June_odd-eyed-cat.jpg';

      const response = await axios({
        method: 'POST',
        url: this.apiUrl,
        params: {
          api_key: this.apiKey,
          image: testImageUrl
        },
        timeout: 10000
      });

      return { 
        success: true, 
        message: 'Roboflow API connected successfully',
        response: { authenticated: true, predictions: response.data?.predictions?.length || 0 }
      };
    } catch (error) {
      if (error.response?.status === 401) {
        return { 
          success: false, 
          message: 'Roboflow API authentication failed - invalid API key' 
        };
      }
      return { 
        success: false, 
        message: `Roboflow API connection failed: ${error.message}` 
      };
    }
  }
}

module.exports = new RoboflowService();
