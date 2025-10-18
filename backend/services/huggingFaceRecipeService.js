const axios = require('axios');

class HuggingFaceRecipeService {
  constructor() {
    this.apiKey = process.env.HUGGINGFACE_API_KEY || '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';
    // Using Microsoft's Phi-2 - small but capable model, publicly accessible
    this.apiUrl = 'https://api-inference.huggingface.co/models/microsoft/phi-2';
    
    if (!this.apiKey) {
      console.error('❌ HUGGINGFACE_API_KEY not configured.');
    } else {
      console.log('✅ HuggingFace Recipe service initialized with Phi-2');
    }
  }

  async getRecipeForFood(foodName) {
    if (!this.apiKey) {
      throw new Error('HuggingFace API key is not set.');
    }

    const prompt = `Generate a detailed recipe for ${foodName}.

Format your response exactly like this:

Ingredients:
- [list each ingredient with measurements]

Instructions:
1. [First step]
2. [Second step]
3. [Continue with all steps]

Now provide the recipe for ${foodName}:`;

    try {
      console.log(`🤖 Getting recipe for "${foodName}" from HuggingFace...`);
      
      const response = await axios.post(
        this.apiUrl,
        {
          inputs: prompt,
          parameters: {
            max_new_tokens: 800,
            temperature: 0.7,
            top_p: 0.95,
            return_full_text: false
          }
        },
        {
          headers: {
            'Authorization': `Bearer ${this.apiKey}`,
            'Content-Type': 'application/json'
          },
          timeout: 30000
        }
      );

      console.log('✅ HuggingFace recipe received');
      
      // Format the response to match Gemini's structure for compatibility
      if (response.data && Array.isArray(response.data) && response.data[0]) {
        const generatedText = response.data[0].generated_text || '';
        
        return {
          candidates: [{
            content: {
              parts: [{
                text: generatedText
              }]
            }
          }]
        };
      }

      throw new Error('Invalid response from HuggingFace');
      
    } catch (error) {
      console.error('❌ HuggingFace API error:', error?.response?.data || error.message);
      
      // Handle specific error cases
      if (error.response?.status === 503) {
        throw new Error('HuggingFace model is loading. Please try again in a few moments.');
      } else if (error.response?.status === 401) {
        throw new Error('Invalid HuggingFace API key.');
      } else if (error.response?.status === 429) {
        throw new Error('Rate limit exceeded. Please try again later.');
      }
      
      throw error;
    }
  }
}

module.exports = new HuggingFaceRecipeService();

