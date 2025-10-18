require('dotenv').config();
const axios = require('axios');
const FormData = require('form-data');

async function debugLogMeal() {
  const apiKey = process.env.LOGMEAL_API_KEY;
  console.log('🔍 Debugging LogMeal API authentication...');
  console.log('🔑 API Key length:', apiKey ? apiKey.length : 0);
  console.log('🔑 API Key prefix:', apiKey ? apiKey.substring(0, 8) + '...' : 'N/A');

  // Test different base URLs and auth methods
  const testConfigs = [
    { url: 'https://api.logmeal.com/v2/image/recognition/type', auth: `Bearer ${apiKey}` },
    { url: 'https://api.logmeal.es/v2/image/recognition/type', auth: `Bearer ${apiKey}` },
    { url: 'https://api.logmeal.com/v2/image/recognition/type', auth: `Token ${apiKey}` },
    { url: 'https://api.logmeal.es/v2/image/recognition/type', auth: `Token ${apiKey}` },
    { url: 'https://api.logmeal.com/image/recognition/type', auth: `Bearer ${apiKey}` },
    { url: 'https://api.logmeal.es/image/recognition/type', auth: `Bearer ${apiKey}` }
  ];

  const testImageBuffer = Buffer.from('/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsjHBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCdABmX/9k=', 'base64');

  for (let i = 0; i < testConfigs.length; i++) {
    const config = testConfigs[i];
    console.log(`\n📡 Test ${i + 1}: ${config.url}`);
    console.log(`🔐 Auth: ${config.auth.split(' ')[0]} ${config.auth.split(' ')[1].substring(0, 8)}...`);

    try {
      const formData = new FormData();
      formData.append('image', testImageBuffer, {
        filename: 'test.jpg',
        contentType: 'image/jpeg'
      });

      const response = await axios({
        method: 'POST',
        url: config.url,
        headers: {
          'Authorization': config.auth,
          ...formData.getHeaders()
        },
        data: formData,
        timeout: 15000
      });

      console.log('✅ SUCCESS!');
      console.log('📊 Status:', response.status);
      console.log('📊 Response keys:', Object.keys(response.data));
      return { success: true, config, data: response.data };

    } catch (error) {
      console.log('❌ FAILED');
      console.log('📊 Status:', error.response?.status);
      console.log('📊 Error:', error.response?.data?.message || error.message);
    }
  }

  console.log('\n❌ All authentication methods failed');
  return { success: false };
}

debugLogMeal();
