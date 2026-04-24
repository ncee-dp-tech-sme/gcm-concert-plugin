# IBM Concert Discovery Plugin - Version 1.2.0 Release Notes

## Release Date
April 24, 2026

## Major Changes

### 🔧 Architectural Fix: Separated Transformation Files

**Problem Solved**: 
Previous versions (1.1.1-1.1.6) experienced persistent transformation errors when processing certificate files with the IT asset transformation. The error was:
```
'FINAL_OUTPUT.port.custom_func(javascript)' failed: result is null
```

**Root Cause**:
GCM's Omniparser applies ALL transformations to ALL output files and evaluates ALL fields in each transformation BEFORE checking skip conditions. This meant:
- Certificate files (without `host` field) were processed by IT asset transformation
- JavaScript functions tried to extract port/protocol from missing `host` field
- Functions failed with null reference errors
- `skip_on_missing_field` couldn't prevent field evaluation (only prevents record creation)

**Solution**:
Separated the combined transformation into two dedicated files:

1. **`transform_certificates.json`** (231 lines)
   - Only processes certificate files
   - Contains certificate-specific field mappings
   - `"yields": "certificate"`

2. **`transform_it_assets.json`** (133 lines)
   - Only processes IT asset files
   - Contains IT asset-specific field mappings with JavaScript functions
   - `"yields": "it-asset"`

**Manifest Changes**:
Updated `manifest.json` to reference both transformations as an array:
```json
"transformation": [
  {
    "type": "gcm",
    "reference": "transformation/discovery/transform_certificates.json"
  },
  {
    "type": "gcm",
    "reference": "transformation/discovery/transform_it_assets.json"
  }
]
```

## Benefits

1. **Eliminates Cross-Contamination**: Each transformation only processes its intended file type
2. **Prevents JavaScript Errors**: IT asset JavaScript functions never execute on certificate files
3. **Proper Separation of Concerns**: Clean architecture for multi-asset-type plugins
4. **Maintainability**: Easier to update/debug individual transformations

## Migration Notes

- The old combined `transform_discover.json` is deprecated and excluded from packaging
- No changes required to playbooks or configuration
- Existing integrations will work with v1.2.0 after upgrade
- Output file structure remains unchanged

## Testing Recommendations

1. Test certificate discovery to ensure all certificate fields are captured
2. Test IT asset discovery to ensure hostname/protocol/port extraction works
3. Verify no transformation errors in GCM logs
4. Confirm both asset types appear in GCM inventory

## Files Changed

- `manifest.json` - Updated version to 1.2.0, changed transformation reference to array
- `transformation/discovery/transform_certificates.json` - NEW: Certificate-only transformation
- `transformation/discovery/transform_it_assets.json` - NEW: IT asset-only transformation
- `.bundleignore` - Added deprecated `transform_discover.json` to exclusions
- `README.md` - Updated version history with v1.2.0 notes

## Upgrade Path

1. Uninstall previous version (1.1.x) from GCM
2. Upload `ibm-concert-discovery-1.2.0.zip` to GCM
3. Install plugin
4. Test discovery with existing integration profiles
5. Verify both certificates and IT assets are discovered without errors

## Known Limitations

- GCM Omniparser does not support XPath predicates (e.g., `.[?(@.field)]`)
- All transformations are applied to all files (hence the need for separate files)
- Field evaluation happens before skip conditions are checked

## Support

For issues or questions, refer to the plugin README.md or contact the development team.