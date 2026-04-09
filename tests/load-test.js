const http = require('http');

// Configuration
const GATEWAY_URL = process.env.GATEWAY_URL || 'localhost:8080';
const DURATION_SECONDS = parseInt(process.env.DURATION) || 60;
const REQUESTS_PER_SECOND = parseInt(process.env.RPS) || 10;

// Parse URL
const [host, port] = GATEWAY_URL.replace('http://', '').split(':');

// Statistics
let stats = {
  total: 0,
  success: 0,
  errors: 0,
  v1: 0,
  v2: 0,
  latencies: []
};

console.log('🚀 Starting load test...');
console.log(`Target: http://${GATEWAY_URL}`);
console.log(`Duration: ${DURATION_SECONDS}s`);
console.log(`Rate: ${REQUESTS_PER_SECOND} req/s`);
console.log('');

// Make a single request
function makeRequest() {
  return new Promise((resolve) => {
    const startTime = Date.now();
    
    const options = {
      hostname: host,
      port: port || 80,
      path: '/api/version',
      method: 'GET',
      timeout: 5000
    };

    const req = http.request(options, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        const latency = Date.now() - startTime;
        stats.latencies.push(latency);
        stats.total++;

        if (res.statusCode === 200) {
          stats.success++;
          try {
            const json = JSON.parse(data);
            if (json.version === 'v1.0.0') {
              stats.v1++;
            } else if (json.version === 'v2.0.0') {
              stats.v2++;
            }
          } catch (e) {
            // Ignore parse errors
          }
        } else {
          stats.errors++;
        }
        resolve();
      });
    });

    req.on('error', () => {
      stats.total++;
      stats.errors++;
      resolve();
    });

    req.on('timeout', () => {
      req.destroy();
      stats.total++;
      stats.errors++;
      resolve();
    });

    req.end();
  });
}

// Send requests at specified rate
async function runLoadTest() {
  const interval = 1000 / REQUESTS_PER_SECOND;
  const endTime = Date.now() + (DURATION_SECONDS * 1000);

  while (Date.now() < endTime) {
    const batchStart = Date.now();
    await makeRequest();
    
    // Wait for next interval
    const elapsed = Date.now() - batchStart;
    const waitTime = Math.max(0, interval - elapsed);
    await new Promise(resolve => setTimeout(resolve, waitTime));
  }
}

// Calculate statistics
function calculateStats() {
  const sortedLatencies = stats.latencies.sort((a, b) => a - b);
  const p50 = sortedLatencies[Math.floor(sortedLatencies.length * 0.5)];
  const p95 = sortedLatencies[Math.floor(sortedLatencies.length * 0.95)];
  const p99 = sortedLatencies[Math.floor(sortedLatencies.length * 0.99)];
  const avg = stats.latencies.reduce((a, b) => a + b, 0) / stats.latencies.length;

  return { p50, p95, p99, avg };
}

// Print results
function printResults() {
  console.log('\n📊 Load Test Results');
  console.log('='.repeat(50));
  console.log(`Total Requests:    ${stats.total}`);
  console.log(`Successful:        ${stats.success} (${((stats.success/stats.total)*100).toFixed(1)}%)`);
  console.log(`Errors:            ${stats.errors} (${((stats.errors/stats.total)*100).toFixed(1)}%)`);
  console.log('');
  console.log('Version Distribution:');
  console.log(`  v1:              ${stats.v1} (${((stats.v1/stats.success)*100).toFixed(1)}%)`);
  console.log(`  v2:              ${stats.v2} (${((stats.v2/stats.success)*100).toFixed(1)}%)`);
  console.log('');
  
  if (stats.latencies.length > 0) {
    const latencyStats = calculateStats();
    console.log('Latency (ms):');
    console.log(`  Average:         ${latencyStats.avg.toFixed(2)}`);
    console.log(`  p50:             ${latencyStats.p50}`);
    console.log(`  p95:             ${latencyStats.p95}`);
    console.log(`  p99:             ${latencyStats.p99}`);
  }
  console.log('='.repeat(50));
}

// Run the test
runLoadTest()
  .then(() => {
    printResults();
    process.exit(stats.errors > stats.total * 0.05 ? 1 : 0);
  })
  .catch((err) => {
    console.error('Error running load test:', err);
    process.exit(1);
  });

// Made with Bob
