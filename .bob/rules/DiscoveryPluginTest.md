# Discovery Plugin Testing Phase

## Overview

This phase validates that the generated playbooks work correctly with the target system. Testing is MANDATORY before proceeding to transformation creation.

## Playbook Validation and Testing

**MANDATORY before Phase 3 (Transformation Creation)**

### Step 1: Ask user for test data option

Bob must ask the user:
> "To proceed with transformation creation, I need sample data from the target system. Please choose one of the following options:
>
> 1. **Provide test credentials** - I will run the playbooks to discover real data from your system
> 2. **Provide mock data** - You can provide sample JSON data files directly (skip playbook execution)
>
> Which option do you prefer?"

---

## Option 1: User Provides Test Credentials (Run Playbooks)

### Prerequisites

- Playbooks generated in previous phase
- Virtual environment activated
- Test credentials available

### Testing Process

#### 1. Request Test Credentials

**IMPORTANT**: Never ask users to provide credentials in chat. Instead, instruct them to update the test configuration files directly.

Ask user to update BOTH config files with their test credentials based on the authentication method identified in playbook generation phase:

> "Please update the test configuration files with your credentials. Based on the authentication method we identified, you'll need to provide:
> - [List specific fields based on auth method, e.g., API Key, Username/Password, etc.]
>
> **For test_connection.yaml**, update `config/test_connection_config.json` (flattened structure):
> ```json
> {
>   "run_id": "test-123",
>   "action": "integration.test_connection",
>   "out_dir": "./test_output",
>   "status_file_name": "status.json",
>   "url": "https://your-target-system.com",
>   "apiKey": "your-api-key-here",
>   "verifySsl": false
> }
> ```
>
> **For discover.yaml**, update `config/test_config.json` (nested structure):
> ```json
> {
>   "run_id": "test-123",
>   "action": "discovery.discover",
>   "out_dir": "./test_output",
>   "status_file_name": "status.json",
>   "pluginConfig": {
>     "integration": [
>       {
>         "url": "https://your-target-system.com",
>         "apiKey": "your-api-key-here",
>         "verifySsl": false
>       }
>     ]
>   }
> }
> ```
>
> Once you've updated both files, let me know and I'll proceed with testing."

#### 2. Verify Test Configuration

After user confirms they've updated the files, verify both configurations exist:

```bash
# Verify config files exist
ls -la config/test_connection_config.json
ls -la config/test_config.json
```

**Note**: The exact fields in the configuration depend on the authentication method and playbook requirements identified in Phase 3.

#### 3. Activate Virtual Environment

```bash
source .venv/bin/activate
```

#### 4. Execute test_connection.yaml

Test authentication and connectivity:

**Linux/macOS**:
```bash
ansible-playbook src/integration/test_connection.yaml \
  --extra-vars "@config/test_connection_config.json"
```

**Windows (PowerShell)**:
```powershell
ansible-playbook src/integration/test_connection.yaml `
  --extra-vars "@config/test_connection_config.json"
```

**Windows (Command Prompt)**:
```cmd
ansible-playbook src/integration/test_connection.yaml ^
  --extra-vars "@config/test_connection_config.json"
```

**Error Analysis**:

If test_connection.yaml fails, analyze the error:

**Playbook Issues** (Bob can fix - retry up to 3 times):
- Syntax errors in YAML
- Missing Ansible modules
- Wrong collection module names
- Incorrect variable references
- Missing required tasks
- Undefined variables

→ Fix the playbook and retry (maximum 3 attempts)

**Configuration/Credential Issues** (User must fix - STOP immediately):
- Authentication failures (401, 403, "Unauthorized", "Invalid credentials")
- Connection timeouts ("timeout", "timed out")
- Invalid URLs/hostnames ("Name or service not known", "Could not resolve")
- Network errors ("Connection refused", "No route to host")
- SSL certificate errors ("certificate verify failed", "SSL")

→ STOP immediately. Report error to user. Request credential/config fix. Do NOT retry.

#### 5. Execute discover.yaml

Generate sample output data:

**Linux/macOS**:
```bash
ansible-playbook src/discovery/discover.yaml \
  --extra-vars "@config/test_config.json"
```

**Windows (PowerShell)**:
```powershell
ansible-playbook src/discovery/discover.yaml `
  --extra-vars "@config/test_config.json"
```

**Windows (Command Prompt)**:
```cmd
ansible-playbook src/discovery/discover.yaml ^
  --extra-vars "@config/test_config.json"
```

**Error Analysis**:

Apply same error analysis as test_connection.yaml:
- **Playbook issues** (syntax, modules, variables) → Fix and retry (max 3 attempts)
- **Configuration/credential issues** (auth, network, SSL) → STOP and report to user

#### 6. Verify Output Files

Check that output files were created. Since the playbook runs from `src/discovery/`, output files are created relative to that directory:

```bash
# Output files are in src/discovery/test_output (relative to playbook location)
ls src/discovery/test_output/crypto_asset_details_*.json

# Count output files
ls src/discovery/test_output/crypto_asset_details_*.json | wc -l

# Check file sizes (should not be empty)
ls -lh src/discovery/test_output/crypto_asset_details_*.json
```

**Note**: Output files are created in `src/discovery/test_output`.

#### 7. Validate Output Structure

Read at least one output file to verify data structure:

```bash
# View first output file
cat src/discovery/test_output/crypto_asset_details_0_0.json | jq .

# Check if file contains valid JSON
jq empty src/discovery/test_output/crypto_asset_details_0_0.json && echo "Valid JSON" || echo "Invalid JSON"
```

Verify the output contains:
- Valid JSON structure
- Expected fields (certificates, keys, secrets, etc.)
- Actual data (not just error messages)
- Proper data types

### Hard Stop Rules

**Do NOT proceed to Phase 3 (Transformation) if**:

1. **Playbook has syntax/logic errors after 3 fix attempts**
   - STOP and report to user
   - Request manual review of playbooks

2. **Authentication or connection fails**
   - Already stopped in step 4/5
   - User must fix credentials/configuration

3. **No output files were created after successful playbook run**
   - STOP and report error
   - Investigate playbook logic for file writing

4. **Output files are empty or contain only error messages**
   - STOP and report error
   - Review playbook data extraction logic

### Success Criteria

Proceed to Phase 3 only when:
- ✅ test_connection.yaml executes successfully
- ✅ discover.yaml executes successfully
- ✅ Output files exist in `out_dir` directory
- ✅ Output files contain valid JSON
- ✅ Output files contain actual data (not errors)
- ✅ Data structure matches expected format

---

## Option 2: User Provides Mock Data (Skip Playbook Execution)

### When to Use

- User doesn't have test credentials readily available
- Target system is not accessible from development environment
- User wants to test transformation logic with sample data first
- Quick prototyping without live system access

### Process

#### 1. Request Mock Data

Ask user to provide sample JSON data files:

> "Please provide sample JSON data files that represent the output from your target system. These files should contain examples of the certificates/keys/secrets you want to discover.
>
> You can provide:
> - One or more JSON files
> - Each file should represent the structure of data returned by the target system
> - Files should contain realistic field names and data structures"

#### 2. Receive Mock Data

User can provide mock data by:
- Uploading files
- Pasting JSON content
- Providing file paths

#### 3. Save Mock Data Files

Save mock data files to output directory:

```bash
# Create output directory (matches where playbook would create it)
mkdir -p src/discovery/test_output

# Save files with proper naming convention
# crypto_asset_details_<instance_index>_<asset_index>.json
```

**Naming Convention**:
- `crypto_asset_details_0_0.json` - First asset from first instance
- `crypto_asset_details_0_1.json` - Second asset from first instance
- `crypto_asset_details_1_0.json` - First asset from second instance

#### 4. Verify Mock Data Files

Use `read_file` tool to read the provided files and verify:

```bash
# Check file exists
ls src/discovery/test_output/crypto_asset_details_*.json

# Validate JSON structure
jq empty src/discovery/test_output/crypto_asset_details_0_0.json

# View content
cat src/discovery/test_output/crypto_asset_details_0_0.json | jq .
```

**Verification Checklist**:
- [ ] Files contain valid JSON
- [ ] JSON has expected structure (objects/arrays with fields)
- [ ] Data looks realistic (not just placeholder text)
- [ ] Field names match expected target system format
- [ ] Data types are appropriate (strings, numbers, booleans)

#### 5. Validation Results

**If verification passes**:
- Proceed to Phase 3 (Transformation) with the mock data files
- Use these files as input for transformation creation

**If verification fails**:
- Report error to user: "Mock data files are invalid or incomplete"
- Specify what's wrong (invalid JSON, missing fields, etc.)
- Request user to provide corrected files

### Important Notes

- Mock data should be representative of real data structure from the target system
- Transformation created with mock data should still work with real data (same structure)
- User can always re-run with real credentials later to validate the plugin
- Mock data is useful for development and testing, but final validation should use real data

---

## Output Directory Configuration

The output directory location is determined by the `out_dir` field in the configuration file:

```json
{
  "out_dir": "./test_output",
  "status_file_name": "status.json"
}
```

All output files are written to this directory:
- `crypto_asset_details_*.json` - Discovered asset data
- `status.json` - Playbook execution status

---

## Temporary Files for Testing

### Inventory File

Create `config/inventory.ini` for local testing:

```ini
[local]
localhost ansible_connection=local
```

### Ansible Configuration

Create `ansible.cfg` in project root (optional):

```ini
[defaults]
inventory = config/inventory.ini
host_key_checking = False
retry_files_enabled = False

[privilege_escalation]
become = False
```

---

## Next Phase

Once testing is complete and output files are verified:
- Proceed to [Transformation.md](Transformation.md) for transformation creation
- Use the actual output files from this phase as input for transformation
- Do NOT proceed without valid output data