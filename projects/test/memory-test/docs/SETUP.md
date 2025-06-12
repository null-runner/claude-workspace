# Setup Guide

**Language:** [🇺🇸 English](SETUP.md) | [🇮🇹 Italiano](SETUP_IT.md)

## Prerequisites

Before setting up Claude Workspace, ensure you have the following installed:

- **Node.js** (version 16 or higher)
- **npm** or **yarn** package manager
- **Git** version control system
- **Claude API access** (Anthropic account required)
- **Terminal/Shell** with administrator privileges

## Installation Steps

### 1. Clone the Repository

```bash
git clone https://github.com/your-username/claude-workspace.git
cd claude-workspace
```

### 2. Install Dependencies

Using npm:
```bash
npm install
```

Using yarn:
```bash
yarn install
```

### 3. Environment Configuration

1. Copy the environment template:
   ```bash
   cp .env.example .env
   ```

2. Edit the `.env` file with your settings:
   ```bash
   # Claude API Configuration
   CLAUDE_API_KEY=your_api_key_here
   CLAUDE_MODEL=claude-3-sonnet-20240229
   
   # Workspace Configuration
   WORKSPACE_PATH=/path/to/your/workspace
   MEMORY_STORAGE_PATH=./data/memory
   
   # Security Settings
   ENCRYPTION_KEY=your_secure_encryption_key
   SESSION_TIMEOUT=3600
   ```

### 4. API Key Setup

1. **Get your Claude API key:**
   - Visit [console.anthropic.com](https://console.anthropic.com)
   - Create an account or sign in
   - Navigate to API Keys section
   - Generate a new API key

2. **Configure the API key:**
   - Add your API key to the `.env` file
   - Verify access with the test command:
     ```bash
     npm run test-api
     ```

### 5. Initialize the Memory System

```bash
npm run init-memory
```

This command will:
- Create necessary directories
- Set up the memory database
- Configure initial settings
- Run system diagnostics

### 6. Run Setup Script

Execute the automated setup script:

```bash
chmod +x setup.sh
./setup.sh
```

The script will:
- Verify all dependencies
- Configure system paths
- Set up logging
- Initialize the workspace
- Run basic tests

## Verification

### Test the Installation

1. **Basic functionality test:**
   ```bash
   npm run test
   ```

2. **API connectivity test:**
   ```bash
   npm run test-connection
   ```

3. **Memory system test:**
   ```bash
   npm run test-memory
   ```

### Expected Output

If everything is configured correctly, you should see:
```
✅ All dependencies installed
✅ Environment variables configured
✅ Claude API connection established
✅ Memory system initialized
✅ Workspace ready for use
```

## Configuration Options

### Advanced Settings

Edit `config/workspace.json` for advanced configuration:

```json
{
  "memory": {
    "maxContextLength": 100000,
    "persistenceEnabled": true,
    "compressionLevel": "medium"
  },
  "workflow": {
    "autoSave": true,
    "backupInterval": 300,
    "maxRetries": 3
  },
  "security": {
    "encryptionEnabled": true,
    "auditLogging": true,
    "sessionManagement": true
  }
}
```

### Custom Workflows

To set up custom workflows:

1. Create workflow files in `workflows/` directory
2. Define workflow steps in YAML format
3. Register workflows in `config/workflows.json`

Example workflow structure:
```yaml
name: "Development Workflow"
steps:
  - name: "Code Review"
    action: "analyze"
    parameters:
      files: ["src/**/*.js"]
  - name: "Generate Documentation"
    action: "document"
    parameters:
      output: "docs/api.md"
```

## Troubleshooting

### Common Issues

**1. API Key Not Working**
- Verify the key is correct and active
- Check API usage limits
- Ensure proper environment variable setup

**2. Memory System Errors**
- Check file permissions in data directory
- Verify disk space availability
- Review memory configuration settings

**3. Installation Failures**
- Update Node.js to the latest stable version
- Clear npm cache: `npm cache clean --force`
- Delete `node_modules` and reinstall

**4. Permission Issues**
- Run with appropriate permissions
- Check directory ownership
- Verify PATH environment variable

### Getting Help

If you encounter issues:

1. Check the logs in `logs/` directory
2. Review the [troubleshooting guide](TROUBLESHOOTING.md)
3. Search existing [GitHub issues](https://github.com/your-username/claude-workspace/issues)
4. Create a new issue with detailed error information

## Next Steps

After successful installation:

1. Read the [Workflow Documentation](WORKFLOW.md)
2. Review [Security Guidelines](SECURITY.md)
3. Explore the [Memory System](MEMORY-SYSTEM.md)
4. Try the example workflows in `examples/`

## Updating

To update Claude Workspace:

```bash
git pull origin main
npm update
npm run update-config
```

Always backup your configuration and data before updating.

---

**Need more help?** Check our [documentation](../README.md) or [create an issue](https://github.com/your-username/claude-workspace/issues/new).