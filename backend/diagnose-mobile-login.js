require('dotenv').config();
const axios = require('axios');

const MOBILE_API_URL = 'http://192.168.194.175:3000/api';

async function diagnoseMobileLogin() {
  console.log('🔍 Diagnosing Mobile App Login Issues...\n');
  
  // Test 1: Basic server connectivity
  console.log('1. Testing basic server connectivity...');
  try {
    const healthResponse = await axios.get(`${MOBILE_API_URL}/health`, { timeout: 5000 });
    console.log(`   ✅ Server reachable: ${healthResponse.data.message}`);
  } catch (error) {
    console.log(`   ❌ Server unreachable: ${error.message}`);
    return;
  }
  
  // Test 2: Database connection check
  console.log('\n2. Testing database connection...');
  try {
    // Try a simple auth request to see if it times out
    const testLogin = axios.post(`${MOBILE_API_URL}/auth/login`, {
      email: 'test@example.com',
      password: 'wrongpassword'
    }, { timeout: 10000 });
    
    const response = await testLogin;
    console.log(`   ✅ Database connected - got response: ${response.data.message}`);
  } catch (error) {
    if (error.code === 'ECONNABORTED') {
      console.log('   ❌ Database connection timeout - MongoDB is likely not running');
      console.log('   💡 This is why your mobile app login is stuck loading!');
    } else if (error.response) {
      console.log(`   ✅ Database connected - got error response: ${error.response.data.message}`);
    } else {
      console.log(`   ❌ Database connection error: ${error.message}`);
    }
  }
  
  // Test 3: Check MongoDB process
  console.log('\n3. Checking MongoDB status...');
  const mongoose = require('mongoose');
  try {
    await mongoose.connect(process.env.MONGODB_URI, { 
      serverSelectionTimeoutMS: 5000,
      connectTimeoutMS: 5000 
    });
    console.log('   ✅ MongoDB is running and accessible');
    await mongoose.disconnect();
  } catch (error) {
    console.log('   ❌ MongoDB connection failed:', error.message);
    console.log('   💡 This confirms MongoDB is not running');
  }
  
  // Test 4: Network interface check
  console.log('\n4. Checking network interfaces...');
  const networkInterfaces = require('os').networkInterfaces();
  let foundCorrectIP = false;
  
  for (const name of Object.keys(networkInterfaces)) {
    for (const net of networkInterfaces[name]) {
      if (net.family === 'IPv4' && !net.internal) {
        console.log(`   📡 Available IP: ${net.address}`);
        if (net.address === '192.168.194.175') {
          foundCorrectIP = true;
          console.log('   ✅ Mobile app IP configuration matches!');
        }
      }
    }
  }
  
  if (!foundCorrectIP) {
    console.log('   ⚠️ Mobile app IP (192.168.194.175) not found in current network interfaces');
  }
  
  // Test 5: CORS and headers check
  console.log('\n5. Testing CORS and headers...');
  try {
    const response = await axios.options(`${MOBILE_API_URL}/auth/login`);
    console.log('   ✅ CORS preflight successful');
  } catch (error) {
    console.log(`   ⚠️ CORS preflight issue: ${error.message}`);
  }
  
  console.log('\n📋 DIAGNOSIS SUMMARY:');
  console.log('=====================================');
  
  // Check if MongoDB is the issue
  try {
    await mongoose.connect(process.env.MONGODB_URI, { 
      serverSelectionTimeoutMS: 2000 
    });
    console.log('✅ Backend server: Running');
    console.log('✅ Network connectivity: Working');
    console.log('✅ MongoDB database: Connected');
    console.log('✅ Mobile app should work now!');
    await mongoose.disconnect();
  } catch (error) {
    console.log('✅ Backend server: Running');
    console.log('✅ Network connectivity: Working');
    console.log('❌ MongoDB database: NOT RUNNING');
    console.log('');
    console.log('🔧 SOLUTION:');
    console.log('Your mobile app login is stuck because MongoDB is not running.');
    console.log('Start MongoDB with one of these commands:');
    console.log('');
    console.log('Option 1: brew services start mongodb-community');
    console.log('Option 2: mongod');
    console.log('Option 3: docker run -d -p 27017:27017 mongo');
    console.log('');
    console.log('After starting MongoDB, your mobile app login will work!');
  }
}

// Run diagnosis
diagnoseMobileLogin().catch(console.error);
