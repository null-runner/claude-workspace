// Example controller with basic CRUD operations
const { validationResult } = require('express-validator');

// In-memory storage (replace with database in production)
let examples = [];
let nextId = 1;

exports.getAll = (req, res) => {
  try {
    const { page = 1, limit = 10, sort = 'id' } = req.query;
    const startIndex = (page - 1) * limit;
    const endIndex = page * limit;

    const sortedExamples = [...examples].sort((a, b) => {
      return sort === 'id' ? a.id - b.id : a[sort]?.localeCompare(b[sort]) || 0;
    });

    const paginatedExamples = sortedExamples.slice(startIndex, endIndex);

    res.json({
      data: paginatedExamples,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: examples.length,
        totalPages: Math.ceil(examples.length / limit)
      }
    });
  } catch (error) {
    res.status(500).json({ error: { message: 'Failed to fetch examples' } });
  }
};

exports.getById = (req, res) => {
  try {
    const { id } = req.params;
    const example = examples.find(e => e.id === parseInt(id));
    
    if (!example) {
      return res.status(404).json({
        error: { message: 'Example not found' }
      });
    }
    
    res.json({ data: example });
  } catch (error) {
    res.status(500).json({ error: { message: 'Failed to fetch example' } });
  }
};

exports.create = (req, res) => {
  try {
    // Validate request
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: { message: 'Validation failed', details: errors.array() }
      });
    }

    const newExample = {
      id: nextId++,
      ...req.body,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };
    
    examples.push(newExample);
    res.status(201).json({ data: newExample });
  } catch (error) {
    res.status(500).json({ error: { message: 'Failed to create example' } });
  }
};

exports.update = (req, res) => {
  try {
    const { id } = req.params;
    const index = examples.findIndex(e => e.id === parseInt(id));
    
    if (index === -1) {
      return res.status(404).json({
        error: { message: 'Example not found' }
      });
    }
    
    // Validate request
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: { message: 'Validation failed', details: errors.array() }
      });
    }
    
    examples[index] = {
      ...examples[index],
      ...req.body,
      updatedAt: new Date().toISOString()
    };
    
    res.json({ data: examples[index] });
  } catch (error) {
    res.status(500).json({ error: { message: 'Failed to update example' } });
  }
};

exports.delete = (req, res) => {
  try {
    const { id } = req.params;
    const index = examples.findIndex(e => e.id === parseInt(id));
    
    if (index === -1) {
      return res.status(404).json({
        error: { message: 'Example not found' }
      });
    }
    
    examples.splice(index, 1);
    res.status(204).send();
  } catch (error) {
    res.status(500).json({ error: { message: 'Failed to delete example' } });
  }
};