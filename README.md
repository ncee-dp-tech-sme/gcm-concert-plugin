# IBM Concert Discovery Plugin for GCM

## Overview

This plugin enables IBM Guardium Cryptography Manager (GCM) to discover and inventory certificates from IBM Concert environments. IBM Concert is a hybrid cloud management platform that tracks certificates across multiple Kubernetes and OpenShift clusters.

## Features

- **Multi-Environment Discovery**: Automatically discovers certificates across all IBM Concert environments (dev, prod, qa, stage, etc.)
- **Environment Context**: Enriches certificate data with environment metadata (environment ID, name, type, cluster information)
- **IT Asset Relationships**: Maps certificates to their access points (hostnames and ports) for complete infrastructure visibility
- **Certificate Metadata**: Captures comprehensive certificate details including subject, issuer, serial number, validity dates, and DNS names
- **Issue Tracking Integration**: Includes information about open tickets linked to certificates in external systems (ServiceNow, Jira)

## Prerequisites

- IBM Guardium Cryptography Manager (GCM) instance
- IBM Concert Hybrid v2.3.0 or later
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

1. **Environment Discovery**: The plugin first fetches all environments from IBM Concert using the `/core/api/v1/environments` API endpoint

2. **Certificate Discovery**: For each environment, the plugin fetches all certificates using the `/core/api/v1/certificates?environment_id={id}` endpoint

3. **Data Enrichment**: Each certificate is enriched with:
   - Environment context (ID, name, type)
   - Cluster information
   - Access point details (hostnames and ports)
   - Issue tracking information

4. **Transformation**: Certificate data is transformed to GCM's standard format using Omniparser rules

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
- **Certificates**: X.509 certificates with full metadata
- **IT Assets**: Hostnames and ports where certificates are deployed
- **Relationships**: Mappings between certificates and IT assets

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

- `GET /core/api/v1/environments` - List all environments
- `GET /core/api/v1/certificates?environment_id={id}` - List certificates per environment

Both endpoints support pagination with `page_size` and `page_number` parameters (up to 2000 items per page).

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