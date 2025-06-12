const express = require('express');
const router = express.Router();

// Example controller
const exampleController = require('../controllers/exampleController');

// Example routes with validation
router.get('/examples', exampleController.getAll);
router.get('/examples/:id', exampleController.getById);
router.post('/examples', exampleController.create);
router.put('/examples/:id', exampleController.update);
router.delete('/examples/:id', exampleController.delete);

// Status route
router.get('/status', (req, res) => {
  res.json({
    api: 'v1',
    status: 'operational',
    timestamp: new Date().toISOString()
  });
});

module.exports = router;