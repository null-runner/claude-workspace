# Documentazione Sistema di Memoria

**Lingua:** [🇺🇸 English](MEMORY-SYSTEM.md) | [🇮🇹 Italiano](MEMORY-SYSTEM_IT.md)

## Panoramica

Il Sistema di Memoria è un componente centrale di Claude Workspace che fornisce gestione avanzata del contesto per conversazioni di lunga durata con Claude AI. Abilita cronologia persistente delle conversazioni, compressione intelligente del contesto e recupero efficiente di informazioni rilevanti tra le sessioni.

## Architettura

### 1. Componenti del Sistema

```
Sistema di Memoria
├── Gestore Contesto      # Gestisce contesti conversazione
├── Motore Storage       # Gestisce persistenza dati
├── Modulo Compressione  # Ottimizza dimensione contesto
├── Sistema Recupero     # Abilita ricerca contesto
└── Livello Sicurezza   # Assicura protezione dati
```

### 2. Flusso Dati

```
Input Utente → Gestore Contesto → Motore Storage → Database Memoria
                ↓
Risposta Claude ← Recupero Contesto ← Modulo Compressione
```

## Funzionalità Principali

### 1. Storage Contesto Persistente

Il sistema di memoria salva automaticamente il contesto conversazione tra le sessioni:

```javascript
const memorySystem = new MemorySystem({
  maxContextLength: 100000,
  compressionEnabled: true,
  persistenceMode: 'automatic'
});

// Il contesto viene salvato automaticamente dopo ogni interazione
await memorySystem.processConversation({
  sessionId: 'progetto-123',
  messages: [
    { role: 'user', content: 'Aiutami a debuggare questa funzione JavaScript' },
    { role: 'assistant', content: 'Sarò felice di aiutarti...' }
  ]
});
```

### 2. Compressione Intelligente del Contesto

Quando il contesto supera i limiti, il sistema comprime intelligentemente i contenuti più vecchi:

```javascript
const compressionStrategies = {
  // Riassumere messaggi più vecchi
  summarization: {
    threshold: 50000, // caratteri
    ratio: 0.3, // comprimi al 30% dell'originale
    preserveRecent: 10 // mantieni ultimi 10 messaggi invariati
  },
  
  // Rimuovere informazioni ridondanti
  deduplication: {
    enabled: true,
    similarityThreshold: 0.8
  },
  
  // Prioritizzare contenuto importante
  importance: {
    codeBlocks: 'high',
    errors: 'high',
    solutions: 'medium',
    general: 'low'
  }
};
```

### 3. Recupero e Ricerca Contesto

Recupera contesto rilevante da conversazioni precedenti:

```javascript
// Trova conversazioni correlate
const relevantContext = await memorySystem.searchContext({
  query: 'debug JavaScript',
  maxResults: 5,
  timeRange: '30d' // ultimi 30 giorni
});

// Ottieni cronologia sessione completa
const sessionHistory = await memorySystem.getSession('progetto-123');

// Cerca per parole chiave
const keywordResults = await memorySystem.searchByKeywords([
  'funzione', 'errore', 'debugging'
]);
```

## Guida Implementazione

### 1. Setup Base

```javascript
import { MemorySystem } from 'claude-workspace';

const memory = new MemorySystem({
  // Configurazione storage
  storage: {
    type: 'sqlite', // o 'postgresql', 'mongodb'
    path: './data/memory.db',
    encryption: true
  },
  
  // Limiti contesto
  limits: {
    maxContextLength: 100000,
    maxSessions: 1000,
    retentionDays: 90
  },
  
  // Impostazioni compressione
  compression: {
    enabled: true,
    threshold: 50000,
    strategy: 'intelligent'
  }
});

await memory.initialize();
```

### 2. Gestione Sessioni

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

### 3. Gestione Avanzata Contesto

```javascript
// Elaborazione contesto personalizzata
const contextProcessor = {
  async preprocessContext(context) {
    // Rimuovere informazioni sensibili
    context = this.sanitizeContext(context);
    
    // Arricchire con metadata
    context = await this.addMetadata(context);
    
    // Applicare preferenze utente
    context = this.applyUserPreferences(context);
    
    return context;
  },
  
  async postprocessContext(context) {
    // Aggiungere riferimenti incrociati
    context = await this.addCrossReferences(context);
    
    // Aggiornare punteggi rilevanza
    context = this.updateRelevanceScores(context);
    
    return context;
  }
};
```

## Opzioni Storage

### 1. SQLite (Default)

**Pro:**
- Nessuna dipendenza esterna
- Veloce per scenari singolo utente
- Storage basato su file

**Configurazione:**
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

**Pro:**
- Eccellente per ambienti multi-utente
- Capacità query avanzate
- Forte consistenza

**Configurazione:**
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

**Pro:**
- Struttura documento flessibile
- Storage JSON naturale
- Scaling orizzontale

**Configurazione:**
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

## Ottimizzazione Memoria

### 1. Strategie Compressione Contesto

**Compressione Gerarchica:**
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

**Compressione Semantica:**
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

### 2. Ottimizzazione Performance

**Strategia Indicizzazione:**
```sql
-- Ottimizza per query comuni
CREATE INDEX idx_session_timestamp ON conversations(session_id, timestamp);
CREATE INDEX idx_content_search ON conversations USING gin(to_tsvector('english', content));
CREATE INDEX idx_metadata ON conversations USING gin(metadata);
```

**Livello Caching:**
```javascript
const cacheConfig = {
  type: 'redis',
  ttl: 3600, // 1 ora
  maxSize: '100MB',
  strategies: {
    context: 'lru',
    search: 'lfu',
    metadata: 'ttl'
  }
};
```

## Ricerca e Recupero

### 1. Ricerca Full-Text

```javascript
const searchOptions = {
  // Ricerca testo
  query: 'debug funzione JavaScript',
  
  // Filtri
  filters: {
    sessionId: 'progetto-123',
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
  
  // Risultati
  limit: 10,
  offset: 0,
  includeContext: true
};

const results = await memory.search(searchOptions);
```

### 2. Ricerca Semantica

```javascript
// Ricerca semantica basata su vettori
const semanticSearch = await memory.searchSemantic({
  query: 'Come correggere problemi async/await?',
  model: 'text-embedding-ada-002',
  threshold: 0.8,
  maxResults: 5
});

// Cercatore conversazioni simili
const similarConversations = await memory.findSimilar({
  sessionId: 'sessione-corrente',
  method: 'cosine_similarity',
  threshold: 0.7
});
```

## Sicurezza e Privacy

### 1. Crittografia Dati

```javascript
const securityConfig = {
  encryption: {
    algorithm: 'aes-256-gcm',
    keyRotation: '30d',
    fieldLevel: true // critta solo campi sensibili
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

### 2. Sanificazione Dati

```javascript
const dataSanitizer = {
  sanitizeBeforeStorage(content) {
    // Rimuovere pattern PII
    const patterns = [
      /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/g, // email
      /\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/g, // carte credito
      /\b\d{3}-\d{2}-\d{4}\b/g, // codice fiscale
    ];
    
    patterns.forEach(pattern => {
      content = content.replace(pattern, '[CENSURATO]');
    });
    
    return content;
  }
};
```

## Monitoraggio e Analytics

### 1. Metriche Performance

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

### 2. Monitoraggio Salute

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

## Riferimento API

### Metodi Principali

```javascript
// Gestione sessioni
await memory.createSession(sessionId, metadata);
await memory.getSession(sessionId);
await memory.deleteSession(sessionId);
await memory.listSessions(filters);

// Operazioni messaggi
await memory.addMessage(sessionId, message);
await memory.getMessages(sessionId, options);
await memory.updateMessage(messageId, updates);
await memory.deleteMessage(messageId);

// Operazioni contesto
await memory.getContext(sessionId, options);
await memory.setContext(sessionId, context);
await memory.compressContext(sessionId);
await memory.exportContext(sessionId, format);

// Operazioni ricerca
await memory.search(query, options);
await memory.searchSemantic(query, options);
await memory.findSimilar(sessionId, options);
await memory.searchByTags(tags, options);
```

### Opzioni Configurazione

```javascript
const memoryOptions = {
  // Configurazione storage
  storage: {
    type: 'sqlite|postgresql|mongodb',
    connection: 'stringa_connessione',
    options: {}
  },
  
  // Limiti memoria
  limits: {
    maxContextLength: 100000,
    maxSessions: 1000,
    maxMessages: 10000,
    retentionDays: 90
  },
  
  // Impostazioni compressione
  compression: {
    enabled: true,
    threshold: 50000,
    strategy: 'intelligent|aggressive|light',
    preserveRecent: 10
  },
  
  // Configurazione ricerca
  search: {
    indexing: true,
    semanticSearch: false,
    caching: true
  },
  
  // Impostazioni sicurezza
  security: {
    encryption: true,
    sanitization: true,
    audit: true
  }
};
```

## Risoluzione Problemi

### Problemi Comuni

**1. Uso Memoria Troppo Alto**
```javascript
// Abilita compressione aggressiva
await memory.updateConfig({
  compression: {
    strategy: 'aggressive',
    threshold: 30000
  }
});

// Pulisci sessioni vecchie
await memory.cleanup({
  olderThan: '30d',
  keepImportant: true
});
```

**2. Problemi Performance Ricerca**
```javascript
// Ricostruisci indici ricerca
await memory.rebuildIndexes();

// Ottimizza database
await memory.optimize();

// Controlla performance query
const stats = await memory.getQueryStats();
```

**3. Errori Recupero Contesto**
```javascript
// Valida integrità contesto
const validation = await memory.validateContext(sessionId);

// Ripara contesto corrotto
if (!validation.valid) {
  await memory.repairContext(sessionId);
}
```

## Best Practice

### 1. Performance
- Abilita compressione per contesti grandi
- Usa backend storage appropriato per la tua scala
- Implementa caching per dati frequentemente acceduti
- Manutenzione e pulizia regolari

### 2. Sicurezza
- Abilita crittografia per conversazioni sensibili
- Implementa controlli accesso appropriati
- Audit sicurezza regolari
- Sanifica input utente

### 3. Affidabilità
- Backup regolari dati memoria
- Monitora salute sistema
- Implementa gestione errori e recupero
- Testa procedure disaster recovery

---

**Hai bisogno di aiuto?** Controlla la nostra [guida risoluzione problemi](TROUBLESHOOTING_IT.md) o [crea un'issue](https://github.com/your-username/claude-workspace/issues/new).