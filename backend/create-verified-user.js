require('dotenv').config();
const axios = require('axios');

const MOBILE_API_URL = 'http://192.168.194.185:3000/api';

async function createVerifiedUser() {
  console.log('👤 Creating Verified User for Mobile App Testing...\n');
  
  const testUser = {
    name: 'Mobile Test User',
    email: 'mobile@test.com',
    password: 'test123456'
  };
  
  try {
    // Step 1: Register user
    console.log('1. Registering user...');
    const registerResponse = await axios.post(`${MOBILE_API_URL}/auth/register`, testUser, {
      timeout: 10000,
      headers: { 'Content-Type': 'application/json' }
    });
    
    console.log(`   ✅ Registration response: ${registerResponse.data.message}`);
    
    // In development mode, the verification code is included in the response
    const verificationCode = registerResponse.data.verificationCode;
    if (verificationCode) {
      console.log(`   🔑 Verification code: ${verificationCode}`);
      
      // Step 2: Verify email
      console.log('\n2. Verifying email...');
      const verifyResponse = await axios.post(`${MOBILE_API_URL}/auth/verify-email`, {
        email: testUser.email,
        code: verificationCode
      }, {
        timeout: 10000,
        headers: { 'Content-Type': 'application/json' }
      });
      
      console.log(`   ✅ Verification response: ${verifyResponse.data.message}`);
      
      // Step 3: Login with verified user
      console.log('\n3. Testing login with verified user...');
      const loginResponse = await axios.post(`${MOBILE_API_URL}/auth/login`, {
        email: testUser.email,
        password: testUser.password
      }, {
        timeout: 10000,
        headers: { 'Content-Type': 'application/json' }
      });
      
      console.log(`   ✅ Login successful!`);
      console.log(`   👤 User: ${loginResponse.data.user.name}`);
      console.log(`   🔑 Token: ${loginResponse.data.token.substring(0, 30)}...`);
      
      // Step 4: Test scan endpoint
      console.log('\n4. Testing scan endpoint access...');
      const scanTestResponse = await axios.get(`${MOBILE_API_URL}/scan/test-huggingface`, {
        headers: {
          'Authorization': `Bearer ${loginResponse.data.token}`,
          'Content-Type': 'application/json'
        },
        timeout: 10000
      });
      
      console.log(`   ✅ Scan endpoint accessible!`);
      console.log(`   🤖 HuggingFace API: ${scanTestResponse.data.message}`);
      
      console.log('\n🎉 SUCCESS! Mobile app can now use these credentials:');
      console.log('=====================================');
      console.log(`📧 Email: ${testUser.email}`);
      console.log(`🔐 Password: ${testUser.password}`);
      console.log('🌐 Backend URL: http://192.168.194.175:3000/api');
      console.log('');
      console.log('✅ User is verified and ready for mobile app login!');
      console.log('✅ HuggingFace food scanning is working!');
      
    } else {
      console.log('   ⚠️ No verification code in response - check email or server logs');
    }
    
  } catch (error) {
    if (error.response?.status === 409) {
      console.log('   ℹ️ User already exists, trying to login directly...');
      
      // Try to login with existing user
      try {
        const loginResponse = await axios.post(`${MOBILE_API_URL}/auth/login`, {
          email: testUser.email,
          password: testUser.password
        }, {
          timeout: 10000,
          headers: { 'Content-Type': 'application/json' }
        });
        
        console.log('   ✅ Login successful with existing user!');
        console.log(`   👤 User: ${loginResponse.data.user.name}`);
        
        console.log('\n🎉 EXISTING USER READY! Mobile app can use:');
        console.log('=====================================');
        console.log(`📧 Email: ${testUser.email}`);
        console.log(`🔐 Password: ${testUser.password}`);
        console.log('🌐 Backend URL: http://192.168.194.175:3000/api');
        
      } catch (loginError) {
        console.log(`   ❌ Login failed: ${loginError.response?.data?.message || loginError.message}`);
        
        if (loginError.response?.data?.message?.includes('verify')) {
          console.log('\n📧 User exists but needs verification. Check server logs for verification code.');
        }
      }
    } else {
      console.log(`   ❌ Registration failed: ${error.response?.data?.message || error.message}`);
    }
  }
}

// Run the user creation
createVerifiedUser().catch(console.error);
