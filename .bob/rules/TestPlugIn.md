# Plugin Deployment Phase

## Overview

This phase handles uploading the packaged plugin to GCM and verifying successful deployment.

## Phase 8: Plugin Deployment to GCM

**Prerequisites**:
- Plugin packaged as zip file (from Phase 7)
- GCM instance accessible
- Appropriate permissions to upload plugins

**IMPORTANT - Python Dependencies**:
Before testing the plugin, Bob should:

1. **Extract collection Python dependencies** (if using Ansible collection):
   ```bash
   # Find and copy collection's requirements.txt to project root
   COLLECTION_PATH="ansible_collections/<namespace>/<collection>"
   if [ -f "$COLLECTION_PATH/requirements.txt" ]; then
     cp "$COLLECTION_PATH/requirements.txt" ./requirements.txt
     echo "Collection dependencies copied to requirements.txt"
   else
     echo "No collection requirements.txt found"
   fi
   ```
   This creates a `requirements.txt` file with ONLY the collection's Python dependencies that need to be installed on the GCM server.

2. **Clean virtual environment before testing** (optional but recommended):
   ```bash
   deactivate  # If venv is active
   rm -rf .venv
   uv venv
   source .venv/bin/activate
   uv sync  # Reinstall from pyproject.toml
   
   # Reinstall collection dependencies
   if [ -f "requirements.txt" ]; then
     uv pip install -r requirements.txt
   fi
   ```
   This ensures no unknown dependencies are missing during testing.

**Note**: The `requirements.txt` file should contain ONLY the collection's Python dependencies (e.g., `boto3`, `requests`, `azure-identity`), NOT Ansible or other development dependencies.

### Step 1: Upload Plugin to GCM

**Using MCP Tool**:
```
Use upload_plugin_to_gcm MCP tool with:
- plugin_zip_path: path/to/plugin_name_version.zip
- gcm_url: https://gcm.example.com
- credentials: [as configured]
```

**Manual Upload** (if MCP tool unavailable):
1. Log in to GCM web interface
2. Navigate to Plugin Management section
3. Click "Upload Plugin" or similar option
4. Select the plugin zip file
5. Confirm upload

**TODO**: Add detailed MCP tool usage and manual upload steps

### Step 2: Verify Plugin in Catalog

**Verification Steps**:
1. Navigate to GCM Plugin Catalog
2. Search for the uploaded plugin by name
3. Verify plugin appears in the list
4. Check plugin version matches uploaded version
5. Verify plugin status shows as "Available" or "Ready"

**TODO**: Add screenshots and detailed verification steps

### Step 3: Test Plugin Installation

**Installation Test**:
1. Create a new integration profile in GCM
2. Select the uploaded plugin
3. Configure integration parameters using the UI
4. Save the configuration
5. Verify configuration is saved successfully

**TODO**: Add detailed testing procedures

### Step 4: Test Plugin Execution

**Execution Test**:
1. Trigger a discovery run using the configured profile
2. Monitor execution status
3. Verify discovery completes successfully
4. Check discovered assets appear in GCM inventory
5. Validate asset data is correct and complete

**TODO**: Add execution testing guidelines

### Step 5: Confirm Deployment Success

**Success Criteria**:
- [ ] Plugin uploaded successfully
- [ ] Plugin appears in GCM catalog
- [ ] Plugin can be configured in integration profile
- [ ] Discovery execution completes without errors
- [ ] Assets are discovered and appear in inventory
- [ ] Asset data matches expected format

## Troubleshooting

### Upload Failures

**Common Issues**:
- Invalid zip file format
- Missing required files in plugin package
- Incompatible plugin version
- Insufficient permissions

**TODO**: Add detailed troubleshooting steps

### Configuration Issues

**Common Issues**:
- UI schema not rendering correctly
- Validation errors on configuration save
- Missing or incorrect field definitions

**TODO**: Add configuration troubleshooting

### Execution Failures

**Common Issues**:
- Authentication failures
- Network connectivity problems
- Transformation errors
- Missing dependencies

**Missing Python Dependencies**:
If the plugin execution fails with import errors (e.g., `ModuleNotFoundError: No module named 'boto3'`):

1. **Check the `requirements.txt`** file in the project root (should contain only collection dependencies)
2. **Verify it contains ONLY collection dependencies**, not Ansible or development tools
3. **Install missing dependencies on GCM server** using the requirements.txt file
4. **Contact your GCM administrator** to install the dependencies if you don't have server access

To regenerate the requirements.txt file from collection:
```bash
COLLECTION_PATH="ansible_collections/<namespace>/<collection>"
if [ -f "$COLLECTION_PATH/requirements.txt" ]; then
  cp "$COLLECTION_PATH/requirements.txt" ./requirements.txt
fi
```

**TODO**: Add execution troubleshooting

## Rollback Procedure

If deployment fails or issues are discovered:

1. **Disable Plugin**: Mark plugin as inactive in GCM
2. **Remove Configurations**: Delete any integration profiles using the plugin
3. **Uninstall Plugin**: Remove plugin from GCM catalog
4. **Fix Issues**: Address identified problems in plugin code
5. **Re-package**: Create new plugin zip with fixes
6. **Re-deploy**: Upload corrected plugin version

**TODO**: Add detailed rollback procedures

## Next Steps

Once plugin is successfully deployed:
- Document any deployment-specific configurations
- Create user guide for plugin usage
- Set up monitoring for plugin executions
- Plan for future updates and maintenance

---

**Note**: This file contains placeholder content. Detailed deployment procedures, MCP tool usage, troubleshooting steps, and rollback procedures need to be added based on GCM deployment specifications.