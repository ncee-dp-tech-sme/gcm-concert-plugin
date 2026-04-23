# Ansible Playbook Generation Guide

## Overview

This document provides guidance for generating Ansible playbooks for GCM plugin integrations. The playbooks handle connection testing and asset discovery from target systems. The integration method (collection, OpenAPI, documentation, or user-provided) determines how the playbooks are constructed.

**All field names, endpoints, and module names in examples are placeholders. Replace them with actual values from the target system's collection documentation, OpenAPI spec, or API documentation.**

## Authentication Method Selection

Before writing any playbook, Bob must determine the correct authentication method from the integration source:

- **Collection**: Read the collection's authentication documentation and module parameters. The collection will specify supported auth methods (token, AppRole, AWS IAM, LDAP, etc.).
- **OpenAPI spec**: Check the `securitySchemes` section of the spec. This defines the exact auth mechanism (Bearer token, API key header name, OAuth2 flows, basic auth).
- **API documentation**: Navigate to the authentication section of the docs. Identify required headers, token formats, and credential fields.

After identifying the available auth methods, **Bob must confirm with the user**:
> "This integration supports the following authentication methods: [list from source]. Which method do you want to use?"

Use the user's selection to determine:
- Which credential fields to include in `integration-json-schema.json`
- How to pass credentials in the playbook (header name, module parameter, etc.)
- What to show in the UI schema (password fields, dropdowns, etc.)

**Do not assume or default to Bearer token or API key.** Always derive auth from the source and confirm with the user.

---

## Decision Tree: Which Approach to Use

```
1. Search for API Documentation (browser tool)
   └── Found documentation?
       YES → Navigate docs → Identify endpoints → Generate playbook using uri module
       NO  → Continue to step 2

2. Search for OpenAPI Specification (browser tool)
   └── Found OpenAPI spec?
       YES → Download spec → Analyze endpoints → Generate playbook using uri module
       NO  → Continue to step 3

3. Search for Ansible Collection (search_ansible_galaxy_collections MCP tool)
   └── Found official collection?
       YES → Download collection → Analyze docs → Generate playbook using collection modules
       NO  → Continue to step 4

4. Ask user to provide integration method
   └── User provides collection name / curl commands / SSH commands / steps
       → Generate playbook from user-provided information
```

**Priority order**: API Documentation > OpenAPI spec > Ansible Collection > User-provided

---

## CRITICAL: No Fallback Rule

**If Phase 1 selected Ansible Collection approach, you MUST use collection modules exclusively.**

Before generating any playbook:
1. Check if Phase 1 selected "Ansible Collection" approach
2. Verify collection files exist in `ansible_collections/<namespace>/<collection>/`
3. If collection files missing: STOP and report error
4. If collection files exist: Use ONLY collection modules (no uri, no API calls)

**Fallback to API/OpenAPI is ONLY allowed if Phase 1 found NO collection.**

When Phase 1 selects a collection:
- You MUST use collection modules for all operations
- You MUST NOT use the `uri` module
- You MUST NOT search for REST APIs or OpenAPI specs
- You MUST NOT fall back to API documentation
- If collection files are missing, STOP and report error (do not fall back)

---

## Approach 1: Using API Documentation (PREFERRED)

Use this when official API documentation is available for the target system.

### Setup

```bash
# Activate virtual environment
source .venv/bin/activate

# Install collection to local directory
ansible-galaxy collection install <namespace>.<collection>:<version> -p ./ansible_collections

# Install collection Python dependencies (if requirements.txt exists)
COLLECTION_PATH="ansible_collections/<namespace>/<collection>"
if [ -f "$COLLECTION_PATH/requirements.txt" ]; then
  uv pip install -r "$COLLECTION_PATH/requirements.txt"
fi
```

After installation, read the collection documentation before writing any playbook:
- `ansible_collections/<namespace>/<collection>/README.md`
- `ansible_collections/<namespace>/<collection>/docs/`
- Module parameter documentation and examples

**IMPORTANT**: API documentation should be the first choice when available. Use the `uri` module to make REST API calls based on the documented endpoints.

### test_connection.yaml (Collection-based)

```yaml
---
- name: Test Connection to Target System
  hosts: localhost
  gather_facts: no

  tasks:
    # Configuration is passed directly via --extra-vars by GCM
    # For test_connection, GCM flattens the integration config to root level
    # All fields are available as top-level variables
    - name: Initialize variables
      set_fact:
        out_dir: "{{ out_dir }}"
        status_file: "{{ out_dir }}/{{ status_file_name }}"

    - name: Create output directory
      file:
        path: "{{ out_dir }}"
        state: directory
        mode: '0755'

    - name: Test connection
      block:
        - name: Initialize status
          copy:
            content: |
              {
                "runId": "{{ run_id }}",
                "action": "{{ action }}",
                "status": "InProgress",
                "message": "Testing connection"
              }
            dest: "{{ status_file }}"

        # Replace this task with the appropriate collection module for the target system.
        # Use the collection's health check, auth validation, or list module.
        # Refer to the collection documentation for the correct module and parameters.
        # Access configuration fields directly as top-level variables (e.g., {{ api_key }}, {{ region }})
        - name: Test connection using collection module
          <namespace>.<collection>.<module>:
            <param1>: "{{ <field1> }}"
            <param2>: "{{ <field2> }}"
          register: connection_result

        - name: Update status - Success
          copy:
            content: |
              {
                "runId": "{{ run_id }}",
                "action": "{{ action }}",
                "status": "Success",
                "message": "Connection successful"
              }
            dest: "{{ status_file }}"

      rescue:
        - name: Update status - Failed
          copy:
            content: |
              {
                "runId": "{{ run_id }}",
                "action": "{{ action }}",
                "status": "Failed",
                "message": "Connection failed: {{ ansible_failed_result.msg | default('Unknown error') }}"
              }
            dest: "{{ status_file }}"

        - name: Fail the playbook
          fail:
            msg: "Connection test failed"
```

### discover.yaml (Collection-based)

`discover.yaml` is the main discovery playbook. It handles configuration loading, output directory creation, iterating over integration instances, and writing the final status.

**Helper File Rule**: When per-instance logic requires error handling (block/rescue), you MUST create a helper file and use `include_tasks` with the loop.

**Main playbook structure** (`discover.yaml`):
```yaml
---
- name: Discover Assets from Target System
  hosts: localhost
  gather_facts: no

  tasks:
    - name: Initialize discovery
      block:
        # Configuration is passed directly via --extra-vars by GCM
        # For discovery, GCM passes full structure with pluginConfig.integration array
        - name: Initialize variables
          set_fact:
            out_dir: "{{ out_dir }}"
            status_file: "{{ out_dir }}/{{ status_file_name }}"
            config_list: "{{ pluginConfig.integration }}"

        - name: Create output directory
          file:
            path: "{{ out_dir }}"
            state: directory
            mode: '0755'

        - name: Initialize counters
          set_fact:
            total_instances: "{{ pluginConfig.integration | length | int }}"
            successful_instances: "0"
            failed_instances: "0"
            total_assets: "0"

    # Process each integration instance using include_tasks
    # This allows proper error handling per instance with block/rescue
    - name: Process each integration instance
      include_tasks: process_instance.yaml
      loop: "{{ pluginConfig.integration }}"
      loop_control:
        loop_var: instance
        index_var: instance_index
      no_log: true

    - name: Generate final summary
      block:
        - name: Update final status
          copy:
            content: |
              {
                "runId": "{{ run_id }}",
                "action": "{{ action }}",
                "status": "Success",
                "message": "Discovery completed",
                "fileFormat": "json",
                "outputFiles": {{ output_files.files | map(attribute='path') | list | to_json }},
                "details": {
                  "total_instances": {{ total_instances }},
                  "successful_instances": {{ successful_instances }},
                  "failed_instances": {{ failed_instances }},
                  "total_assets_discovered": {{ total_assets }}
                }
              }
            dest: "{{ status_file }}"

      rescue:
        - name: Update failure status
          copy:
            content: |
              {
                "runId": "{{ run_id }}",
                "action": "{{ action }}",
                "status": "Failed",
                "message": "Discovery failed: {{ ansible_failed_result.msg | default('Unknown error') }}"
              }
            dest: "{{ status_file }}"
```

**Helper file structure** (`src/discovery/process_instance.yaml`):
```yaml
---
# Helper file to process discovery for a single integration instance
# This file is included by discover.yaml with loop_var: instance
# Access instance configuration fields via {{ instance.field_name }}

- name: Process discovery for instance
  block:
    - name: Update status - processing
      copy:
        content: |
          {
            "runId": "{{ run_id }}",
            "action": "{{ action }}",
            "status": "InProgress",
            "message": "Discovering assets from instance {{ instance_index + 1 }}"
          }
        dest: "{{ out_dir }}/{{ status_file_name }}"

    # Replace this task with the appropriate collection module call(s) to fetch assets.
    # Refer to the collection documentation for the correct module and parameters.
    # Access configuration fields via instance variable (e.g., {{ instance.api_key }}, {{ instance.region }})
    - name: Fetch assets using collection module
      <namespace>.<collection>.<module>:
        <param1>: "{{ instance.<field1> }}"
        <param2>: "{{ instance.<field2> }}"
      register: fetch_result
      no_log: true

    # Write one output file per discovered asset.
    - name: Write asset output files
      copy:
        content: "{{ asset | to_nice_json }}"
        dest: "{{ out_dir }}/crypto_asset_details_{{ instance_index }}_{{ asset_index }}.json"
      loop: "{{ fetch_result.<assets_field> }}"
      loop_control:
        loop_var: asset
        index_var: asset_index

    - name: Update counters
      set_fact:
        total_assets: "{{ (total_assets | int) + (fetch_result.<assets_field> | length) }}"
        successful_instances: "{{ (successful_instances | int) + 1 }}"

  rescue:
    - name: Update failed counter
      set_fact:
        failed_instances: "{{ (failed_instances | int) + 1 }}"

    - name: Log error
      debug:
        msg: "Discovery failed for instance {{ instance_index }}: {{ ansible_failed_result.msg | default(ansible_failed_result | string) }}"
```

---

## Approach 2: Using OpenAPI Specification

Use this ONLY when no API documentation is available for the target system.

### How to obtain the OpenAPI spec

Use the browser tool to search for `<product name> OpenAPI spec` or `<product name> swagger.json`. Download the spec file and analyze:
- Available endpoints for listing/fetching certificates, keys, or secrets
- Authentication schemes (Bearer token, API key header, basic auth, OAuth)
- Request parameters and response schemas for discovery endpoints
- Pagination patterns (page/limit, cursor, offset)

### test_connection.yaml (OpenAPI-based)

```yaml
---
- name: Test Connection to Target System
  hosts: localhost
  gather_facts: no

  tasks:
    # Configuration is passed directly via --extra-vars by GCM
    # For test_connection, GCM flattens the integration config to root level
    # All fields are available as top-level variables
    - name: Initialize variables
      set_fact:
        out_dir: "{{ out_dir }}"
        status_file: "{{ out_dir }}/{{ status_file_name }}"

    - name: Create output directory
      file:
        path: "{{ out_dir }}"
        state: directory
        mode: '0755'

    - name: Test connection
      block:
        - name: Initialize status
          copy:
            content: |
              {
                "runId": "{{ run_id }}",
                "action": "{{ action }}",
                "status": "InProgress",
                "message": "Testing connection"
              }
            dest: "{{ status_file }}"

        # Use the health check, ping, or auth validation endpoint from the OpenAPI spec.
        # Replace the url, method, headers, and status_code with values from the spec.
        # Access configuration fields directly as top-level variables
        - name: Test API connectivity
          uri:
            url: "{{ <base_url_field> }}/<health_or_auth_endpoint>"
            method: GET
            headers:
              <auth_header_name>: "{{ <credential_field> }}"
            validate_certs: "{{ verifySsl | default(true) }}"
            status_code: [200]
          register: api_response
          no_log: true

        - name: Update status - Success
          copy:
            content: |
              {
                "runId": "{{ run_id }}",
                "action": "{{ action }}",
                "status": "Success",
                "message": "Connection successful"
              }
            dest: "{{ status_file }}"

      rescue:
        - name: Update status - Failed
          copy:
            content: |
              {
                "runId": "{{ run_id }}",
                "action": "{{ action }}",
                "status": "Failed",
                "message": "Connection failed: {{ ansible_failed_result.msg | default('Unknown error') }}"
              }
            dest: "{{ status_file }}"

        - name: Fail the playbook
          fail:
            msg: "Connection test failed"
```

### discover.yaml structure note (OpenAPI-based)

`discover.yaml` is the primary and often only playbook needed. Apply the same **Helper File Rule** as described in the Collection-based approach above.

---

## Approach 3: Using Ansible Collection

Use this ONLY when no API documentation and no OpenAPI spec is available.

### How to obtain the collection

Use the `search_ansible_galaxy_collections` MCP tool to search for `<product name>` keywords. Navigate through the collection documentation to find:
- Authentication method and required module parameters
- Modules for listing certificates, keys, or secrets
- Module response format and field names
- Pagination mechanism

The playbook structure uses collection modules exclusively. Replace the placeholder values with actual module names and parameters found in the collection documentation.

---

## Approach 4: User-Provided Commands

Use this ONLY when no API documentation, OpenAPI spec, or Ansible collection is found.

Ask the user:
> "No API documentation, OpenAPI spec, or Ansible collection was found for this product. Please provide one of the following so I can generate the integration playbook:
> - Ansible collection name (official or community)
> - curl commands that list/fetch the target assets
> - SSH commands for remote system access
> - Step-by-step instructions for connecting and retrieving assets"

Convert the provided information:
- `curl` commands → `uri` module tasks
- `ssh` commands → `command` or `shell` module tasks
- Step-by-step instructions → sequential Ansible task blocks

---

## Common Patterns

### Configuration Loading

**GCM uses TWO DIFFERENT configuration passing methods** depending on the action:

#### For test_connection.yaml (Single Instance)
GCM flattens the integration config to root level. All configuration fields are available as top-level variables.

**Configuration file** (`config/test_connection_config.json`):
```json
{
  "run_id": "test-123",
  "action": "integration.test_connection",
  "out_dir": "./test_output",
  "status_file_name": "status.json",
  "region": "us-east-1",
  "access_key_id": "key",
  "secret_access_key": "secret",
  "verifySsl": true
}
```

**Execution:**
```bash
ansible-playbook test_connection.yaml --extra-vars '@config/test_connection_config.json'
```

**Playbook access pattern:**
```yaml
tasks:
  # All fields available as top-level variables
  - name: Use configuration
    debug:
      msg: "Region: {{ region }}"
      msg: "Key: {{ access_key_id }}"
```

#### For discover.yaml (Multiple Instances)
GCM passes the full nested structure with `pluginConfig.integration` array to support multiple integration instances.

**Configuration file** (`config/test_config.json`):
```json
{
  "run_id": "test-123",
  "action": "discovery.discover",
  "out_dir": "./test_output",
  "status_file_name": "status.json",
  "pluginConfig": {
    "integration": [
      {
        "region": "us-east-1",
        "access_key_id": "key",
        "secret_access_key": "secret"
      }
    ]
  }
}
```

**Execution:**
```bash
ansible-playbook discover.yaml --extra-vars '@config/test_config.json'
```

**Playbook access pattern:**
```yaml
tasks:
  # Top-level fields: {{ run_id }}, {{ action }}, {{ out_dir }}, {{ status_file_name }}
  # Integration array: {{ pluginConfig.integration }}
  
  - name: Set config list
    set_fact:
      config_list: "{{ pluginConfig.integration }}"
  
  - name: Process each instance
    include_tasks: process_instance.yaml
    loop: "{{ pluginConfig.integration }}"
    loop_control:
      loop_var: instance
    no_log: true
```

**In helper file (process_instance.yaml):**
```yaml
# Access instance fields via loop variable
- name: Use instance configuration
  debug:
    msg: "Region: {{ instance.region }}"
    msg: "Key: {{ instance.access_key_id }}"
```

### Output Directory

The output directory location is determined by the `out_dir` field in the configuration file. Playbooks create this directory and write all output files to it.

**Example configuration**:
```json
{
  "out_dir": "./test_output",
  "status_file_name": "status.json"
}
```

This creates output files at `src/discovery/test_output/crypto_asset_details_*.json` (relative to the playbook execution directory `src/discovery/`).

### Status File Updates

```yaml
# InProgress
- name: Update status
  copy:
    content: |
      {
        "runId": "{{ run_id }}",
        "action": "{{ action }}",
        "status": "InProgress",
        "message": "Discovering assets"
      }
    dest: "{{ out_dir }}/{{ status_file_name }}"

# Success
- name: Update status - Success
  copy:
    content: |
      {
        "runId": "{{ run_id }}",
        "action": "{{ action }}",
        "status": "Success",
        "message": "Discovery completed",
        "fileFormat": "json",
        "outputFiles": {{ output_files.files | map(attribute='path') | list | to_json }}
      }
    dest: "{{ out_dir }}/{{ status_file_name }}"

# Failed
- name: Update status - Failed
  copy:
    content: |
      {
        "runId": "{{ run_id }}",
        "action": "{{ action }}",
        "status": "Failed",
        "message": "{{ ansible_failed_result.msg | default('Unknown error') }}"
      }
    dest: "{{ out_dir }}/{{ status_file_name }}"
```

### Output File Naming

Asset output files must follow this naming convention:

```
crypto_asset_details_<instance_index>_<asset_index>.json
```

- `instance_index`: Zero-based index of the integration instance (from loop_control)
- `asset_index`: Zero-based index of the asset within that instance

```yaml
# In process_instance.yaml (called with loop_var: instance, index_var: instance_index)
- name: Write asset files
  copy:
    content: "{{ asset | to_nice_json }}"
    dest: "{{ out_dir }}/crypto_asset_details_{{ instance_index }}_{{ asset_index }}.json"
  loop: "{{ discovered_assets }}"
  loop_control:
    loop_var: asset
    index_var: asset_index
```

**Example output files:**
- `crypto_asset_details_0_0.json` - First asset from first instance
- `crypto_asset_details_0_1.json` - Second asset from first instance
- `crypto_asset_details_1_0.json` - First asset from second instance

### IT Asset Discovery

**Always attempt to discover IT assets** (hostname, IP, port, service) when available from the target system. Include this information in the crypto object output for relationship mapping during transformation.

**Pattern**: Include IT asset fields in output when available
```yaml
- name: Write crypto asset with IT context
  copy:
    content: |
      {
        "certificate_data": "{{ cert.pem }}",
        "subject": "{{ cert.subject }}",
        "ip": "{{ cert.ip | default('') }}",
        "hostname": "{{ cert.hostname | default('') }}",
        "port": "{{ cert.port | default('') }}",
        "protocol": "{{ cert.protocol | default('') }}"
      }
    dest: "{{ out_dir }}/crypto_asset_details_{{ instance_index }}_{{ asset_index }}.json"
```

**Note**: Discovery will not fail if IT asset data is unavailable (e.g., HashiCorp Vault only stores crypto objects).

### Pagination

When the target API returns paginated results, use a loop with a termination condition:

```yaml
- name: Initialize pagination
  set_fact:
    current_page: 1
    has_more: true
    all_assets: []

- name: Fetch all pages
  include_tasks: fetch_page.yaml
  loop: "{{ range(1, 1000) | list }}"
  loop_control:
    loop_var: page_num
  when: has_more
```

In `fetch_page.yaml`, update `has_more` and `all_assets` based on the API response. The exact pagination fields depend on the target API.

### Authentication Patterns

The authentication pattern to use is determined by the integration source (collection docs, OpenAPI spec, or API docs) and confirmed with the user before writing any playbook. Common implementation patterns are shown below for reference — use only the one that matches the confirmed auth method:

**For test_connection.yaml** (fields are flattened to root level):
```yaml
# Bearer token (when API uses Authorization: Bearer header)
headers:
  Authorization: "Bearer {{ <token_field> }}"

# API key in custom header (header name comes from the API spec)
headers:
  <api_key_header_name>: "{{ <api_key_field> }}"

# Basic auth (username + password)
url_username: "{{ <username_field> }}"
url_password: "{{ <password_field> }}"

# Client certificate (mutual TLS)
client_cert: "{{ <cert_field> }}"
client_key: "{{ <key_field> }}"

# Collection-specific auth (parameters vary by collection module)
<auth_param_from_collection_docs>: "{{ <credential_field> }}"
```

**For discover.yaml / process_instance.yaml** (access via instance variable):
```yaml
# Bearer token
headers:
  Authorization: "Bearer {{ instance.<token_field> }}"

# API key in custom header
headers:
  <api_key_header_name>: "{{ instance.<api_key_field> }}"

# Basic auth
url_username: "{{ instance.<username_field> }}"
url_password: "{{ instance.<password_field> }}"

# Client certificate
client_cert: "{{ instance.<cert_field> }}"
client_key: "{{ instance.<key_field> }}"

# Collection-specific auth
<auth_param_from_collection_docs>: "{{ instance.<credential_field> }}"
```

The field names (`<token_field>`, `<api_key_field>`, etc.) must match the fields defined in `config/integration/integration-json-schema.json`. These field names are determined after confirming the auth method with the user.

---

## Error Handling

All API calls and collection module calls must use the `block/rescue` pattern:

```yaml
- name: Perform operation
  block:
    - name: Execute task
      <module>:
        <params>
      register: result

  rescue:
    - name: Handle failure
      set_fact:
        failed_instances: "{{ failed_instances | int + 1 }}"

    - name: Log error
      debug:
        msg: "Operation failed: {{ ansible_failed_result.msg | default('Unknown error') }}"
```

For retries on transient failures:

```yaml
- name: Execute with retry
  <module>:
    <params>
  register: result
  retries: 3
  delay: 5
  until: result is succeeded
```

---

## Security

- Always use `no_log: true` on tasks that handle credentials
- Never use `debug` to print credential values
- Sanitize error messages before writing to status file:
  ```yaml
  - name: Sanitize error
    set_fact:
      safe_error: "{{ ansible_failed_result.msg | default('Unknown error') | regex_replace('(?i)(token|key|password|secret)=[^\\s&]*', '\\1=***') }}"
  ```
- Clear sensitive variables after use:
  ```yaml
  - name: Clear credentials
    set_fact:
      integration_config: {}
  ```

---

## Testing

```bash
# Activate virtual environment
source .venv/bin/activate
```

### Local Testing with Separate Config Files

For local testing, use the `--extra-vars` format with the `@` prefix to load from file. Bob will create two separate config files to match GCM's behavior:

**Linux/macOS**:
```bash
# Test connection (uses flattened config)
ansible-playbook src/integration/test_connection.yaml \
  --extra-vars "@config/test_connection_config.json"

# Run discovery (uses nested config)
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

### Test Configuration Files

**config/test_connection_config.json** (Flattened structure for test_connection):
```json
{
  "run_id": "test-123",
  "action": "integration.test_connection",
  "out_dir": "./test_output",
  "status_file_name": "status.json",
  "region": "us-east-1",
  "access_key_id": "your-key",
  "secret_access_key": "your-secret",
  "verifySsl": true
}
```

**config/test_config.json** (Nested structure for discovery):
```json
{
  "run_id": "test-123",
  "action": "discovery.discover",
  "out_dir": "./test_output",
  "status_file_name": "status.json",
  "pluginConfig": {
    "integration": [
      {
        "region": "us-east-1",
        "access_key_id": "your-key",
        "secret_access_key": "your-secret",
        "verifySsl": true
      }
    ]
  }
}
```

### Verify Output Files

```bash
# Output files are in src/discovery/test_output
ls src/discovery/test_output/crypto_asset_details_*.json

# View first output file
cat src/discovery/test_output/crypto_asset_details_0_0.json | jq .
```

**Note**: Since the playbook runs from `src/discovery/`, the config's `"out_dir": "./test_output"` creates files in `src/discovery/test_output`.

Do not proceed to transformation creation until these files exist and contain real data from the target system.

---

## Next Phase

Once playbooks are generated:
- Proceed to [DiscoveryPluginTest.md](DiscoveryPluginTest.md) for testing and validation
- Ensure playbooks execute successfully before moving to transformation creation