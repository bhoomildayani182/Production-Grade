const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const { Pool } = require('pg');
const redis = require('redis');
const winston = require('winston');
require('dotenv').config();

// Initialize Express app
const app = express();
const PORT = process.env.PORT || 3000;

// Configure Winston logger
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: 'docker-swarm-backend' },
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' }),
    new winston.transports.Console({
      format: winston.format.simple()
    })
  ]
});

// Database configuration
const dbConfig = {
  host: process.env.DB_HOST || 'postgres',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'appdb',
  user: process.env.DB_USER || 'user',
  password: process.env.DB_PASSWORD || 'password',
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
};

// Initialize database pool
const pool = new Pool(dbConfig);

// Initialize Redis client
let redisClient;
try {
  redisClient = redis.createClient({
    host: process.env.REDIS_HOST || 'redis',
    port: process.env.REDIS_PORT || 6379,
    retry_strategy: (options) => {
      if (options.error && options.error.code === 'ECONNREFUSED') {
        logger.error('Redis server refused connection');
      }
      if (options.total_retry_time > 1000 * 60 * 60) {
        logger.error('Redis retry time exhausted');
        return new Error('Retry time exhausted');
      }
      if (options.attempt > 10) {
        return undefined;
      }
      return Math.min(options.attempt * 100, 3000);
    }
  });
} catch (error) {
  logger.error('Redis connection failed:', error);
}

// Middleware
app.use(helmet());
app.use(cors());
app.use(compression());
app.use(morgan('combined', { stream: { write: message => logger.info(message.trim()) } }));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.'
});
app.use(limiter);

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    // Check database connection
    await pool.query('SELECT 1');
    
    res.status(200).json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      service: 'docker-swarm-backend',
      version: '1.0.0',
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      database: 'connected'
    });
  } catch (error) {
    logger.error('Health check failed:', error);
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: error.message
    });
  }
});

// Database health check endpoint
app.get('/database/health', async (req, res) => {
  try {
    const result = await pool.query('SELECT NOW() as current_time');
    res.status(200).json({
      status: 'connected',
      timestamp: new Date().toISOString(),
      database_time: result.rows[0].current_time
    });
  } catch (error) {
    logger.error('Database health check failed:', error);
    res.status(503).json({
      status: 'disconnected',
      error: error.message
    });
  }
});

// Test endpoint
app.get('/test', (req, res) => {
  res.json({
    message: 'Docker Swarm Backend API is working!',
    timestamp: new Date().toISOString(),
    hostname: require('os').hostname(),
    environment: process.env.NODE_ENV || 'development',
    node_version: process.version,
    platform: process.platform
  });
});

// Users endpoint with sample data
app.get('/users', async (req, res) => {
  try {
    // Try to get from Redis cache first
    if (redisClient && redisClient.connected) {
      const cachedUsers = await redisClient.get('users');
      if (cachedUsers) {
        logger.info('Returning cached users');
        return res.json(JSON.parse(cachedUsers));
      }
    }

    // Sample users data
    const users = [
      {
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
        role: 'DevOps Engineer',
        created_at: new Date().toISOString()
      },
      {
        id: 2,
        name: 'Jane Smith',
        email: 'jane@example.com',
        role: 'Software Developer',
        created_at: new Date().toISOString()
      },
      {
        id: 3,
        name: 'Mike Johnson',
        email: 'mike@example.com',
        role: 'System Administrator',
        created_at: new Date().toISOString()
      }
    ];

    // Cache in Redis for 5 minutes
    if (redisClient && redisClient.connected) {
      await redisClient.setex('users', 300, JSON.stringify(users));
    }

    res.json({
      success: true,
      data: users,
      total: users.length,
      cached: false
    });
  } catch (error) {
    logger.error('Error fetching users:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error'
    });
  }
});

// Cluster info endpoint
app.get('/cluster/info', (req, res) => {
  res.json({
    cluster_name: 'docker-swarm-cluster',
    node_hostname: require('os').hostname(),
    node_type: 'worker', // This would be determined dynamically in a real scenario
    services_running: [
      'frontend',
      'backend',
      'postgres',
      'redis',
      'traefik'
    ],
    load_balancer: 'AWS ALB + Traefik',
    ssl_enabled: true,
    auto_scaling: true
  });
});

// Metrics endpoint
app.get('/metrics', (req, res) => {
  const metrics = {
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory_usage: process.memoryUsage(),
    cpu_usage: process.cpuUsage(),
    active_connections: pool.totalCount,
    idle_connections: pool.idleCount,
    waiting_connections: pool.waitingCount
  };

  res.json(metrics);
});

// Error handling middleware
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', err);
  res.status(500).json({
    success: false,
    error: 'Internal server error',
    timestamp: new Date().toISOString()
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: 'Endpoint not found',
    path: req.path,
    method: req.method
  });
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  
  server.close(() => {
    logger.info('Process terminated');
    pool.end();
    if (redisClient) {
      redisClient.quit();
    }
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  
  server.close(() => {
    logger.info('Process terminated');
    pool.end();
    if (redisClient) {
      redisClient.quit();
    }
    process.exit(0);
  });
});

// Start server
const server = app.listen(PORT, '0.0.0.0', () => {
  logger.info(`Server running on port ${PORT}`);
  logger.info(`Environment: ${process.env.NODE_ENV || 'development'}`);
  logger.info(`Node version: ${process.version}`);
});

module.exports = app;
