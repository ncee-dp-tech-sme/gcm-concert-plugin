# Information Gathering Phase

## Overview

This phase focuses on discovering the best integration method for the target system. Bob searches for API documentation, OpenAPI specifications, and Ansible collections in a prioritized order.

**Priority Order**: API Documentation > OpenAPI Spec > Ansible Collection > User-Provided Method

## Phase 1: Target System Analysis and Integration Method Discovery

**Prerequisites**:
- Virtual environment must be activated (`source .venv/bin/activate`)
- UV and Ansible installed (see [Setup.md](Setup.md))

**Input**: User request with product name, version, and requirements from [IntentDiscovery.md](IntentDiscovery.md)

**Verification**: Before starting, verify environment is ready:
```bash
# Check if venv is activated
which python  # Should show .venv/bin/python

# Verify Ansible is available
ansible --version
ansible-galaxy --version
```

If verification fails, stop and direct user to complete [Setup.md](Setup.md) first.

**Process**: Bob searches for integration methods sequentially, selecting the first available option.

### 1.1 Search for API Documentation (PREFERRED METHOD)

Use browser tool to search for "{product name} API documentation"

**Search Strategy**:
- Search for official API documentation from vendor website
- Look for REST API guides, developer documentation, or API reference
- Prioritize official documentation over third-party sources
- Check for authentication sections and endpoint documentation

**If documentation found**:
- Navigate through documentation to find integration points
- Identify authentication methods (API key, OAuth, basic auth, etc.)
- Locate certificate/key discovery endpoints
- Extract request/response examples
- Document endpoint URLs, HTTP methods, and required parameters

**Update CHECKPOINT.md**:
```markdown
## Phase 1: Integration Method
- Product: [Product Name] [Version]
- Integration Method: API Documentation
- Documentation URL: [URL]
- Authentication Method: [method from docs]
- Discovery Endpoints: [list of endpoints]
```

**Proceed to Next Phase**:
- **Proceed to [DiscoveryPlugInGeneration.md](DiscoveryPlugInGeneration.md) with API Documentation approach**

**If documentation NOT found**:
- Proceed to section 1.2 (OpenAPI Specification search)

---

### 1.2 Search for OpenAPI Specification

**ONLY if no API documentation found in section 1.1**

Use browser tool to search internet for "{product name} OpenAPI spec"

**Search Strategy**:
- Search for "swagger.json", "openapi.json", or "openapi.yaml"
- Check vendor's GitHub repositories
- Look for API specification downloads on vendor website
- Check common paths like `/api/swagger.json` or `/api/openapi.yaml`

**If OpenAPI spec found**:
- Download the OpenAPI specification file
- Analyze endpoints, authentication methods, request/response schemas
- Identify certificate/key discovery endpoints
- Extract authentication schemes from `securitySchemes` section
- Document available operations and data models

**Update CHECKPOINT.md**:
```markdown
## Phase 1: Integration Method
- Product: [Product Name] [Version]
- Integration Method: OpenAPI Specification
- Spec File: [filename]
- Authentication Method: [method from spec]
- Discovery Endpoints: [list of endpoints]
```

**Proceed to Next Phase**:
- **Proceed to [DiscoveryPlugInGeneration.md](DiscoveryPlugInGeneration.md) with OpenAPI approach**

**If OpenAPI spec NOT found**:
- Proceed to section 1.3 (Ansible Collection search)

---

### 1.3 Search for Ansible Collection

**ONLY if no API documentation AND no OpenAPI spec found**

#### Search Strategy

Use `search_ansible_galaxy_collections` MCP tool with target system keywords.

**Iterate up to 5 times** with different keyword combinations to find official collection:
- Try primary keywords first (e.g., "hashicorp vault")
- Try vendor-specific keywords (e.g., "hashicorp", "vault")
- Try community keywords (e.g., "community vault")
- Prioritize collections from official namespaces (vendor name, `community.*`, `ansible.*`)
- Look for verified/certified badges in collection metadata
- **If a collection has high downloads but outdated `updated_at` timestamp** (e.g., not updated in >1 year): Continue searching through remaining keyword iterations to find a more recently maintained alternative before selecting

#### MCP Tool Failure Handling

**If MCP tool fails** (network error, timeout, tool unavailable):

1. Report the error to user with details
2. Ask user to choose next action:
   > "The MCP tool `search_ansible_galaxy_collections` failed due to [error reason].
   >
   > I can:
   > 1. **Retry the MCP tool** (Ask the user, Based on the approval preference)
   > 2. **Skip collection search** and proceed to user-provided method
   >
   > Which option would you prefer?"

3. Proceed based on user's choice:
   - Option 1: Retry MCP tool with same keywords
   - Option 2: Skip to section 1.4 (User-provided method)

#### Official Collection Criteria

- Namespace matches vendor name (e.g., `hashicorp.vault` for HashiCorp)
- Published by `community` namespace with high download count
- Marked as certified or verified in Galaxy
- **When multiple collections have similar download counts**: Check `updated_at` timestamp and prefer the most recently updated collection (indicates active maintenance)

#### Pre-Download Capability Verification

**CRITICAL**: Verify capabilities BEFORE downloading the collection.

1. Use browser action to navigate to collection documentation:
   ```
   https://galaxy.ansible.com/ui/repo/published/<namespace>/<collection>/docs/
   ```

2. Review the documentation in browser to check available modules

3. **If docs available**: Verify required capabilities:
   - Look for modules that can list/fetch certificates (e.g., `list_certificates`, `get_certificate`, `cert_info`)
   - Look for modules that can list/fetch keys (e.g., `list_keys`, `get_key`, `key_info`)
   - Look for modules that can list/fetch secrets (e.g., `list_secrets`, `read_secret`, `secret_info`)
   - Verify authentication methods match user's requirements
   - Check if modules support the asset types user requested (certificates/keys/protocols)

4. **Decision Point**:
   - **If docs available AND required capabilities found**: Proceed to download
   - **If docs NOT available online**: Proceed to download (will verify locally in post-download step)
   - **If docs available BUT required capabilities MISSING**:
     - Report to user: "Collection `<namespace>.<collection>` found but lacks required capabilities for [asset types]. Moving to user-provided method."
     - SKIP download
     - Proceed to section 1.4 (User-provided method)

#### Download and Setup Collection

**Only if pre-verification passed or docs unavailable**:

```bash
# Activate virtual environment
source .venv/bin/activate

# Install collection to local ansible_collections/ directory
ansible-galaxy collection install <namespace>.<collection>:<version> -p ./ansible_collections
```

#### MANDATORY VERIFICATION - Collection Download Success

- Use `list_files` tool to verify `ansible_collections/<namespace>/<collection>/` directory exists
- Verify at least one of these files exists in the collection directory:
  - `README.md` or `README.rst`
  - `docs/` directory
  - `plugins/` directory

**If verification fails**:
- STOP immediately
- Report error to user: "Collection download failed. Directory ansible_collections/<namespace>/<collection>/ not found or empty."
- Do NOT proceed to Phase 2
- Do NOT fall back to user-provided method
- Request user to check network connectivity or try manual installation

#### Post-Download Capability Verification

**Only if pre-verification was skipped due to unavailable online docs**:

1. Navigate to `ansible_collections/<namespace>/<collection>/`
2. Read `README.md` and files in `docs/` directory
3. List files in `plugins/modules/` directory to see available modules
4. Identify available modules for certificate/key/secret operations

5. **Decision Point**:
   - **If required capabilities found**: Continue to setup and analysis
   - **If required capabilities MISSING**:
     - Report to user: "Collection `<namespace>.<collection>` downloaded but lacks required capabilities for [asset types]."
     - Ask user: "Should I delete this collection and try user-provided method instead? (Yes/No)"
     - If user confirms YES:
       - Delete collection directory using `execute_command` with `rm -rf ansible_collections/<namespace>/<collection>`
       - Proceed to section 1.4 (User-provided method)
     - If user says NO: STOP and request user guidance

#### Setup Ansible Environment

**Only if capabilities verified**:

- Check collection dependencies in requirements.yaml
- Ensure all required Ansible modules are available

#### Analyze Collection Documentation

- Read collection README and documentation files
- Identify available modules for certificate/key discovery
- Understand module parameters and authentication methods
- Review example playbooks and usage patterns

#### Install Collection Python Dependencies

**After successful collection installation**, check for and install Python dependencies. Usually in the requirements.txt inside the ansible collection folder

**Important Notes**:
- Collection dependencies are installed into the same virtual environment (`.venv`)
- If `requirements.txt` doesn't exist, skip this step

#### Update CHECKPOINT.md

```markdown
## Phase 1: Integration Method
- Product: [Product Name] [Version]
- Integration Method: Ansible Collection
- Collection: <namespace>.<collection>:<version>
- Collection Path: ./ansible_collections/<namespace>/<collection>/
- Capabilities Verified: ✓ ([list of modules found])
- Authentication Method: [method from docs]
```

#### Proceed to Next Phase

**Proceed to [DiscoveryPlugInGeneration.md](DiscoveryPlugInGeneration.md) with Ansible Collection approach**

**If collection NOT found after 5 iterations**:
- Proceed to section 1.4 (User-provided method)

---

### 1.4 Request User-Provided Integration Method

**ONLY if no API documentation, OpenAPI spec, or Ansible collection found**

Ask user:
> "No API documentation, OpenAPI spec, or Ansible collection found. Please provide one of the following:
> - Ansible collection name (community/unofficial)
> - curl commands to interact with the target system
> - SSH commands for remote system access
> - Step-by-step integration instructions"

- Accept user input and analyze provided method
- **Proceed to [DiscoveryPlugInGeneration.md](DiscoveryPlugInGeneration.md) with user-provided approach**

---

## Output

Complete understanding of target system integration requirements and selected integration method.

## Next Phase

Once integration method is identified and verified:
- Proceed to [DiscoveryPlugInGeneration.md](DiscoveryPlugInGeneration.md) for playbook generation
- Carry forward all discovered information (API endpoints, OpenAPI spec, collection details, authentication methods)