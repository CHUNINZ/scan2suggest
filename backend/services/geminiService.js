const axios = require('axios');

class GeminiService {
  constructor() {
    this.apiKey = process.env.GEMINI_API_KEY;
    // Use the available model for this API key
    this.apiUrl = 'https://generativelanguage.googleapis.com/v1/models/gemini-2.5-pro:generateContent';
    if (!this.apiKey) {
      console.error('❌ GEMINI_API_KEY not configured.');
    }
  }

  async getRecipeForFood(foodName) {
    if (!this.apiKey) throw new Error('Gemini API key is not set.');
    const prompt = `Give me the ingredients (as a list) and step-by-step instructions on how to cook "${foodName}". Format with a heading "Ingredients", then a bullet-point list, then a heading "Instructions", then a numbered list.`;
    const body = {
      contents: [{parts: [{text: prompt}]}],
    };
    try {
      const response = await axios.post(
        this.apiUrl,
        body,
        { params: { key: this.apiKey } }
      );
      return response.data;
    } catch (error) {
      console.error('❌ Gemini API error:', error?.response?.data || error.message);
      throw error;
    }
  }
}

module.exports = new GeminiService();
