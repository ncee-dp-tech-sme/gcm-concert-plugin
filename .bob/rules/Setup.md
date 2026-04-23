# Environment Setup Phase

## Overview

This phase sets up the development environment for GCM plugin development using UV package manager, Python, and Ansible.

**Prerequisites**: Before starting plugin development, ensure the Ansible environment is properly configured.

## Critical Package Manager Rule

**ALWAYS use UV commands** for Python package management throughout the development process. Never use pip, pip3, or other package managers.

## UV Package Manager

UV is a fast Python package manager and project manager written in Rust. It is used in this project to manage Ansible and its dependencies for plugin development and testing.

**Official Documentation**: [UV Documentation](https://docs.astral.sh/uv/)

### Installation

#### Quick Install

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

After installation, UV will be available in your PATH. Restart your terminal or source your shell configuration:

```bash
source ~/.bashrc  # or ~/.zshrc
```

#### Verify Installation

```bash
uv --version
```

### Troubleshooting UV Installation

**UV not found after installation**:
```bash
# Add UV to PATH manually
export PATH="$HOME/.cargo/bin:$PATH"
```

## Project Setup

### Step 1: Create Virtual Environment

```bash
uv venv
```

This creates a `.venv` directory in your project root.

### Step 2: Initialize Python Environment

The project includes a `pyproject.toml` file with Ansible dependencies. Initialize the environment:

```bash
# Install dependencies from pyproject.toml
uv sync
```

This installs:
- ansible (>=9.0.0)
- ansible-core (>=2.16.0)

### Step 3: Activate Virtual Environment

```bash
# Activate the virtual environment
source .venv/bin/activate

# Verify Ansible installation
ansible --version
ansible-galaxy --version
```

## Managing Dependencies

### Add Dependencies

```bash
# Add a new dependency
uv add ansible-lint

# Add a dev dependency
uv add --dev pytest
```

### Remove Dependencies

```bash
# Remove a dependency
uv remove ansible-lint
```

### Update Dependencies

```bash
# Update all dependencies
uv lock --upgrade

# Update specific package
uv lock --upgrade-package ansible
```

## Testing Workflow Setup

### 1. Configure Test Environment

Create `config/inventory.ini`:
```ini
[local]
localhost ansible_connection=local
```

Create test configuration files (Bob will generate these with actual credentials):

**config/test_connection_config.json** (for test_connection.yaml - flattened structure):
```json
{
  "run_id": "test-123",
  "action": "integration.test_connection",
  "out_dir": "./test_output",
  "status_file_name": "status.json",
  "url": "https://test.example.com",
  "apiKey": "test-key",
  "verifySsl": false
}
```

**config/test_config.json** (for discover.yaml - nested structure):
```json
{
  "run_id": "test-123",
  "action": "discovery.discover",
  "out_dir": "./test_output",
  "status_file_name": "status.json",
  "pluginConfig": {
    "integration": [
      {
        "url": "https://test.example.com",
        "apiKey": "test-key",
        "verifySsl": false
      }
    ]
  }
}
```

### 2. Install Required Collections

```bash
# Install collections needed for your plugin
ansible-galaxy collection install community.general
ansible-galaxy collection install ansible.utils
```

### 3. Test Playbooks

**Linux/macOS**:
```bash
# Test connection
ansible-playbook src/integration/test_connection.yaml \
  --extra-vars "@config/test_connection_config.json"

# Run discovery
ansible-playbook src/discovery/discover.yaml \
  --extra-vars "@config/test_config.json"
```

**Windows (PowerShell)**:
```powershell
# Test connection
ansible-playbook src/integration/test_connection.yaml `
  --extra-vars "@config/test_connection_config.json"

# Run discovery
ansible-playbook src/discovery/discover.yaml `
  --extra-vars "@config/test_config.json"
```

**Windows (Command Prompt)**:
```cmd
REM Test connection
ansible-playbook src/integration/test_connection.yaml ^
  --extra-vars "@config/test_connection_config.json"

REM Run discovery
ansible-playbook src/discovery/discover.yaml ^
  --extra-vars "@config/test_config.json"
```

## Common UV Commands for Plugin Development

### Running Commands

```bash
ansible --version
ansible-playbook playbook.yaml
ansible-galaxy collection install namespace.collection
```

### Environment Management

```bash
# Remove and recreate virtual environment
rm -rf .venv
uv sync

# Show installed packages
uv pip list

# Show dependency tree
uv pip tree
```

## Verification Checklist

Before proceeding to the next phase, verify:
- [ ] UV is installed and accessible
- [ ] Virtual environment is created (`.venv` directory exists)
- [ ] Dependencies are installed (`uv sync` completed successfully)
- [ ] Ansible is accessible (`uv run ansible --version` works)
- [ ] Ansible Galaxy is accessible (`uv run ansible-galaxy --version` works)

## Next Phase

Once environment setup is complete:
- Proceed to [GatherInfo.md](GatherInfo.md) to discover integration methods
- Keep the virtual environment activated for all subsequent development tasks

## Troubleshooting

### Virtual Environment Issues

```bash
# Remove and recreate virtual environment
rm -rf .venv
uv sync
```

### Permission Issues

```bash
# Ensure UV binary has execute permissions
chmod +x ~/.cargo/bin/uv
```

### Path Issues

```bash
# Add UV to PATH in shell configuration
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## Best Practices

1. **Always activate virtual environment** before running Ansible commands
2. **Use `uv run`** prefix for all Ansible commands to ensure correct environment
3. **Keep dependencies updated** with `uv lock --upgrade` periodically
4. **Document custom dependencies** in `pyproject.toml`
5. **Test in clean environment** by recreating `.venv` before final testing