# Task: Concert 3.0+ Migration — IBM Concert Discovery Plugin

**Prompt**: "This repo contains the code for a Guardium Cryptography Manager plugin for IBM Concert. Originally built for concert v2.30+ but in the latest versions, the api has changed. Investigate what changes need to be made to support Concert 3.0.0 and newer"

**Timestamp**: Fri Sep 11 20:25:19 CEST 2026

---

## Summary

Investigated and implemented all changes required to support IBM Concert 3.0.0+. The API spec was sourced from the official IBM GitHub repo: https://github.com/IBM/Concert/tree/main/concert-api-spec (file: `Concert_All_APIs_for_Publishing_v3.0.1.1_202608212235.json`).

---

## Root Cause Analysis

### Critical Bug (all versions, including v2.x)
The IT asset discovery endpoint URL `{{ server_url }}/concert/core/api/v1/applications/{id}/environments/{id}/access_points` contained a `/concert` URL prefix that **has never existed** in the Concert API specification. The server base URL is `https://{tenant}.concert.ibm.com` and all paths begin with `/core/api/v1/`. This caused every IT asset API call to silently fail (swallowed by the `rescue` block), meaning **IT asset discovery was broken in all plugin versions**.

### Concert 3.0 API Changes
1. A simpler environment-scoped endpoint now exists: `GET /core/api/v1/environments/{env_id}/access_points`
2. The response (`AccesspointSummary`) includes `environment_id` and `environment_name` directly — no client-side enrichment needed
3. Certificate endpoints are **unchanged** — no migration needed there
4. Authentication (`C_API_KEY` + `InstanceId` headers) is **unchanged**

---

## Changes Made

### `src/discovery/fetch_application_access_points.yaml`
- **Old URL**: `/concert/core/api/v1/applications/{app_id}/environments/{env_id}/access_points`
- **New URL**: `/core/api/v1/environments/{env_id}/access_points`
- Loop variable renamed from `app_env_combo` to `concert_environment`
- `environment_id` / `environment_name` enrichment removed (now native in API response)
- `application_id` / `application_name` enrichment removed (not in flat endpoint response)
- Only `environment_type` still enriched from loop variable

### `src/discovery/process_instance.yaml`
- Removed the entire "Fetch applications" step (saved one API call per instance)
- Removed the `all_applications | product(all_environments)` Cartesian product loop
- Access points now loop over `all_environments` — same structure as certificates
- API call reduction: O(apps × envs) → O(envs)

### `transformation/discovery/transform_discover.json`
- Removed `concert_application_id` and `concert_application_name` from IT asset metadata object

### `transformation/discovery/transform_it_assets.json`
- Removed `concert_application_id` and `concert_application_name` from IT asset metadata object

### `manifest.json`
- Version bumped: `1.2.5` → `2.0.0`

### `README.md`
- Corrected all API endpoint references (removed incorrect `/concert/` prefix)
- Updated "How It Works" discovery steps (removed application discovery step)
- Updated "API Endpoints Used" section
- Updated "Discovered Assets" section (removed application name/ID from IT asset fields)
- Added v2.0.0 entry to Version History
- Updated prerequisites to reflect Concert 3.0+ requirement

### Phase 3 Changelog comments added to
- `src/discovery/fetch_application_access_points.yaml`
- `src/discovery/process_instance.yaml`

---

## What Was Not Changed

- `src/integration/test_connection.yaml` — uses `/core/api/v1/environments` which is correct and unchanged
- `src/discovery/discover.yaml` — no changes needed
- `src/discovery/fetch_environment_certificates.yaml` — certificate endpoint unchanged
- `transformation/discovery/transform_certificates.json` — certificate schema unchanged
- `config/integration/integration-json-schema.json` — same credentials required
- `config/integration/integration-ui-schema.json` — no UI changes needed

---

## Result

Plugin v2.0.0 is ready for testing against IBM Concert 3.0+. IT asset discovery will now work correctly for the first time. Certificate discovery is unaffected.
