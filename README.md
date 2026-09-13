# IBM Concert Discovery Plugin for GCM

## Overview

This plugin enables IBM Guardium Cryptography Manager (GCM) to discover and inventory both certificates and IT assets (access points) from IBM Concert environments. IBM Concert is a hybrid cloud management platform that tracks certificates and application endpoints across multiple Kubernetes and OpenShift clusters.

## Features

- **Multi-Environment Discovery**: Automatically discovers certificates and IT assets across all IBM Concert environments (dev, prod, qa, stage, etc.)
- **IT Asset Discovery**: Discovers application access points (endpoints/hostnames) with protocol, port, and application context
- **Environment Context**: Enriches both certificate and IT asset data with environment metadata (environment ID, name, type, cluster information)
- **Certificate-to-IT Asset Relationships**: Maps certificates to their access points (hostnames and ports) for complete infrastructure visibility
- **Certificate Metadata**: Captures comprehensive certificate details including subject, issuer, serial number, validity dates, and DNS names
- **Issue Tracking Integration**: Includes information about open tickets linked to certificates in external systems (ServiceNow, Jira)
- **Application Context**: Links IT assets to their parent applications for better organization and tracking

## Prerequisites

- IBM Guardium Cryptography Manager (GCM) instance
- IBM Concert 3.0.0 or later (for v2.x of this plugin)
- IBM Concert Hybrid v2.3.0+ supported by plugin v1.x
- IBM Concert API credentials:
  - Server URL (HTTPS)
  - API Key
  - Instance ID

## Configuration

### Required Fields

1. **Server URL**: The base URL of your IBM Concert instance
   - Format: `https://your-instance.concert.saas.ibm.com`
   - Must use HTTPS protocol

2. **API Key**: IBM Concert API key for authentication
   - Obtained from IBM Concert settings
   - Used in `Authorization: C_API_KEY {key}` header

3. **Instance ID**: IBM Concert instance identifier
   - Format: UUID (e.g., `20240826-1930-2047-8140-78cf45ec64dc`)
   - Sent in `InstanceId` header for API requests

### Optional Fields

4. **Verify SSL**: Enable/disable SSL certificate verification
   - Default: `true` (recommended)
   - Set to `false` only for testing with self-signed certificates

## How It Works

### Discovery Process

1. **Environment Discovery**: The plugin fetches all environments from IBM Concert using the `/core/api/v1/environments` endpoint

2. **Certificate Discovery**: For each environment, fetches all certificates using `/core/api/v1/certificates?environment_id={id}`

3. **IT Asset Discovery**: For each environment, fetches access points using `/core/api/v1/environments/{env_id}/access_points` — one call per environment, no application loop required

4. **Data Enrichment**:
   - **Certificates** are enriched with:
     - Environment context (ID, name, type)
     - Cluster information
     - Access point details (hostnames and ports)
     - Issue tracking information
   
   - **IT Assets** are enriched with:
     - Environment context (ID, name) — provided directly in the API response
     - Environment type — added from the environment loop variable
     - Endpoint details (protocol, hostname, port)
     - Public/private access indicators

6. **Transformation**: Both certificate and IT asset data are transformed to GCM's standard format using Omniparser rules

### API Authentication

IBM Concert uses a custom authentication scheme:
- **Authorization Header**: `C_API_KEY {api_key}`
- **Instance ID Header**: `InstanceId: {instance_id}`

Both headers are required for all API requests.

### Data Mapping

| IBM Concert Field | GCM Field | Notes |
|-------------------|-----------|-------|
| `subject` | `subject` | Certificate subject DN |
| `issuer` | `issuer` | Certificate issuer DN |
| `serial_number` | `certificate_serial_number` | Converted to integer |
| `validity_start_date` | `not_before` | Unix timestamp → ISO 8601 |
| `validity_end_date` | `not_after` | Unix timestamp → ISO 8601 |
| `dns_names` | `san` | Comma-separated → Array of DNS SANs |
| `environment_id` | `metadata.concert_environment_id` | Environment UUID |
| `environment_name` | `metadata.concert_environment_name` | Environment name (dev/prod/qa/stage) |
| `environment_type` | `metadata.concert_environment_type` | Environment type (GKE/OpenShift/etc) |
| `cluster_name` | `metadata.concert_cluster_name` | Kubernetes cluster name |
| `access_points` | `relationships` | IT asset relationships (hostname:port) |

## Installation

1. Upload the plugin zip file to GCM
2. Navigate to Plugin Management in GCM
3. Install the IBM Concert Discovery plugin
4. Configure integration profile with your IBM Concert credentials

## Usage

### Creating an Integration Profile

1. In GCM, navigate to Integration Profiles
2. Create a new profile and select "IBM Concert Discovery"
3. Enter your IBM Concert credentials:
   - Server URL
   - API Key
   - Instance ID
4. Test the connection
5. Save the profile

### Running Discovery

1. Navigate to Discovery in GCM
2. Select your IBM Concert integration profile
3. Click "Discover Now"
4. Monitor the discovery progress
5. View discovered certificates in the GCM inventory

### Discovered Assets

The plugin discovers:
- **Certificates**: X.509 certificates with full metadata and environment context
- **IT Assets**: Application access points (endpoints) with:
  - Hostname/URL
  - Protocol (HTTP/HTTPS)
  - Port number
  - Environment name and type
  - Public/private access indicator
  - Endpoint paths
- **Relationships**: Mappings between certificates and IT assets for infrastructure visibility

## Certificate Metadata

Each discovered certificate includes:

### Core Certificate Data
- Subject DN
- Issuer DN
- Serial number
- Validity period (not before/not after dates)
- DNS Subject Alternative Names (SANs)
- Certificate status (active/expired)

### IBM Concert Context
- Environment ID and name
- Environment type (GKE, OpenShift, etc.)
- Cluster name
- Kubernetes namespaces
- Archive status
- Last updated timestamp and user

### Issue Tracking
- Open ticket status
- Linked issues (ServiceNow, Jira)
- Issue IDs and URLs

### IT Asset Relationships
- Access points (hostname:port combinations)
- Public/private endpoint indicators

## Troubleshooting

### Connection Test Fails

**Problem**: "Connection failed" error during test connection

**Solutions**:
1. Verify server URL is correct and uses HTTPS
2. Check API key is valid and not expired
3. Confirm instance ID matches your IBM Concert instance
4. Verify network connectivity to IBM Concert server
5. Check SSL certificate verification setting

### No Certificates Discovered

**Problem**: Discovery completes but no certificates found

**Solutions**:
1. Verify your IBM Concert instance has certificates
2. Check API key has sufficient permissions to list environments and certificates
3. Review discovery logs for API errors
4. Confirm environments exist in IBM Concert

### Authentication Errors

**Problem**: "401 Unauthorized" or "403 Forbidden" errors

**Solutions**:
1. Regenerate API key in IBM Concert settings
2. Verify instance ID is correct
3. Check API key permissions include certificate read access

### SSL Certificate Errors

**Problem**: SSL verification failures

**Solutions**:
1. For production: Install IBM Concert's CA certificate in GCM
2. For testing only: Set "Verify SSL" to `false`
3. Verify IBM Concert server certificate is valid

## API Endpoints Used

### Certificate Discovery
- `GET /core/api/v1/environments` — List all environments
- `GET /core/api/v1/certificates?environment_id={id}` — List certificates per environment (paginated)

### IT Asset Discovery
- `GET /core/api/v1/environments/{env_id}/access_points` — List access points per environment (paginated)

All endpoints support pagination with `page_size` and `page_number` parameters (up to 2000 items per page).

> **Note**: Plugin v1.x used the incorrect `/concert/core/api/v1/` URL prefix and a more complex app×environment loop. Both issues are resolved in v2.0.0.

## Limitations

- **No PEM Material**: IBM Concert API does not provide certificate PEM data, so the plugin discovers certificate metadata only
- **Read-Only**: This plugin only discovers certificates; it does not manage or modify them
- **API Rate Limits**: Subject to IBM Concert API rate limits (contact IBM for details)

## Support

For issues or questions:
1. Check GCM plugin logs for detailed error messages
2. Review IBM Concert API documentation
3. Contact IBM Support with plugin version and error details

## Version History

### 2.0.2 (2026-09-12) — Pagination Timeout Fix
- **Critical Fix**: Resolved discovery timeouts caused by all 1000 loop iterations firing regardless of actual page count
  - Root cause: Ansible evaluates `when:` on `include_tasks` **once before the loop starts**, not before each iteration. So setting `has_more_pages: false` inside the page helper had no effect on the already-committed loop — every environment triggered 1000 API calls
  - Fix: Removed `when: has_more_pages | bool` from the `include_tasks` call in both `fetch_environment_certificates.yaml` and `fetch_application_access_points.yaml`; added `when: has_more_pages | bool` to **every individual task** inside `fetch_environment_certificates_page.yaml` and `fetch_application_access_points_page.yaml` so the guard is re-evaluated on each iteration

### 2.0.1 (2026-09-11) — Pagination Bug Fix
- **Critical Fix**: Resolved infinite loop / `exit status 1` crash in discovery
  - Root cause: `fetch_environment_certificates.yaml` and `fetch_application_access_points.yaml` implemented pagination by calling `include_tasks: <themselves>`, which re-ran the file from the top on every page, resetting `current_page` to `1` and the accumulator lists to `[]` — creating an infinite loop
  - Fix: Replaced recursive self-calls with a bounded `loop: range(1, 1001)` that delegates each page fetch to new dedicated page-helper files
  - New helpers: `fetch_environment_certificates_page.yaml` and `fetch_application_access_points_page.yaml`
  - The loop exits early via `when: has_more_pages | bool` once the final page is reached

### 2.0.0 (2026-09-11) — Concert 3.0+ Migration
- **Breaking Change**: Minimum supported Concert version is now 3.0.0
- **Critical Fix**: Corrected access point API URL — the previous `/concert/core/api/v1/` prefix was invalid and caused all IT asset discovery to silently fail via the rescue block
- **Simplified IT Asset Discovery**: Replaced the application × environment Cartesian product loop with a single environment-scoped endpoint `/core/api/v1/environments/{id}/access_points`, reducing API calls from O(apps×envs) to O(envs)
- **Removed `application_id`/`application_name`**: These fields are no longer provided by the environment-scoped access point endpoint and have been removed from IT asset metadata
- **Environment context now native**: `environment_id` and `environment_name` are returned directly on each access point in the Concert 3.0 API; client-side enrichment for these fields removed

### 1.2.3 (2026-04-25)
- **Critical Fix**: IT asset files now properly included in GCM processing
  - Fixed: IT asset discovery was creating files but GCM wasn't processing them
  - Root cause: discover.yaml only looked for `crypto_asset_details_*.json` files
  - Solution: Updated discover.yaml to find both certificate and IT asset output files
  - Now properly discovers and transforms both certificates AND IT assets (access points)
  - IT assets include hostname, protocol, port, and application context from Concert

### 1.2.2 (2026-04-25)
- **Critical Fix**: Wrapped all IT asset JavaScript functions with skip_on_missing_field
  - Fixed: `'FINAL_OUTPUT.port.custom_func(javascript)' failed: result is null` error
  - Root cause: JavaScript functions (hostname, protocol, port) were executing on certificate files
  - Solution: Wrapped each JavaScript function with skip_on_missing_field checking for host field
  - Added null checks inside JavaScript functions as additional safety
  - Now properly skips IT asset transformation when processing certificate files

### 1.2.1 (2026-04-24)
- **Fix**: Reverted to single transformation file with transformation_list array
  - GCM manifest schema does not support array for transformation field
  - Combined both transformations in `transform_discover.json` with transformation_list array

### 1.2.0 (2026-04-24)
- **Attempted Fix**: Tried separate transformation files (reverted in 1.2.1)
  - GCM manifest schema validation failed: "found a list, want object"

### 1.1.6 (2026-04-24)
- **Bug Fix**: Attempted to remove null checks (did not work)
  - GCM still evaluated all fields regardless of skip_on_missing_field

### 1.1.5 (2026-04-24)
- **Bug Fix**: Attempted to add null checks inside JavaScript functions (did not work)
  - Added `if (!host) return ''` checks but GCM still evaluated other fields
  - Issue: GCM evaluates all fields regardless of skip_on_missing_field on uri

### 1.1.4 (2026-04-24)
- **Bug Fix**: Attempted to wrap JavaScript functions with skip_on_missing_field (did not work)
  - Issue: skip_on_missing_field checks result after JavaScript executes, not before
  - JavaScript still executed and returned null, causing errors

### 1.1.3 (2026-04-24)
- **Bug Fix**: Reverted XPath predicate approach (not supported by GCM Omniparser)
  - Removed invalid XPath syntax `.[?(@.subject)]` and `.[?(@.host)]`
  - Added `skip_on_missing_field` to IT asset `uri` field to skip certificate files
  - Certificate transformation already has `skip_on_missing_field` on required fields
  - Both transformations now use simple `"xpath": "."` with field-level skipping
  - Resolves schema validation error: `'FINAL_OUTPUT.xpath' (value: '.[?(@.subject)]') is invalid`

### 1.1.2 (2026-04-24)
- **Bug Fix**: Attempted conditional XPath filters (reverted in 1.1.3)
  - XPath predicate syntax not supported by GCM Omniparser
  - Caused schema validation errors

### 1.1.1 (2026-04-24)
- **Bug Fix**: Corrected transformation file structure
  - Merged certificate and IT asset transformations into single `transform_discover.json` file
  - Both transformations now in `transformation_list` array with different `yields` values
  - Updated manifest to reference single transformation file
  - Follows GCM best practices for multi-asset type discovery
  - Resolves IT asset discovery issues where assets were not being processed

### 1.1.0 (2026-04-24)
- **New Feature**: IT Asset Discovery
  - Added discovery of application access points (endpoints) from IBM Concert
  - Discovers hostnames, protocols, ports, and endpoint paths
  - Links IT assets to applications and environments
  - Includes public/private access indicators
  - Creates relationships between certificates and IT assets
- **Enhancement**: Multi-asset type discovery
  - Plugin now discovers both certificates and IT assets in a single run
  - Separate transformation rules for each asset type
  - Improved data enrichment with application context

### 1.0.3 (2026-04-24)
- **Bug Fix**: Fixed data type and validation issues
  - Changed `certificate_serial_number` from int to string to handle large serial numbers
  - Added `Array.isArray()` check in relationships JavaScript to prevent map errors
  - Resolves "value out of range" error for large serial numbers
  - Resolves "Object has no member 'map'" error in relationships transformation

### 1.0.2 (2026-04-24)
- **Bug Fix**: Fixed transformation schema structure
  - Added required `transformation_list` wrapper array
  - Added `format` and `yields` fields for GCM compatibility
  - Resolves "incorrect transformation schema" error in GCM UI and discovery

### 1.0.1 (2026-04-24)
- **Bug Fix**: Added `userId` field to transformation
  - Maps to `last_updated_by` from IBM Concert certificate data
  - Required by GCM for asset tracking and audit purposes
  - Resolves "userId cannot be nil or empty" error during discovery

### 1.0.0 (Initial Release)
- Multi-environment certificate discovery
- Environment context enrichment
- IT asset relationship mapping
- Issue tracking integration
- Support for IBM Concert Hybrid v2.3.0+

## License

This plugin is provided as-is for use with IBM Guardium Cryptography Manager.