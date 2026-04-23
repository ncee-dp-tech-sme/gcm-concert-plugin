# GCM Plugin Packaging Rules

## Context

This packaging process is executed during **Phase 7: Plugin Packaging and Deployment** of the GCM plugin development workflow. It should only be triggered after:
- All plugin files have been generated (manifest, playbooks, transformations, UI schemas, README)
- User has reviewed and approved the plugin for packaging

## Core Directive

When user requests "create zip file" or "package plugin", execute the packaging workflow below.

**PREREQUISITE**: User must have approved the plugin for packaging. If not yet approved, request user review first.

## Manifest.json Schema

The `manifest.json` file MUST adhere to this JSON schema:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": [
    "code",
    "title",
    "description",
    "version",
    "type",
    "category",
    "capability"
  ],
  "properties": {
    "code": {
      "type": "string",
      "description": "Unique identifier for the plugin"
    },
    "title": {
      "type": "string",
      "description": "Display title of the plugin"
    },
    "description": {
      "type": "string",
      "description": "Description of the plugin"
    },
    "version": {
      "type": "string",
      "pattern": "^\\d+\\.\\d+\\.\\d+$",
      "description": "Semantic version of the plugin (e.g., 1.0.0)"
    },
    "type": {
      "type": "string",
      "enum": ["internal", "external"],
      "description": "Type of plugin - must be either 'internal' or 'external'"
    },
    "category": {
      "type": "array",
      "items": {
        "type": "string",
        "enum": ["DISCOVERY", "PKI"]
      },
      "minItems": 1,
      "description": "Categories this plugin belongs to"
    },
    "dependencies": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["dependency", "supportedVersions"],
        "properties": {
          "dependency": {
            "type": "string"
          },
          "supportedVersions": {
            "type": "string"
          },
          "comment": {
            "type": "string"
          }
        }
      }
    },
    "tags": {
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "capability": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "required": ["component", "supportedActions"],
        "properties": {
          "component": {
            "type": "string"
          },
          "supportedActions": {
            "type": "array",
            "items": {
              "type": "string"
            },
            "minItems": 1
          }
        }
      },
      "contains": {
        "type": "object",
        "properties": {
          "component": {
            "const": "integration"
          }
        },
        "required": ["component"]
      },
      "description": "Plugin capabilities - must contain at least one capability with component 'integration'"
    },
    "transformation": {
      "type": "object",
      "properties": {
        "type": {
          "type": "string"
        },
        "reference": {
          "type": "string"
        }
      }
    },
    "config": {
      "type": "object",
      "properties": {
        "type": {
          "type": "string",
          "enum": ["inline", "external"]
        }
      }
    }
  }
}
```

### Required Fields
- `code`: Unique identifier (string)
- `title`: Display title (string)
- `description`: Plugin description (string)
- `version`: Semantic version matching `^\d+\.\d+\.\d+$` (e.g., "1.0.0")
- `type`: Either "internal" or "external" (Bob-generated plugins are always "external")
- `category`: Array with at least one of ["DISCOVERY", "PKI"]
- `capability`: Array with at least one capability object; MUST contain one with `component: "integration"`

### Optional Fields
- `dependencies`: Array of dependency objects with `dependency`, `supportedVersions`, and optional `comment`
- `tags`: Array of strings
- `transformation`: Object with `type` and `reference`
- `config`: Object with `type` ("inline" or "external")

### Example manifest.json

```json
{
  "code": "hashicorp-vault-discovery",
  "title": "HashiCorp Vault Discovery",
  "description": "Discovery plugin for HashiCorp Vault",
  "version": "1.0.0",
  "type": "external",
  "category": ["DISCOVERY"],
  "capability": [
    {
      "component": "integration",
      "supportedActions": ["test-connection"]
    },
    {
      "component": "discovery",
      "supportedActions": ["discover", "abort"]
    }
  ],
  "transformation": {
    "type": "gcm",
    "reference": "transformation/discovery/transform_discover.json"
  },
  "config": {
    "type": "inline"
  }
}
```

## Packaging Workflow

### Step 1: Execute Packaging Script

Bob has created automated packaging scripts for both Unix/Linux/macOS and Windows systems. These scripts handle all packaging steps automatically.

**For Unix/Linux/macOS:**
```bash
./package.sh
```

**For Windows (PowerShell):**
```powershell
.\package.ps1
```

Both scripts will:
1. Read plugin metadata from `manifest.json`
2. Verify `.bundleignore` file exists
3. Create a temporary directory
4. Copy all files (excluding patterns from `.bundleignore`)
5. Create zip file with files at root level
6. Clean up temporary directory
7. Verify and report package structure

### Step 2: Verify Structure
After creating zip, verify it contains files at root level:
```bash
unzip -l "$ZIP_NAME" | head -20
```

Expected output:
```
Archive:  plugin-code-1.0.0.zip
  Length      Date    Time    Name
---------  ---------- -----   ----
      XXX  XX-XX-XXXX XX:XX   manifest.json
      XXX  XX-XX-XXXX XX:XX   README.md
        0  XX-XX-XXXX XX:XX   src/
        0  XX-XX-XXXX XX:XX   config/
        0  XX-XX-XXXX XX:XX   config/integration/
      XXX  XX-XX-XXXX XX:XX   config/integration/integration-json-schema.json
```

### Step 3: Report Completion
```
✓ Plugin packaged successfully
✓ Zip file: plugin-code-1.0.0.zip
✓ Size: X.X KB
✓ Location: /path/to/workspace/

Package structure verified:
plugin-code-1.0.0.zip (files at root level)
├── manifest.json
├── README.md
├── requirements.yaml
├── pyproject.toml
├── src/
│   ├── discovery/
│   └── integration/
├── config/
│   └── integration/
├── transformation/
│   └── discovery/
└── translation/
    └── en/
```

## Critical Rules

1. **ALWAYS** create temp directory to stage files
2. **ALWAYS** use `.bundleignore` to exclude unwanted files via rsync/copy
3. **ALWAYS** exclude temp directory and zip files from copy
4. **ALWAYS** zip from INSIDE temp directory to get files at root level
5. **ALWAYS** cleanup temp directory after zipping
6. **NEVER** zip the temp directory itself - zip its contents

## Expected Result

The zip file MUST have this structure (files at root level):
```
plugin-code-1.0.0.zip
├── manifest.json            ← Files at root level (no nested folder)
├── README.md
├── requirements.yaml
├── pyproject.toml
├── src/                     ← Directories at root level
│   ├── discovery/
│   └── integration/
├── config/
│   └── integration/
├── transformation/
│   └── discovery/
└── translation/
    └── en/
```

## Error Handling

If packaging fails:
1. Check manifest.json exists and is valid JSON
2. Check required files exist (manifest.json, README.md, requirements.yaml)
3. Check write permissions in workspace directory
4. Report specific error to user

## Validation

After creating zip, MUST verify:
- [ ] Zip file exists
- [ ] Zip file size > 0
- [ ] Zip contains `manifest.json` at root level (not nested in a folder)
- [ ] Zip contains `README.md` at root level
- [ ] Zip contains `src/`, `config/`, `transformation/`, `translation/` directories at root level
- [ ] No nested `{code}-{version}/` folder structure

## Next Steps: Deployment

After successful packaging, proceed with deployment using MCP tools:

### Step 1: Upload Plugin

**Option A: Using MCP Tool (Recommended)**

Use `upload_plugin` MCP tool to upload the zip file to GCM:

**Required Parameters**:
- `file_content`: Binary content of the zip file (read the zip file as bytes)
- `filename`: Name of the zip file (e.g., "hashicorp-vault-discovery-1.0.0.zip")

**Process**:
1. Read the zip file as binary content
2. Call `upload_plugin` MCP tool with file content and filename
3. Wait for upload response
4. Check if upload was successful

**Example**:
```
Use upload_plugin MCP tool with:
- file_content: <binary content of plugin-code-1.0.0.zip>
- filename: "plugin-code-1.0.0.zip"
```

**Option B: Using curl Command (Alternative)**

If MCP tool is unavailable, use curl to upload the plugin directly:

**Unix/Linux/macOS**:
```bash
# Read token from .bob/mcp.json
TOKEN=$(python3 -c "import json; print(json.load(open('.bob/mcp.json'))['mcpServers']['gcm-custom-adaptor']['headers']['Authorization'].split('Bearer ')[1])")

# Read plugin metadata
PLUGIN_CODE=$(python3 -c "import json; print(json.load(open('manifest.json'))['code'])")
PLUGIN_VERSION=$(python3 -c "import json; print(json.load(open('manifest.json'))['version'])")
ZIP_NAME="${PLUGIN_CODE}-${PLUGIN_VERSION}.zip"

# Upload to GCM
curl -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@$ZIP_NAME" \
  https://aim-gcm.dev.fyre.ibm.com:31443/ibm/plugin-framework/api/v1/plugins/upload

# Check response for success
```

**Windows PowerShell**:
```powershell
# Read token from .bob/mcp.json
$mcpConfig = Get-Content .bob/mcp.json | ConvertFrom-Json
$token = $mcpConfig.mcpServers.'gcm-custom-adaptor'.headers.Authorization -replace 'Bearer ', ''

# Read plugin metadata
$manifest = Get-Content manifest.json | ConvertFrom-Json
$zipName = "$($manifest.code)-$($manifest.version).zip"

# Upload to GCM
$headers = @{
    "Authorization" = "Bearer $token"
}
$uri = "https://aim-gcm.dev.fyre.ibm.com:31443/ibm/plugin-framework/api/v1/plugins/upload"

Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Form @{
    file = Get-Item $zipName
}
```

### Step 2: Install Plugin (if upload successful)

If upload succeeds, notify user and proceed with installation:

**User Notification**:
```
✓ Plugin uploaded successfully to GCM
→ Proceeding with plugin installation...
```

Use `install_plugin` MCP tool to install the uploaded plugin:

**Required Parameters**:
- `plugin_id`: Plugin code from manifest.json `code` field (e.g., "hashicorp-vault-discovery")
- `version_number`: Plugin version from manifest.json `version` field (e.g., "1.0.0")

**Process**:
1. Extract plugin_id from manifest.json `code` field
2. Extract version_number from manifest.json `version` field
3. Call `install_plugin` MCP tool with plugin_id and version_number
4. Wait for installation response
5. Report installation status to user

**Example**:
```
Use install_plugin MCP tool with:
- plugin_id: "hashicorp-vault-discovery"
- version_number: "1.0.0"
```

### Step 3: Report Final Status

**If both upload and installation succeed**:
```
✓ Plugin packaged successfully
✓ Plugin uploaded to GCM
✓ Plugin installed successfully

Plugin Details:
- Name: [Plugin Name]
- Version: [Version]
- Plugin ID: [plugin_id]
- Zip File: [filename]

The plugin is now ready for use in GCM.
```

**If upload fails**:
```
✓ Plugin packaged successfully
✗ Plugin upload failed: [error message]

Please check:
- GCM connection and credentials
- Network connectivity
- Zip file integrity
```

**If upload succeeds but installation fails**:
```
✓ Plugin packaged successfully
✓ Plugin uploaded to GCM
✗ Plugin installation failed: [error message]

The plugin has been uploaded but installation failed.
You can try installing it manually from the GCM UI.
```

### Step 4: Update CHECKPOINT.md

After deployment (success or failure), update CHECKPOINT.md:
```
## Phase 7: Packaging and Deployment
- Packaging: ✓ Complete
- Zip file: [filename]
- Upload: [✓ Success / ✗ Failed]
- Installation: [✓ Success / ✗ Failed]
- Status: [Ready for use / Needs manual installation / Failed]
```
