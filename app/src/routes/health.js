const express = require('express');
const router = express.Router();

// Liveness probe - checks if the application is running
router.get('/health/live', (req, res) => {
  res.status(200).json({
    status: 'UP',
    timestamp: new Date().toISOString(),
    checks: {
      liveness: 'OK'
    }
  });
});

// Readiness probe - checks if the application is ready to serve traffic
router.get('/health/ready', (req, res) => {
  // In a real application, you would check database connections, etc.
  const isReady = true;

  if (isReady) {
    res.status(200).json({
      status: 'UP',
      timestamp: new Date().toISOString(),
      checks: {
        readiness: 'OK',
        database: 'OK',
        dependencies: 'OK'
      }
    });
  } else {
    res.status(503).json({
      status: 'DOWN',
      timestamp: new Date().toISOString(),
      checks: {
        readiness: 'FAILED'
      }
    });
  }
});

// Startup probe - checks if the application has started successfully
router.get('/health/startup', (req, res) => {
  res.status(200).json({
    status: 'UP',
    timestamp: new Date().toISOString(),
    checks: {
      startup: 'OK'
    }
  });
});

// Combined health check
router.get('/health', (req, res) => {
  res.status(200).json({
    status: 'UP',
    timestamp: new Date().toISOString(),
    version: process.env.APP_VERSION || 'unknown',
    hostname: process.env.HOSTNAME || 'unknown',
    uptime: process.uptime(),
    memory: {
      used: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
      total: Math.round(process.memoryUsage().heapTotal / 1024 / 1024),
      unit: 'MB'
    }
  });
});

module.exports = router;

// Made with Bob
