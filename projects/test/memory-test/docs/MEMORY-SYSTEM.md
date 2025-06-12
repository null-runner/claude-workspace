# Memory System Documentation

**Language:** [🇺🇸 English](MEMORY-SYSTEM.md) | [🇮🇹 Italiano](MEMORY-SYSTEM_IT.md)

## Overview

The Memory System is a core component of Claude Workspace that provides advanced context management for long-running conversations with Claude AI. It enables persistent conversation history, intelligent context compression, and efficient retrieval of relevant information across sessions.

## Architecture

### 1. System Components

```
Memory System
├── Context Manager      # Manages conversation contexts
├── Storage Engine      # Handles data persistence
├── Compression Module  # Optimizes context size
├── Retrieval System   # Enables context search
└── Security Layer     # Ensures data protection
```

### 2. Data Flow

```
User Input → Context Manager → Storage Engine → Memory Database
                ↓
Claude Response ← Context Retrieval ← Compression Module
```

## Core Features

### 1. Persistent Context Storage

The memory system automatically saves conversation context across sessions:

```javascript
const memorySystem = new MemorySystem({
  maxContextLength: 100000,
  compressionEnabled: true,
  persistenceMode: 'automatic'
});

// Context is automatically saved after each interaction
await memorySystem.processConversation({
  sessionId: 'project-123',
  messages: [
    { role: 'user', content: 'Help me debug this JavaScript function' },
    { role: 'assistant', content: 'I\'d be happy to help...' }
  ]
});
```

### 2. Intelligent Context Compression

When context exceeds limits, the system intelligently compresses older content:

```javascript
const compressionStrategies = {
  // Summarize older messages
  summarization: {
    threshold: 50000, // characters
    ratio: 0.3, // compress to 30% of original
    preserveRecent: 10 // keep last 10 messages unchanged
  },
  
  // Remove redundant information
  deduplication: {
    enabled: true,
    similarityThreshold: 0.8
  },
  
  // Prioritize important content
  importance: {
    codeBlocks: 'high',
    errors: 'high',
    solutions: 'medium',
    general: 'low'
  }
};
```

### 3. Context Retrieval and Search

Retrieve relevant context from previous conversations:

```javascript
// Find related conversations
const relevantContext = await memorySystem.searchContext({
  query: 'JavaScript debugging',
  maxResults: 5,
  timeRange: '30d' // last 30 days
});

// Get full session history
const sessionHistory = await memorySystem.getSession('project-123');

// Search by keywords
const keywordResults = await memorySystem.searchByKeywords([
  'function', 'error', 'debugging'
]);
```

## Implementation Guide

### 1. Basic Setup

```javascript
import { MemorySystem } from 'claude-workspace';

const memory = new MemorySystem({
  // Storage configuration
  storage: {
    type: 'sqlite', // or 'postgresql', 'mongodb'
    path: './data/memory.db',
    encryption: true
  },
  
  // Context limits
  limits: {
    maxContextLength: 100000,
    maxSessions: 1000,
    retentionDays: 90
  },
  
  // Compression settings
  compression: {
    enabled: true,
    threshold: 50000,
    strategy: 'intelligent'
  }
});

await memory.initialize();
```

### 2. Session Management

```javascript
class ConversationManager {
  constructor(memorySystem) {
    this.memory = memorySystem;
  }
  
  async startSession(sessionId, metadata = {}) {
    await this.memory.createSession({
      id: sessionId,
      timestamp: Date.now(),
      metadata: {
        project: metadata.project,
        user: metadata.user,
        tags: metadata.tags || []
      }
    });
  }
  
  async addMessage(sessionId, message) {
    await this.memory.appendMessage(sessionId, {
      ...message,
      timestamp: Date.now(),
      id: this.generateMessageId()
    });
  }
  
  async getContext(sessionId, options = {}) {
    return await this.memory.getContext(sessionId, {
      includeMetadata: options.includeMetadata || false,
      maxLength: options.maxLength || 50000,
      format: options.format || 'chronological'
    });
  }
}
```

### 3. Advanced Context Management

```javascript
// Custom context processing
const contextProcessor = {
  async preprocessContext(context) {
    // Remove sensitive information
    context = this.sanitizeContext(context);
    
    // Enhance with metadata
    context = await this.addMetadata(context);
    
    // Apply user preferences
    context = this.applyUserPreferences(context);
    
    return context;
  },
  
  async postprocessContext(context) {
    // Add cross-references
    context = await this.addCrossReferences(context);
    
    // Update relevance scores
    context = this.updateRelevanceScores(context);
    
    return context;
  }
};
```

## Storage Options

### 1. SQLite (Default)

**Pros:**
- No external dependencies
- Fast for single-user scenarios
- File-based storage

**Configuration:**
```javascript
const sqliteConfig = {
  type: 'sqlite',
  path: './data/memory.db',
  options: {
    journal_mode: 'WAL',
    synchronous: 'NORMAL',
    cache_size: 10000
  }
};
```

### 2. PostgreSQL

**Pros:**
- Excellent for multi-user environments
- Advanced querying capabilities
- Strong consistency

**Configuration:**
```javascript
const postgresConfig = {
  type: 'postgresql',
  connection: {
    host: 'localhost',
    port: 5432,
    database: 'claude_workspace',
    user: 'workspace_user',
    password: process.env.DB_PASSWORD
  },
  pool: {
    min: 2,
    max: 10
  }
};
```

### 3. MongoDB

**Pros:**
- Flexible document structure
- Natural JSON storage
- Horizontal scaling

**Configuration:**
```javascript
const mongoConfig = {
  type: 'mongodb',
  connection: 'mongodb://localhost:27017/claude_workspace',
  options: {
    useUnifiedTopology: true,
    maxPoolSize: 10
  }
};
```

## Memory Optimization

### 1. Context Compression Strategies

**Hierarchical Compression:**
```javascript
const hierarchicalCompression = {
  levels: [
    {
      age: '1d',
      compression: 'none',
      priority: 'high'
    },
    {
      age: '7d',
      compression: 'light',
      priority: 'medium'
    },
    {
      age: '30d',
      compression: 'aggressive',
      priority: 'low'
    }
  ]
};
```

**Semantic Compression:**
```javascript
const semanticCompression = {
  preserveStructure: true,
  keywordExtraction: true,
  topicModeling: true,
  summaryGeneration: {
    maxLength: 500,
    style: 'technical',
    preserveCode: true
  }
};
```

### 2. Performance Optimization

**Indexing Strategy:**
```sql
-- Optimize for common queries
CREATE INDEX idx_session_timestamp ON conversations(session_id, timestamp);
CREATE INDEX idx_content_search ON conversations USING gin(to_tsvector('english', content));
CREATE INDEX idx_metadata ON conversations USING gin(metadata);
```

**Caching Layer:**
```javascript
const cacheConfig = {
  type: 'redis',
  ttl: 3600, // 1 hour
  maxSize: '100MB',
  strategies: {
    context: 'lru',
    search: 'lfu',
    metadata: 'ttl'
  }
};
```

## Search and Retrieval

### 1. Full-Text Search

```javascript
const searchOptions = {
  // Text search
  query: 'debug JavaScript function',
  
  // Filters
  filters: {
    sessionId: 'project-123',
    dateRange: {
      start: '2024-01-01',
      end: '2024-12-31'
    },
    tags: ['debugging', 'javascript']
  },
  
  // Ranking
  ranking: {
    recency: 0.3,
    relevance: 0.5,
    importance: 0.2
  },
  
  // Results
  limit: 10,
  offset: 0,
  includeContext: true
};

const results = await memory.search(searchOptions);
```

### 2. Semantic Search

```javascript
// Vector-based semantic search
const semanticSearch = await memory.searchSemantic({
  query: 'How to fix async/await issues?',
  model: 'text-embedding-ada-002',
  threshold: 0.8,
  maxResults: 5
});

// Similar conversation finder
const similarConversations = await memory.findSimilar({
  sessionId: 'current-session',
  method: 'cosine_similarity',
  threshold: 0.7
});
```

## Security and Privacy

### 1. Data Encryption

```javascript
const securityConfig = {
  encryption: {
    algorithm: 'aes-256-gcm',
    keyRotation: '30d',
    fieldLevel: true // encrypt sensitive fields only
  },
  
  access: {
    authentication: true,
    authorization: 'rbac',
    sessionTimeout: 3600
  },
  
  audit: {
    enabled: true,
    logLevel: 'info',
    retentionDays: 365
  }
};
```

### 2. Data Sanitization

```javascript
const dataSanitizer = {
  sanitizeBeforeStorage(content) {
    // Remove PII patterns
    const patterns = [
      /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/g, // emails
      /\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/g, // credit cards
      /\b\d{3}-\d{2}-\d{4}\b/g, // SSN
    ];
    
    patterns.forEach(pattern => {
      content = content.replace(pattern, '[REDACTED]');
    });
    
    return content;
  }
};
```

## Monitoring and Analytics

### 1. Performance Metrics

```javascript
const metricsCollector = {
  async collectMetrics() {
    return {
      storage: {
        totalSessions: await this.countSessions(),
        totalMessages: await this.countMessages(),
        storageSize: await this.getStorageSize(),
        avgSessionLength: await this.getAvgSessionLength()
      },
      
      performance: {
        avgQueryTime: await this.getAvgQueryTime(),
        compressionRatio: await this.getCompressionRatio(),
        cacheHitRate: await this.getCacheHitRate()
      },
      
      usage: {
        activeUsers: await this.getActiveUsers(),
        dailyQueries: await this.getDailyQueries(),
        popularTopics: await this.getPopularTopics()
      }
    };
  }
};
```

### 2. Health Monitoring

```javascript
const healthMonitor = {
  async checkHealth() {
    const checks = await Promise.all([
      this.checkDatabaseConnection(),
      this.checkStorageSpace(),
      this.checkMemoryUsage(),
      this.checkIndexHealth()
    ]);
    
    return {
      status: checks.every(c => c.status === 'ok') ? 'healthy' : 'degraded',
      checks: checks,
      timestamp: Date.now()
    };
  }
};
```

## API Reference

### Core Methods

```javascript
// Session management
await memory.createSession(sessionId, metadata);
await memory.getSession(sessionId);
await memory.deleteSession(sessionId);
await memory.listSessions(filters);

// Message operations
await memory.addMessage(sessionId, message);
await memory.getMessages(sessionId, options);
await memory.updateMessage(messageId, updates);
await memory.deleteMessage(messageId);

// Context operations
await memory.getContext(sessionId, options);
await memory.setContext(sessionId, context);
await memory.compressContext(sessionId);
await memory.exportContext(sessionId, format);

// Search operations
await memory.search(query, options);
await memory.searchSemantic(query, options);
await memory.findSimilar(sessionId, options);
await memory.searchByTags(tags, options);
```

### Configuration Options

```javascript
const memoryOptions = {
  // Storage configuration
  storage: {
    type: 'sqlite|postgresql|mongodb',
    connection: 'connection_string',
    options: {}
  },
  
  // Memory limits
  limits: {
    maxContextLength: 100000,
    maxSessions: 1000,
    maxMessages: 10000,
    retentionDays: 90
  },
  
  // Compression settings
  compression: {
    enabled: true,
    threshold: 50000,
    strategy: 'intelligent|aggressive|light',
    preserveRecent: 10
  },
  
  // Search configuration
  search: {
    indexing: true,
    semanticSearch: false,
    caching: true
  },
  
  // Security settings
  security: {
    encryption: true,
    sanitization: true,
    audit: true
  }
};
```

## Troubleshooting

### Common Issues

**1. Memory Usage Too High**
```javascript
// Enable aggressive compression
await memory.updateConfig({
  compression: {
    strategy: 'aggressive',
    threshold: 30000
  }
});

// Clean up old sessions
await memory.cleanup({
  olderThan: '30d',
  keepImportant: true
});
```

**2. Search Performance Issues**
```javascript
// Rebuild search indexes
await memory.rebuildIndexes();

// Optimize database
await memory.optimize();

// Check query performance
const stats = await memory.getQueryStats();
```

**3. Context Retrieval Errors**
```javascript
// Validate context integrity
const validation = await memory.validateContext(sessionId);

// Repair corrupted context
if (!validation.valid) {
  await memory.repairContext(sessionId);
}
```

## Best Practices

### 1. Performance
- Enable compression for large contexts
- Use appropriate storage backend for your scale
- Implement caching for frequently accessed data
- Regular maintenance and cleanup

### 2. Security
- Enable encryption for sensitive conversations
- Implement proper access controls
- Regular security audits
- Sanitize user input

### 3. Reliability
- Regular backups of memory data
- Monitor system health
- Implement error handling and recovery
- Test disaster recovery procedures

---

**Need help?** Check our [troubleshooting guide](TROUBLESHOOTING.md) or [create an issue](https://github.com/your-username/claude-workspace/issues/new).