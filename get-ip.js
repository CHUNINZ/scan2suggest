#!/usr/bin/env node

const os = require('os');

function getCurrentIP() {
  const networkInterfaces = os.networkInterfaces();
  const ips = [];
  
  Object.keys(networkInterfaces).forEach((interfaceName) => {
    const interfaces = networkInterfaces[interfaceName];
    interfaces.forEach((interface) => {
      if (interface.family === 'IPv4' && !interface.internal) {
        ips.push({
          interface: interfaceName,
          ip: interface.address,
          url: `http://${interface.address}:3000/api`
        });
      }
    });
  });
  
  return ips;
}

console.log('📡 Current Network IP Addresses:');
console.log('================================');

const ips = getCurrentIP();
if (ips.length === 0) {
  console.log('❌ No external network interfaces found');
} else {
  ips.forEach((item, index) => {
    console.log(`${index + 1}. ${item.interface}: ${item.ip}`);
    console.log(`   API URL: ${item.url}`);
    console.log('');
  });
  
  console.log('💡 Update your mobile app config with any of the above URLs');
  console.log('📱 Current mobile app config should use:', ips[0].url);
}
