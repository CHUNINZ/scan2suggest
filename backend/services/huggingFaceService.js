const axios = require('axios');

class HuggingFaceService {
  constructor() {
    this.apiKey = process.env.HUGGINGFACE_API_KEY;
    this.apiUrl = 'https://api-inference.huggingface.co/models/nateraw/food';
    this.isConfigured = !!this.apiKey;
    
    if (!this.isConfigured) {
      console.error('❌ HUGGINGFACE_API_KEY not configured. Food detection will fail.');
    } else {
      console.log('✅ HuggingFace AI service initialized with API key');
    }
  }

  async analyzeFood(imageBuffer, scanType) {
    // Require API key - no fallbacks
    if (!this.isConfigured) {
      throw new Error('HuggingFace API key is required. Please configure HUGGINGFACE_API_KEY in environment variables.');
    }

    try {
      console.log(`🤖 Analyzing ${scanType} image with HuggingFace AI...`);
      
      const response = await axios({
        method: 'POST',
        url: this.apiUrl,
        headers: {
          'Authorization': `Bearer ${this.apiKey}`,
          'Content-Type': 'application/octet-stream'
        },
        data: imageBuffer,
        timeout: 30000 // 30 second timeout
      });

      console.log('🎯 Raw HuggingFace response:', JSON.stringify(response.data, null, 2));
      
      // Format the response to match our expected format
      const formattedItems = this.formatHuggingFaceResponse(response.data, scanType);
      
      console.log(`✅ HuggingFace detected ${formattedItems.length} items`);
      return formattedItems;
      
    } catch (error) {
      console.error('❌ HuggingFace API error:', error.message);
      console.error('❌ Full error stack:', error.stack);
      
      // Handle specific error cases
      if (error.response?.status === 503) {
        throw new Error('HuggingFace model is currently loading. Please try again in a few moments.');
      } else if (error.response?.status === 401) {
        throw new Error('Invalid HuggingFace API key. Please check your configuration.');
      } else if (error.response?.status === 429) {
        throw new Error('HuggingFace API rate limit exceeded. Please try again later.');
      }
      
      throw new Error(`HuggingFace API failed: ${error.message}`);
    }
  }

  formatHuggingFaceResponse(huggingFaceData, scanType) {
    console.log('🔍 Formatting HuggingFace response:', JSON.stringify(huggingFaceData, null, 2));
    
    if (!huggingFaceData || !Array.isArray(huggingFaceData)) {
      console.warn('⚠️ Invalid HuggingFace response format');
      return [];
    }

    // HuggingFace returns an array of predictions with label and score
    const formattedItems = huggingFaceData
      .filter(item => item.score > 0.1) // Filter out low confidence predictions
      .map((item, index) => ({
        name: this.formatFoodName(item.label || 'Unknown Food'),
        confidence: Math.round(item.score * 100) / 100,
        category: this.categorizeFood(item.label || 'food'),
        boundingBox: {
          x: 50 + (index * 20), // Spread items across image
          y: 50 + (index * 15),
          width: 150,
          height: 100
        }
      }))
      .slice(0, 5); // Limit to top 5 predictions
    
    console.log('✨ Formatted HuggingFace predictions:', formattedItems);
    
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
      'steamed_fish': 'Steamed Fish'
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
      'steamed_fish': 'dish'
    };
    
    const cleanName = className.toLowerCase().replace(/[_-]/g, '_');
    return categories[cleanName] || 'food';
  }

  // Test method to verify API connectivity
  async testConnection() {
    if (!this.isConfigured) {
      return { success: false, message: 'HuggingFace API key not configured' };
    }

    try {
      // Test with a simple HTTP request to check authentication
      const response = await axios({
        method: 'GET',
        url: 'https://huggingface.co/api/whoami-v2',
        headers: {
          'Authorization': `Bearer ${this.apiKey}`
        },
        timeout: 10000
      });

      return { 
        success: true, 
        message: 'HuggingFace API connected successfully',
        response: { authenticated: true, user: response.data?.name || 'API User' }
      };
    } catch (error) {
      if (error.response?.status === 401) {
        return { 
          success: false, 
          message: 'HuggingFace API authentication failed - invalid API key' 
        };
      }
      return { 
        success: false, 
        message: `HuggingFace API connection failed: ${error.message}` 
      };
    }
  }
}

module.exports = new HuggingFaceService();
