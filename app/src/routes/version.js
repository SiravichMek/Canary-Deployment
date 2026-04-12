const express = require('express');
const router = express.Router();
const os = require('os');

// Get version information
router.get('/api/version', (req, res) => {
  const version = process.env.APP_VERSION || 'unknown';
  const color = process.env.APP_COLOR || '#3498db';
  const feature = process.env.APP_FEATURE || 'Standard';

  res.json({
    version,
    color,
    feature,
    hostname: os.hostname(),
    platform: os.platform(),
    nodeVersion: process.version,
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'development'
  });
});

// Root endpoint with visual version display
router.get('/', (req, res) => {
  const version = process.env.APP_VERSION || 'unknown';
  const color = process.env.APP_COLOR || '#3498db';
  const feature = process.env.APP_FEATURE || 'Standard';
  const hostname = os.hostname();

  const html = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Canary Demo - newest version!!!!</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, ${color} 0%, ${adjustColor(color, -30)} 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            color: white;
        }
        .container {
            text-align: center;
            padding: 40px;
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
            border: 1px solid rgba(255, 255, 255, 0.18);
            max-width: 600px;
            width: 90%;
        }
        h1 {
            font-size: 3em;
            margin-bottom: 20px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        .version {
            font-size: 2em;
            font-weight: bold;
            margin: 20px 0;
            padding: 15px 30px;
            background: rgba(255, 255, 255, 0.2);
            border-radius: 10px;
            display: inline-block;
        }
        .info {
            margin: 15px 0;
            font-size: 1.1em;
            opacity: 0.9;
        }
        .feature {
            margin-top: 20px;
            padding: 10px 20px;
            background: rgba(255, 255, 255, 0.15);
            border-radius: 8px;
            font-size: 1.2em;
        }
        .hostname {
            margin-top: 15px;
            font-size: 0.9em;
            opacity: 0.7;
            font-family: monospace;
        }
        .badge {
            display: inline-block;
            padding: 5px 15px;
            background: rgba(255, 255, 255, 0.3);
            border-radius: 20px;
            margin: 5px;
            font-size: 0.9em;
        }
        @keyframes pulse {
            0%, 100% { transform: scale(1); }
            50% { transform: scale(1.05); }
        }
        .version {
            animation: pulse 2s infinite;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Canary Deployment Demo</h1>
        <div class="version">Version ${version}</div>
        <div class="feature">✨ ${feature}</div>
        <div class="info">
            <div class="badge">Pod: ${hostname}</div>
            <div class="badge">Node: ${process.version}</div>
        </div>
        <div class="hostname">Served by: ${hostname}</div>
        <div class="info" style="margin-top: 30px; font-size: 0.9em;">
            Refresh the page to see load balancing in action!
        </div>
    </div>
</body>
</html>
  `;

  res.send(html);
});

// Simulate slow response (for testing)
router.get('/api/slow', async (req, res) => {
  const delay = parseInt(req.query.delay) || 1000;
  const version = process.env.APP_VERSION || 'unknown';

  await new Promise(resolve => setTimeout(resolve, delay));

  res.json({
    message: 'Slow response completed',
    version,
    delay,
    timestamp: new Date().toISOString()
  });
});

// Simulate error (for testing rollback)
router.get('/api/error', (req, res) => {
  const errorRate = parseFloat(process.env.ERROR_RATE) || 0;
  const shouldError = Math.random() < errorRate;

  if (shouldError) {
    res.status(500).json({
      error: 'Simulated error',
      version: process.env.APP_VERSION || 'unknown',
      timestamp: new Date().toISOString()
    });
  } else {
    res.json({
      message: 'Success',
      version: process.env.APP_VERSION || 'unknown',
      timestamp: new Date().toISOString()
    });
  }
});

// Helper function to adjust color brightness
function adjustColor(color, amount) {
  const clamp = (num) => Math.min(Math.max(num, 0), 255);
  const num = parseInt(color.replace('#', ''), 16);
  const r = clamp((num >> 16) + amount);
  const g = clamp(((num >> 8) & 0x00FF) + amount);
  const b = clamp((num & 0x0000FF) + amount);
  return '#' + ((r << 16) | (g << 8) | b).toString(16).padStart(6, '0');
}

module.exports = router;

// Made with Bob
