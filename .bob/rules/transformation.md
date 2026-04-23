# GCM Data Transformation Guide

## Overview

This document provides comprehensive guidance for creating data transformation rules using Omniparser to convert discovered data into GCM-compatible format. Transformations are defined in JSON format and executed by the GCM transformation engine.

## CRITICAL: Transformation Testing Workflow

**MANDATORY PROCESS** - Bob MUST follow this exact workflow for Phase 5 transformation testing:

### Step 1: Prepare Test Data (REQUIRED)
Before creating any transformation, Bob MUST:
1. Read actual output files from Phase 2 playbook execution
2. Extract the JSON structure from `test_output/crypto_asset_details_*.json`

### Step 2: Create Simple Root Structure Test (REQUIRED)
Before creating complex transformations, Bob MUST test the root data structure:

```python
# Example: Simple root test transformation
{
  "parser_settings": {
    "file_format_type": "json",
    "version": "omni.2.1"
  },
  "transform_declarations": {
    "FINAL_OUTPUT": {
      "xpath": ".",  # Test with "." for single object
      "object": {
        "test_field1": {"xpath": "field1"},
        "test_field2": {"xpath": "field2"}
      }
    }
  }
}
```

**Purpose**: Verify XPath root and data structure before adding complex logic.

### Step 3: Test Root Structure (REQUIRED)
Use `test_transformation_files` MCP tool:
- Provide simple transformation (no custom functions)
- Use actual input data (dict or list format)
- Verify `overall.assetsFound > 0` (if 0, adjust XPath)
- Review data quality report for errors and warnings
- Analyze transformed output data

### Step 4: Iterative XPath Refinement (IF NEEDED)
If `data: []` (empty), Bob MUST try different XPath patterns:
1. Try `"xpath": "."` for single object at root
2. Try `"xpath": "*"` for array at root
3. Try `"xpath": "[*]"` for explicit array notation
4. Try `"xpath": "data.*"` if data is nested under "data" key

**Test each XPath variation** until `data` array contains assets.

### Step 5: Add Mandatory Fields (REQUIRED)
Once correct XPath is found, add GCM mandatory fields:
- Start with simple field mappings (no custom functions)
- Test after adding each mandatory field
- Verify no errors before proceeding

### Step 6: Add Custom Functions (INCREMENTAL)
Add custom functions ONE AT A TIME:
1. Add one custom function
2. Test transformation
3. If successful, add next function
4. If 400 error, simplify or remove the function

**Known Issues**:
- Deeply nested custom functions (3+ levels) may cause 400 errors
- Use simpler alternatives when possible

### Step 7: Final Validation (REQUIRED)
Before marking Phase 5 complete, Bob MUST verify:
- [ ] Transformation created successfully (has ID)
- [ ] Test executed without errors (`errors_count: 0`)
- [ ] Assets generated (`assets_generated > 0`) OR valid reason for 0 (e.g., conditional XPath filter)
- [ ] All mandatory GCM fields present in generated assets

## MCP Tool Parameter Format (CRITICAL)

**IMPORTANT**: The MCP server expects Python objects (dict/list).

### Parameter Types

**Required Parameters**:
- `input_file_content`: dict or list (required) - Input data as Python object
  - Read from playbook output file: `test_output/*.json`
  - Pass the object directly
  
- `transformation_file_content`: dict (required) - Transformation config as Python object
  - Read from transformation file: `transformation/discovery/transform_discover.json`
  - Must contain ONLY the transformation_list structure
  - Pass the object directly

### Usage Rules

**When user provides complete tool arguments**:
- Use arguments AS-IS (already in correct format)

**When reading from files**:
- Read the file content as Python object
- Pass directly to MCP tool

## Transformation File Structure

**Location**: `transformation/discovery/transform_discover.json`

**Complete File Structure**:
```json
{
  "parser_settings": {
    "file_format_type": "json",
    "version": "omni.2.1"
  },
  "transform_declarations": {
    "FINAL_OUTPUT": {
      "xpath": "root.path.to.data",
      "object": {
        "field_name": {
          "xpath": "relative.path"
        }
      }
    }
  }
}
```

**Important**: When Bob generates transformation rules, it should output only the transformation object (parser_settings + transform_declarations), not the full file structure with transformation_list wrapper. The wrapper is added by the GCM framework when the transformation is saved to the file.

## Omniparser Syntax

### XPath Expressions

XPath expressions locate data within the source JSON structure.

**Absolute Path**:
```json
"xpath": "data.certificates[*]"
```

**Relative Path** (within object context):
```json
"xpath": "subject.commonName"
```

**Array Access**:
```json
"xpath": "certificates[0]"        // First element
"xpath": "certificates[*]"        // All elements
"xpath": "certificates[-1]"       // Last element
```

**Conditional Selection**:
```json
"xpath": "certificates[?(@.type=='X509')]"
```

### Value Assignment Methods

#### 1. Direct XPath
Extract value from source data:
```json
"subject": {
  "xpath": "certificate.subject"
}
```

#### 2. Constant Value
Assign static value:
```json
"asset_type": {
  "const": "CERTIFICATE"
}
```

#### 3. Template String
Combine multiple values:
```json
"display_name": {
  "template": "{{ subject }} - {{ issuer }}"
}
```

#### 4. Custom Function
Apply transformation function:
```json
"not_before": {
  "xpath": "validFrom",
  "custom_func": "parse_date_iso8601"
}
## XPath Root Detection Strategy

**MANDATORY**: Before creating final transformations, Bob MUST determine the correct root XPath by testing simple transformations.

### Root Detection Process

1. **Create Test Transformation**:
```json
{
  "parser_settings": {
    "file_format_type": "json",
    "version": "omni.2.1"
  },
  "transform_declarations": {
    "FINAL_OUTPUT": {
      "xpath": ".",
      "object": {
        "field1": {"xpath": "field1_name"},
        "field2": {"xpath": "field2_name"}
      }
    }
  }
}
```

2. **Test with MCP Tool**:
```xml
<use_mcp_tool>
<server_name>gcm-custom-adaptor</server_name>
<tool_name>test_transformation_files</tool_name>
<arguments>
{
  "input_file_content": [{"field": "value"}],
  "transformation_file_content": {"transformation_list": [...]}
}
</arguments>
</use_mcp_tool>
```

3. **Analyze Results**:
- If `overall.assetsFound: 0` → XPath doesn't match structure
- If `overall.assetsFound > 0` → XPath is correct
- Check `warnings` count for data quality issues

4. **XPath Patterns to Try** (in order):
```
Single object at root:     "xpath": "."
Array at root:             "xpath": "*"
Explicit array:            "xpath": "[*]"
Nested under key:          "xpath": "data.*"
Conditional filter:        "xpath": ".[?(@.type=='certificate')]"
```

5. **Save Correct XPath**: Once found, use this XPath for all transformations of that asset type.

## Common XPath Issues and Solutions

### Issue 1: Empty Data Array (`data: []`)
**Symptom**: Test succeeds but `assets_generated: 0`
**Cause**: XPath doesn't match data structure
**Solution**: Try different XPath patterns (see Root Detection Process above)

### Issue 2: 400 Bad Request Error
**Symptom**: API returns 400 error during test
**Causes**:
1. **Complex nested custom functions** (3+ levels deep)
2. **Invalid custom function syntax**
3. **Missing required transformation fields**

**Solutions**:
1. Simplify custom functions - reduce nesting levels
2. Test custom functions individually before combining
3. Verify all required fields present

### Issue 3: Transformation Pending
**Symptom**: `is_available: false`, `status: "pending"`
**Cause**: Transformation still being processed by GCM
**Solution**: Wait 5-10 minutes and retry, or proceed with deployment

## Custom Function Complexity Guidelines

**CRITICAL**: Deeply nested custom functions (3+ levels) often cause 400 Bad Request errors.

### Safe Nesting Levels
- **Level 1** (Direct): ✅ Always works
  ```json
  "field": {"xpath": "source_field"}
  ```

- **Level 2** (Single function): ✅ Usually works
  ```json
  "field": {
    "custom_func": {
      "name": "hex_to_int",
      "args": [{"xpath": "hex_value"}]
    }
  }
  ```

- **Level 3** (Nested functions): ⚠️ May work
  ```json
  "field": {
    "custom_func": {
      "name": "skip_on_missing_field",
      "args": [
        {
          "custom_func": {
            "name": "hex_to_int",
            "args": [{"xpath": "hex_value"}]
          }
        },
        {"const": "message:Skipped"}
      ]
    }
  }
  ```

- **Level 4+** (Deep nesting): ❌ Often fails with 400 error
  ```json
  "field": {
    "custom_func": {
      "name": "skip_on_missing_field",
      "args": [
        {
          "custom_func": {
            "name": "hex_to_int",
            "args": [
              {
                "custom_func": {
                  "name": "replace_matches",
                  "args": [...]
                }
              }
            ]
          }
        }
      ]
    }
  }
  ```

### Simplification Strategies
1. **Break into multiple fields**: Create intermediate fields instead of deep nesting
2. **Use simpler functions**: Avoid complex regex when simple xpath works
3. **Test incrementally**: Add one function at a time and test


## GCM Custom Functions

GCM's Omniparser implementation provides specialized custom functions for data extraction and transformation:

### Text Extraction Functions

**find_value_for_key**: Extract value using regex pattern and key separator
```json
{
  "custom_func": {
    "name": "find_value_for_key",
    "args": [
      {
        "xpath": "plugin_text"
      },
      {
        "const": "(?s)Subject Name:.*?Common Name:\\s*(\\S+)"
      },
      {
        "const": "Common Name:"
      }
    ]
  }
}
```

**find_matches**: Extract all matches for a regex pattern
```json
{
  "custom_func": {
    "name": "find_matches",
    "args": [
      {
        "xpath": "plugin_text"
      },
      {
        "const": "DNS:\\s*[^\\n]+"
      }
    ]
  }
}
```

**replace_matches**: Replace regex matches with empty string or replacement
```json
{
  "custom_func": {
    "name": "replace_matches",
    "args": [
      {
        "xpath": "serial_number"
      },
      {
        "const": "\\s"
      }
    ]
  }
}
```

### Date/Time Functions

**dateTimeLayoutToRFC3339**: Convert date string to RFC3339 format
```json
{
  "custom_func": {
    "name": "dateTimeLayoutToRFC3339",
    "args": [
      {
        "xpath": "date_string"
      },
      {
        "const": "Jan 2 15:04:05 2006 MST",
        "_comment": "layout"
      },
      {
        "const": "false",
        "_comment": "layoutTZ"
      },
      {
        "const": "GMT",
        "_comment": "fromTZ"
      },
      {
        "const": "UTC",
        "_comment": "toTZ"
      }
    ]
  }
}
```

### Encoding Functions

**hex_to_int**: Convert hexadecimal string to integer
```json
{
  "custom_func": {
    "name": "hex_to_int",
    "args": [
      {
        "xpath": "hex_value"
      }
    ]
  }
}
```

**to_sha256**: Generate SHA-256 hash
```json
{
  "custom_func": {
    "name": "to_sha256",
    "args": [
      {
        "xpath": "data"
      },
      {
        "const": "hex"
      }
    ]
  }
}
```
Options for encoding: "hex", "base64"

### String Functions

**concat**: Concatenate multiple strings
```json
{
  "custom_func": {
    "name": "concat",
    "args": [
      {
        "xpath": "ip"
      },
      {
        "const": ":"
      },
      {
        "xpath": "port"
      }
    ]
  }
}
```

### JavaScript Function

**javascript**: Execute custom JavaScript code
```json
{
  "custom_func": {
    "name": "javascript",
    "args": [
      {
        "const": "(function() { return lis.map(item => item.trim()); })()"
      },
      {
        "const": "lis"
      },
      {
        "xpath": "array_data"
      }
    ]
  }
}
```

### Validation Functions

**skip_on_missing_field**: Skip record if field is missing or empty
```json
{
  "custom_func": {
    "name": "skip_on_missing_field",
    "args": [
      {
        "xpath": "required_field"
      },
      {
        "const": "message:Skipped record as required_field is missing"
      }
    ]
  }
}
```

## GCM Asset Structure

GCM supports four primary asset types for crypto object discovery. Each asset type requires a separate transformation with its own `yields` value.

### Transformation Yields Values

Each transformation must specify the asset type it generates using the `yields` field:

```json
{
  "transformation_list": [
    {
      "format": "json",
      "yields": "certificate",  // For certificates
      "transformation": {...}
    },
    {
      "format": "json",
      "yields": "keys",  // For cryptographic keys
      "transformation": {...}
    },
    {
      "format": "json",
      "yields": "ciphers",  // For cipher suites and protocols
      "transformation": {...}
    },
    {
      "format": "json",
      "yields": "it-asset",  // For IT infrastructure assets
      "transformation": {...}
    }
  ]
}
```

**Valid yields values**:
- `"certificate"` - For X.509 certificates
- `"keys"` - For cryptographic keys (symmetric/asymmetric)
- `"ciphers"` - For cipher suites and protocol configurations
- `"it-asset"` - For IT infrastructure assets (servers, endpoints, services)

### Certificate Asset

**Mandatory Fields**:
```json
{
  "category": {
    "const": "CRYPTO_OBJECT"
  },
  "asset_type": {
    "const": "CRYPTO_OBJECT.CERTIFICATE"
  },
  "subject": "CN=example.com",
  "issuer": "CN=CA",
  "certificate_serial_number": 123456,
  "not_before": "2026-01-01T00:00:00Z",
  "not_after": "2027-01-01T00:00:00Z",
  "material": "base64_encoded_cert_without_pem_markers"
}
```

**Optional Fields**:
```json
{
  "key_algorithm": "RSA Encryption",
  "key_length": 2048,
  "hashing_algorithm": "SHA-256 With RSA Encryption",
  "san": [
    {
      "type_id": "DNS",
      "value": "example.com"
    }
  ],
  "material_hash_value": "sha256_hash_of_material",
  "crypto_object_name": "example.com Certificate",
  "discovery_sources": ["profile_id"]
}
```

### Key Asset

**Mandatory Fields**:
```json
{
  "key_algorithm": "RSA",
  "key_length": 2048,
  "key_type": "asymmetric",
  "public_hash_key_value": "sha256_hash_of_public_key"
}
```

**Optional Fields**:
```json
{
  "crypto_object_name": "Production Key",
  "private_hash_key_value": "sha256_hash_of_private_key",
  "key_usage": "encryption",
  "expiry": "2027-01-01T00:00:00Z",
  "discovery_sources": ["profile_id"]
}
```

**Note**: `public_hash_key_value` is mandatory for key identification and relationship mapping. Generate it using the `to_sha256` custom function with the key identifier or public key material.

### Cipher Asset

**Mandatory Fields**:
```json
{
  "protocol": "TLS",
  "protocols": [
    {
      "version": "1.2",
      "ciphers": ["TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"]
    }
  ]
}
```

**Optional Fields**:
```json
{
  "crypto_object_name": "TLS Configuration",
  "it_asset_uri": "10.0.0.1:443",
  "discovery_sources": ["profile_id"]
}
```

### IT Asset

**Mandatory Fields**:
```json
{
  "uri": "10.0.0.1:443"
}
```

**Optional Fields**:
```json
{
  "hostname": "server.example.com",
  "ip": "10.0.0.1",
  "port": 443,
  "protocol": "HTTPS",
  "asset_type": "SERVER",
  "discovery_sources": ["profile_id"]
}
```

### Relationships

Assets can define relationships to other assets using the `relationships` array:

**IT Asset Relationship** (from Certificate/Key to IT Asset):
```json
{
  "relationships": [
    {
      "asset_type": "IT_ASSET",
      "asset_identifiers": {
        "uri": "10.0.0.1:443"
      }
    }
  ]
}
```

**Key Relationship** (from Certificate to Key):
```json
{
  "relationships": [
    {
      "asset_type": "CRYPTO_OBJECT.KEY",
      "asset_identifiers": {
        "public_hash_key_value": "sha256_hash_of_public_key"
      }
    }
  ]
}
```

## Pattern: Tenable Security Center Certificate Discovery

**Source Data Structure**:
```json
{
  "certificates": [
    {
      "source_hostname": "https://sc.example.com",
      "plugin_id": "10863",
      "plugin_name": "SSL Certificate Information",
      "ip": "10.0.0.1",
      "hostname": "server.example.com",
      "port": "443",
      "protocol": "TCP",
      "plugin_text": "<plugin_output>Subject Name: ...\nCommon Name: *.example.com\n..."
    }
  ]
}
```

**Transformation Pattern** (Bob should generate only the inner transformation object):
```json
{
  "parser_settings": {
    "file_format_type": "json",
    "version": "omni.2.1"
  },
  "transform_declarations": {
    "FINAL_OUTPUT": {
      "xpath": "certificates/*",
      "object": {
        "category": {
          "const": "CRYPTO_OBJECT"
        },
        "asset_type": {
          "const": "CRYPTO_OBJECT.CERTIFICATE"
        },
        "subject": {
          "custom_func": {
            "name": "skip_on_missing_field",
            "args": [
              {
                "custom_func": {
                  "name": "find_value_for_key",
                  "args": [
                    {
                      "xpath": "plugin_text"
                    },
                    {
                      "const": "(?s)Subject Name:.*?Common Name:\\s*(\\S+)"
                    },
                    {
                      "const": "Common Name:"
                    }
                  ]
                }
              },
              {
                "const": "message:Skipped record as subject is missing"
              }
            ]
          }
        },
        "issuer": {
          "custom_func": {
            "name": "skip_on_missing_field",
            "args": [
              {
                "custom_func": {
                  "name": "find_value_for_key",
                  "args": [
                    {
                      "xpath": "plugin_text"
                    },
                    {
                      "const": "(?s)Issuer Name:.*?Common Name:\\s*(\\S+)"
                    },
                    {
                      "const": "Common Name:"
                    }
                  ]
                }
              },
              {
                "const": "message:Skipped record as issuer is missing"
              }
            ]
          }
        },
        "certificate_serial_number": {
          "custom_func": {
            "name": "skip_on_missing_field",
            "args": [
              {
                "custom_func": {
                  "name": "hex_to_int",
                  "args": [
                    {
                      "custom_func": {
                        "name": "replace_matches",
                        "args": [
                          {
                            "custom_func": {
                              "name": "find_value_for_key",
                              "args": [
                                {
                                  "xpath": "plugin_text"
                                },
                                {
                                  "const": "(?i)Serial Number:\\s*([0-9A-Fa-f ]+)"
                                },
                                {
                                  "const": ":"
                                }
                              ]
                            }
                          },
                          {
                            "const": "\\s"
                          }
                        ]
                      }
                    }
                  ]
                }
              },
              {
                "const": "message:Skipped record as certificate_serial_number is missing"
              }
            ]
          }
        },
        "key_algorithm": {
          "custom_func": {
            "name": "find_value_for_key",
            "args": [
              {
                "xpath": "plugin_text"
              },
              {
                "const": "Algorithm:\\s*([^\\n]+)"
              },
              {
                "const": ":"
              }
            ]
          }
        },
        "key_length": {
          "custom_func": {
            "name": "replace_matches",
            "args": [
              {
                "custom_func": {
                  "name": "find_value_for_key",
                  "args": [
                    {
                      "xpath": "plugin_text"
                    },
                    {
                      "const": "(?i)Key Length:\\s*(.+)"
                    },
                    {
                      "const": ":"
                    }
                  ]
                }
              },
              {
                "const": " ([bits|bytes|bit|byte])"
              }
            ]
          },
          "type": "int"
        },
        "hashing_algorithm": {
          "custom_func": {
            "name": "find_value_for_key",
            "args": [
              {
                "xpath": "plugin_text"
              },
              {
                "const": "Signature Algorithm:\\s*([^\\n]+)"
              },
              {
                "const": ":"
              }
            ]
          }
        },
        "not_before": {
          "custom_func": {
            "name": "dateTimeLayoutToRFC3339",
            "args": [
              {
                "custom_func": {
                  "name": "find_value_for_key",
                  "args": [
                    {
                      "xpath": "plugin_text"
                    },
                    {
                      "const": "Not Valid Before:\\s*([^\\n]+)"
                    },
                    {
                      "const": ":"
                    }
                  ]
                }
              },
              {
                "const": "Jan 2 15:04:05 2006 MST",
                "_comment": "layout"
              },
              {
                "const": "false",
                "_comment": "layoutTZ"
              },
              {
                "const": "GMT",
                "_comment": "fromTZ"
              },
              {
                "const": "UTC",
                "_comment": "toTZ"
              }
            ]
          }
        },
        "not_after": {
          "custom_func": {
            "name": "skip_on_missing_field",
            "args": [
              {
                "custom_func": {
                  "name": "dateTimeLayoutToRFC3339",
                  "args": [
                    {
                      "custom_func": {
                        "name": "find_value_for_key",
                        "args": [
                          {
                            "xpath": "plugin_text"
                          },
                          {
                            "const": "Not Valid After:\\s*([^\\n]+)"
                          },
                          {
                            "const": ":"
                          }
                        ]
                      }
                    },
                    {
                      "const": "Jan 2 15:04:05 2006 MST",
                      "_comment": "layout"
                    },
                    {
                      "const": "false",
                      "_comment": "layoutTZ"
                    },
                    {
                      "const": "GMT",
                      "_comment": "fromTZ"
                    },
                    {
                      "const": "UTC",
                      "_comment": "toTZ"
                    }
                  ]
                }
              },
              {
                "const": "message:Skipped record as not_after is missing"
              }
            ]
          }
        },
        "san": {
          "custom_func": {
            "name": "javascript",
            "args": [
              {
                "const": "(function() { if (!lis || lis.length === 0) return \"\"; return lis.map(item => { const parts = item.split(':'); return { typeId: parts[0].trim(), value: parts.slice(1).join(':').trim() }; }); })()"
              },
              {
                "const": "lis"
              },
              {
                "custom_func": {
                  "name": "find_matches",
                  "args": [
                    {
                      "xpath": "plugin_text"
                    },
                    {
                      "const": "DNS:\\s*[^\\n]+"
                    }
                  ]
                }
              }
            ]
          }
        },
        "material": {
          "custom_func": {
            "name": "javascript",
            "args": [
              {
                "const": "lis[0]"
              },
              {
                "const": "lis"
              },
              {
                "custom_func": {
                  "name": "replace_matches",
                  "args": [
                    {
                      "custom_func": {
                        "name": "find_matches",
                        "args": [
                          {
                            "xpath": "plugin_text"
                          },
                          {
                            "const": "(?s)-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----"
                          }
                        ]
                      }
                    },
                    {
                      "const": "-----BEGIN CERTIFICATE-----|\\s|-----END CERTIFICATE-----"
                    }
                  ]
                }
              }
            ]
          }
        },
        "material_hash_value": {
          "custom_func": {
            "name": "to_sha256",
            "args": [
              {
                "custom_func": {
                  "name": "javascript",
                  "args": [
                    {
                      "const": "lis[0]"
                    },
                    {
                      "const": "lis"
                    },
                    {
                      "custom_func": {
                        "name": "replace_matches",
                        "args": [
                          {
                            "custom_func": {
                              "name": "find_matches",
                              "args": [
                                {
                                  "xpath": "plugin_text"
                                },
                                {
                                  "const": "(?s)-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----"
                                }
                              ]
                            }
                          },
                          {
                            "const": "-----BEGIN CERTIFICATE-----|\\s|-----END CERTIFICATE-----"
                          }
                        ]
                      }
                    }
                  ]
                }
              },
              {
                "const": "base64"
              }
            ]
          }
        },
        "description": {
          "xpath": "plugin_name"
        },
        "discovery_sources": {
          "array": [
            {
              "external": "profile_id"
            }
          ]
        },
        "relationships": {
          "array": [
            {
              "object": {
                "asset_type": {
                  "const": "IT_ASSET"
                },
                "asset_identifiers": {
                  "object": {
                    "uri": {
                      "custom_func": {
                        "name": "concat",
                        "args": [
                          {
                            "xpath": "ip"
                          },
                          {
                            "const": ":"
                          },
                          {
                            "xpath": "port"
                          }
                        ]
                      }
                    }
                  }
                }
              }
            },
            {
              "object": {
                "asset_type": {
                  "const": "CRYPTO_OBJECT.KEY"
                },
                "asset_identifiers": {
                  "object": {
                    "public_hash_key_value": {
                      "custom_func": {
                        "name": "to_sha256",
                        "args": [
                          {
                            "custom_func": {
                              "name": "replace_matches",
                              "args": [
                                {
                                  "custom_func": {
                                    "name": "find_value_for_key",
                                    "args": [
                                      {
                                        "xpath": "plugin_text"
                                      },
                                      {
                                        "const": "(?s)Public Key:\\s*([0-9A-Fa-f\\s]+?)\\s*Exponent:"
                                      },
                                      {
                                        "const": ":"
                                      }
                                    ]
                                  }
                                },
                                {
                                  "const": "\\s"
                                }
                              ]
                            }
                          },
                          {
                            "const": "hex"
                          }
                        ]
                      }
                    }
                  }
                }
              }
            }
          ]
        }
      }
    }
  }
}
```

**Key Extraction Patterns for Tenable Plugin Text**:

1. **Subject**: `(?s)Subject Name:.*?Common Name:\s*(\S+)`
2. **Issuer**: `(?s)Issuer Name:.*?Common Name:\s*(\S+)`
3. **Serial Number**: `(?i)Serial Number:\s*([0-9A-Fa-f ]+)` (then remove spaces and convert hex to int)
4. **Dates**: `Not Valid Before:\s*([^\n]+)` and `Not Valid After:\s*([^\n]+)`
5. **Key Algorithm**: `(?s)Public Key Info:.*?Algorithm:\s*([^\n]+)`
6. **Key Length**: `(?i)Key Length:\s*(.+)` (then remove "bits" suffix)
7. **Signature Algorithm**: `Signature Algorithm:\s*([^\n]+)`
8. **SAN DNS**: `DNS:\s*[^\n]+` (find all matches)
9. **PEM Certificate**: `(?s)-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----`
10. **Public Key**: `(?s)Public Key:\s*([0-9A-Fa-f\s]+?)\s*Exponent:`

```

## Mandatory GCM Fields

### Certificate Assets

**Required Fields**:
```json
{
  "asset_type": {
    "const": "CERTIFICATE"
  },
  "certificate_pem": {
    "xpath": "pem_data"
  },
  "subject": {
    "xpath": "subject_dn"
  },
  "issuer": {
    "xpath": "issuer_dn"
  },
  "serial_number": {
    "xpath": "serial"
  },
  "not_before": {
    "xpath": "valid_from"
  },
  "not_after": {
    "xpath": "valid_to"
  },
  "key_algorithm": {
    "xpath": "public_key.algorithm"
  },
  "key_length": {
    "xpath": "public_key.size"
  },
  "signature_algorithm": {
    "xpath": "signature.algorithm"
  }
}
```

**Optional Fields**:
```json
{
  "san_dns": {
    "xpath": "extensions.subjectAltName.dns"
  },
  "san_ip": {
    "xpath": "extensions.subjectAltName.ip"
  },
  "key_usage": {
    "xpath": "extensions.keyUsage"
  },
  "extended_key_usage": {
    "xpath": "extensions.extendedKeyUsage"
  },
  "thumbprint_sha1": {
    "xpath": "fingerprints.sha1"
  },
  "thumbprint_sha256": {
    "xpath": "fingerprints.sha256"
  }
}
```

### Key Assets

**Required Fields**:
```json
{
  "asset_type": {
    "const": "KEY"
  },
  "key_type": {
    "xpath": "type"
  },
  "key_algorithm": {
    "xpath": "algorithm"
  },
  "key_length": {
    "xpath": "size"
  },
  "key_id": {
    "xpath": "id"
  }
}
```

## Transformation Patterns

### Pattern 1: Simple Object Mapping

**Source Data**:
```json
{
  "certificate": {
    "subject": "CN=example.com",
    "issuer": "CN=CA",
    "serialNumber": "123456",
    "notBefore": "2026-01-01T00:00:00Z",
    "notAfter": "2027-01-01T00:00:00Z"
  }
}
```

**Transformation**:
```json
{
  "transformation_list": [
    {
      "format": "json",
      "yields": "assets",
      "transformation": {
        "parser_settings": {
          "file_format_type": "json",
          "version": "omni.2.1"
        },
        "transform_declarations": {
          "FINAL_OUTPUT": {
            "xpath": "certificate",
            "object": {
              "asset_type": {
                "const": "CERTIFICATE"
              },
              "subject": {
                "xpath": "subject"
              },
              "issuer": {
                "xpath": "issuer"
              },
              "serial_number": {
                "xpath": "serialNumber"
              },
              "not_before": {
                "xpath": "notBefore"
              },
              "not_after": {
                "xpath": "notAfter"
              }
            }
          }
        }
      }
    }
  ]
}
```

### Pattern 2: Array Iteration

**Source Data**:
```json
{
  "certificates": [
    {
      "subject": "CN=cert1.com",
      "pem": "-----BEGIN CERTIFICATE-----\n..."
    },
    {
      "subject": "CN=cert2.com",
      "pem": "-----BEGIN CERTIFICATE-----\n..."
    }
  ]
}
```

**Transformation**:
```json
{
  "transformation_list": [
    {
      "format": "json",
      "yields": "assets",
      "transformation": {
        "parser_settings": {
          "file_format_type": "json",
          "version": "omni.2.1"
        },
        "transform_declarations": {
          "FINAL_OUTPUT": {
            "xpath": "certificates[*]",
            "object": {
              "asset_type": {
                "const": "CERTIFICATE"
              },
              "certificate_pem": {
                "xpath": "pem"
              },
              "subject": {
                "xpath": "subject"
              }
            }
          }
        }
      }
    }
  ]
}
```

### Pattern 3: Nested Object Extraction

**Source Data**:
```json
{
  "data": {
    "items": [
      {
        "certificate": {
          "details": {
            "subject": "CN=example.com",
            "issuer": "CN=CA"
          },
          "validity": {
            "notBefore": "2026-01-01",
            "notAfter": "2027-01-01"
          }
        }
      }
    ]
  }
}
```

**Transformation**:
```json
{
  "transformation_list": [
    {
      "format": "json",
      "yields": "assets",
      "transformation": {
        "parser_settings": {
          "file_format_type": "json",
          "version": "omni.2.1"
        },
        "transform_declarations": {
          "FINAL_OUTPUT": {
            "xpath": "data.items[*].certificate",
            "object": {
              "asset_type": {
                "const": "CERTIFICATE"
              },
              "subject": {
                "xpath": "details.subject"
              },
              "issuer": {
                "xpath": "details.issuer"
              },
              "not_before": {
                "xpath": "validity.notBefore"
              },
              "not_after": {
                "xpath": "validity.notAfter"
              }
            }
          }
        }
      }
    }
  ]
}
```

### Pattern 4: Array Field Mapping

**Source Data**:
```json
{
  "certificate": {
    "subject": "CN=example.com",
    "subjectAltNames": [
      "example.com",
      "www.example.com",
      "api.example.com"
    ]
  }
}
```

**Transformation**:
```json
{
  "transformation_list": [
    {
      "format": "json",
      "yields": "assets",
      "transformation": {
        "parser_settings": {
          "file_format_type": "json",
          "version": "omni.2.1"
        },
        "transform_declarations": {
          "FINAL_OUTPUT": {
            "xpath": "certificate",
            "object": {
              "asset_type": {
                "const": "CERTIFICATE"
              },
              "subject": {
                "xpath": "subject"
              },
              "san_dns": {
                "xpath": "subjectAltNames",
                "array": true
              }
            }
          }
        }
      }
    }
  ]
}
```

### Pattern 5: Conditional Mapping

**Source Data**:
```json
{
  "items": [
    {
      "type": "certificate",
      "data": {...}
    },
    {
      "type": "key",
      "data": {...}
    }
  ]
}
```

**Transformation**:
```json
{
  "transformation_list": [
    {
      "format": "json",
      "yields": "assets",
      "transformation": {
        "parser_settings": {
          "file_format_type": "json",
          "version": "omni.2.1"
        },
        "transform_declarations": {
          "FINAL_OUTPUT": {
            "xpath": "items[?(@.type=='certificate')].data",
            "object": {
              "asset_type": {
                "const": "CERTIFICATE"
              },
              "certificate_pem": {
                "xpath": "pem"
              }
            }
          }
        }
      }
    }
  ]
}
```

### Pattern 6: Field Concatenation

**Source Data**:
```json
{
  "certificate": {
    "subject": {
      "commonName": "example.com",
      "organization": "Example Inc",
      "country": "US"
    }
  }
}
```

**Transformation**:
```json
{
  "transformation_list": [
    {
      "format": "json",
      "yields": "assets",
      "transformation": {
        "parser_settings": {
          "file_format_type": "json",
          "version": "omni.2.1"
        },
        "transform_declarations": {
          "FINAL_OUTPUT": {
            "xpath": "certificate",
            "object": {
              "asset_type": {
                "const": "CERTIFICATE"
              },
              "subject": {
                "template": "CN={{ subject.commonName }}, O={{ subject.organization }}, C={{ subject.country }}"
              }
            }
          }
        }
      }
    }
  ]
}
```

## Custom Functions

### Date/Time Functions

**parse_date_iso8601**: Convert date to ISO 8601 format
```json
"not_before": {
  "xpath": "validFrom",
  "custom_func": "parse_date_iso8601"
}
```

**parse_date_unix**: Convert Unix timestamp to ISO 8601
```json
"not_before": {
  "xpath": "validFromTimestamp",
  "custom_func": "parse_date_unix"
}
```

**parse_date_custom**: Parse custom date format
```json
"not_before": {
  "xpath": "validFrom",
  "custom_func": "parse_date_custom",
  "format": "DD/MM/YYYY HH:mm:ss"
}
```

### String Functions

**to_upper**: Convert to uppercase
```json
"key_algorithm": {
  "xpath": "algorithm",
  "custom_func": "to_upper"
}
```

**to_lower**: Convert to lowercase
```json
"key_algorithm": {
  "xpath": "algorithm",
  "custom_func": "to_lower"
}
```

**trim**: Remove whitespace
```json
"subject": {
  "xpath": "subject",
  "custom_func": "trim"
}
```

**replace**: Replace substring
```json
"subject": {
  "xpath": "subject",
  "custom_func": "replace",
  "find": "CN=",
  "replace": ""
}
```

### Encoding Functions

**base64_decode**: Decode base64 string
```json
"certificate_pem": {
  "xpath": "pemBase64",
  "custom_func": "base64_decode"
}
```

**base64_encode**: Encode to base64
```json
"certificate_pem": {
  "xpath": "pemRaw",
  "custom_func": "base64_encode"
}
```

**hex_to_string**: Convert hex to string
```json
"serial_number": {
  "xpath": "serialHex",
  "custom_func": "hex_to_string"
}
```

### Numeric Functions

**to_int**: Convert to integer
```json
"key_length": {
  "xpath": "keySize",
  "custom_func": "to_int"
}
```

**to_string**: Convert to string
```json
"serial_number": {
  "xpath": "serialNumber",
  "custom_func": "to_string"
}
```

## Data Type Handling

### String Fields
```json
"subject": {
  "xpath": "subject",
  "type": "string"
}
```

### Integer Fields
```json
"key_length": {
  "xpath": "keySize",
  "type": "integer"
}
```

### Boolean Fields
```json
"is_ca": {
  "xpath": "basicConstraints.ca",
  "type": "boolean"
}
```

### Array Fields
```json
"san_dns": {
  "xpath": "subjectAltName.dns",
  "type": "array"
}
```

### Object Fields
```json
"metadata": {
  "xpath": "customMetadata",
  "type": "object"
}
```

## Error Handling

### Default Values

Provide fallback when field is missing:
```json
"key_length": {
  "xpath": "keySize",
  "default": 0
}
```

### Null Handling

Skip null values:
```json
"san_dns": {
  "xpath": "subjectAltName.dns",
  "skip_null": true
}
```

### Required Fields

Mark field as mandatory:
```json
"certificate_pem": {
  "xpath": "pem",
  "required": true
}
```

## Validation Rules

### Field Validation

**Pattern Matching**:
```json
"serial_number": {
  "xpath": "serial",
  "pattern": "^[0-9A-F:]+$"
}
```

**Length Constraints**:
```json
"subject": {
  "xpath": "subject",
  "min_length": 1,
  "max_length": 500
}
```

**Value Range**:
```json
"key_length": {
  "xpath": "keySize",
  "min": 1024,
  "max": 8192
}
```

**Enum Values**:
```json
"key_algorithm": {
  "xpath": "algorithm",
  "enum": ["RSA", "EC", "DSA"]
}
```

## Testing Transformations

### Using test_transformation_files MCP Tool

The `test_transformation_files` MCP tool tests a transformation configuration with input data and returns complete results including transformed data, data quality report, and summary statistics. This provides detailed error information for debugging and fixing transformations.

**Required Parameters**:
- `input_file_content`: dict or list (required) - Input data as Python object
  - Source: Playbook output file `test_output/crypto_asset_details_0_0.json`
  - Pass the object directly
  
- `transformation_file_content`: dict (required) - Transformation config as Python object
  - Source: Transformation file `transformation/discovery/transform_discover.json`
  - Must contain ONLY the transformation_list structure
  - Pass the object directly

**Example Usage**:
```xml
<use_mcp_tool>
<server_name>gcm-custom-adaptor</server_name>
<tool_name>test_transformation_files</tool_name>
<arguments>
{
  "input_file_content": [{"hostname": "test.com", "ip": "192.168.1.1"}],
  "transformation_file_content": {"transformation_list": [{"format": "json", "yields": "it-asset", "transformation": {...}}]}
}
</arguments>
</use_mcp_tool>
```

**Response Structure**:
```json
{
  "message": "Transformation test completed successfully",
  "data": {
    "output_data": {
      "assets": [
        {
          "uri": "test.com",
          "hostname": "test.com",
          "ip": "192.168.1.1"
        }
      ]
    },
    "summary": {
      "assets": [
        {
          "assetType": "certificate",
          "summary": {
            "assetsFound": 41,
            "warnings": 232
          }
        }
      ],
      "overall": {
        "assetsFound": 589,
        "warnings": 505
      }
    },
    "data_quality_report": [
      {
        "field": "subject",
        "status": "valid",
        "message": "Field validated successfully"
      },
      {
        "field": "not_after",
        "status": "error",
        "message": "Required field missing",
        "line": 15,
        "record": {...}
      }
    ]
  },
  "files_extracted": ["output_data", "summary", "data_quality_report"]
}
```

**Response Fields**:
- `message`: Status message
- `data.output_data`: Complete transformed asset data
- `data.summary`: Summary statistics by asset type and overall
- `data.data_quality_report`: Detailed field-level validation results with errors and warnings
- `files_extracted`: List of data files extracted from transformation result

**Data Quality Report Structure**:
The `data_quality_report` array contains detailed validation information for each field:
- `field`: Field name being validated
- `status`: Validation status ("valid", "warning", "error")
- `message`: Detailed error or warning message
- `line`: Line number in source data where issue occurred (for errors)
- `record`: Partial record data showing context (for errors)

---

### Analyzing Test Results

**Check Summary First**:
```json
"summary": {
  "overall": {
    "assetsFound": 10,
    "warnings": 2
  }
}
```

**Analyze Asset Summaries**:
1. Check `assets` array - shows breakdown by asset type
2. Verify `assetsFound > 0` for expected asset types
3. Review `warnings` count - indicates data quality issues

**Review Transformed Data**:
```json
"output_data": {
  "assets": [
    {
      "uri": "server.example.com:443",
      "hostname": "server.example.com",
      "ip": "10.0.0.1",
      "port": 443
    }
  ]
}
```

**Analyze Data Quality Issues**:
When errors or warnings occur, examine the detailed error information:
```json
{
  "assetType": "certificate",
  "summary": {
    "assetsFound": 8,
    "warnings": 2,
    "errors": [
      {
        "line": 15,
        "field": "not_after",
        "error": "Required field missing or invalid",
        "record": {
          "subject": "CN=test.com",
          "issuer": "CN=CA"
        }
      }
    ]
  }
}
```

**Fix Transformation Based on Errors**:

1. **Missing Required Field**:
   - Error: "Required field missing"
   - Fix: Add field mapping or use `skip_on_missing_field` custom function
   ```json
   "not_after": {
     "custom_func": {
       "name": "skip_on_missing_field",
       "args": [
         {"xpath": "expiry_date"},
         {"const": "message:Skipped - expiry_date missing"}
       ]
     }
   }
   ```

2. **Invalid Data Type**:
   - Error: "Expected integer, got string"
   - Fix: Add type conversion
   ```json
   "port": {
     "xpath": "port_number",
     "type": "int"
   }
   ```

3. **XPath Not Matching**:
   - Error: "Field not found in source data"
   - Fix: Verify XPath against actual data structure
   ```json
   // Check actual data structure
   "certificate": {
     "details": {
       "subject": "CN=test.com"  // Correct path: certificate.details.subject
     }
   }
   ```

4. **Date Format Issues**:
   - Error: "Invalid date format"
   - Fix: Use date conversion function
   ```json
   "not_after": {
     "xpath": "expiry",
     "custom_func": "dateTimeLayoutToRFC3339",
     "args": [...]
   }
   ```

**Iterative Testing Workflow**:

1. Read actual playbook output files from Phase 4
2. Analyze data structure and identify field mappings
3. Create transformation rules in `transformation/discovery/transform_discover.json`
4. Test with `test_transformation_files` tool
5. Review `output_data` to verify transformed assets
6. Check `summary` for errors and warnings
7. Fix transformation based on error details
8. Re-test until `assetsFound > 0` and no critical errors

**Example Iterative Process**:
```xml
<!-- Step 1: Initial test -->
<use_mcp_tool>
<server_name>gcm-custom-adaptor</server_name>
<tool_name>test_transformation_files</tool_name>
<arguments>
{
  "input_file_content": [{"subject": "CN=test.com", "expiry": "2027-01-01"}],
  "transformation_file_content": {"transformation_list": [...]}
}
</arguments>
</use_mcp_tool>

<!-- Step 2: Analyze response -->
<!-- Review output_data and summary for errors -->

<!-- Step 3: Fix transformation based on errors -->
<!-- Edit transformation/discovery/transform_discover.json -->

<!-- Step 4: Re-test -->
<use_mcp_tool>
<server_name>gcm-custom-adaptor</server_name>
<tool_name>test_transformation_files</tool_name>
<arguments>
{
  "input_file_content": [{"subject": "CN=test.com", "expiry": "2027-01-01"}],
  "transformation_file_content": {"transformation_list": [...]}
}
</arguments>
</use_mcp_tool>
```

### Validation Checklist

- [ ] All mandatory GCM fields are mapped
- [ ] Date fields are in ISO 8601 format
- [ ] PEM data includes BEGIN/END markers
- [ ] Serial numbers are properly formatted
- [ ] Array fields are correctly handled
- [ ] Nested objects are properly extracted
- [ ] Default values are provided for optional fields
- [ ] Null values are handled appropriately
- [ ] Data types match GCM expectations

## Common Issues and Solutions

### Issue: Missing PEM Data
**Problem**: Certificate PEM not found in source
**Solution**: Check if PEM is base64 encoded or in different field
```json
"certificate_pem": {
  "xpath": "pemData",
  "custom_func": "base64_decode"
}
```

### Issue: Date Format Mismatch
**Problem**: Dates not in ISO 8601 format
**Solution**: Use date parsing function
```json
"not_before": {
  "xpath": "validFrom",
  "custom_func": "parse_date_custom",
  "format": "YYYY-MM-DD HH:mm:ss"
}
```

### Issue: Nested Array Access
**Problem**: Data is deeply nested in arrays
**Solution**: Use proper XPath with array notation
```json
"xpath": "data.results[*].items[*].certificate"
```

### Issue: Field Name Conflicts
**Problem**: Source field names don't match GCM expectations
**Solution**: Map explicitly with xpath
```json
"serial_number": {
  "xpath": "serialNo"
}
```

### Issue: Multiple Data Sources
**Problem**: Need to combine data from multiple fields
**Solution**: Use template strings
```json
"display_name": {
  "template": "{{ subject }} ({{ issuer }})"
}
```

## Best Practices

1. **Start Simple**: Begin with mandatory fields, add optional fields later
2. **Test Incrementally**: Validate transformation after each field addition
3. **Use Descriptive Names**: Make field mappings clear and understandable
4. **Handle Nulls**: Always provide defaults or skip_null for optional fields
5. **Validate Data Types**: Ensure numeric fields are numbers, not strings
6. **Document Assumptions**: Comment complex transformations
7. **Test Edge Cases**: Verify handling of missing, null, or malformed data
8. **Use Custom Functions**: Leverage built-in functions for common transformations
9. **Maintain Consistency**: Use consistent patterns across similar fields
10. **Version Control**: Track transformation changes with version comments

## Complete Example

**Source Data**:
```json
{
  "certificates": [
    {
      "id": "cert-001",
      "pemData": "LS0tLS1CRUdJTi...",
      "subjectDN": "CN=example.com,O=Example Inc,C=US",
      "issuerDN": "CN=Example CA,O=Example Inc,C=US",
      "serialNumber": "01:23:45:67:89:AB",
      "validity": {
        "notBefore": "2026-01-01T00:00:00.000Z",
        "notAfter": "2027-01-01T00:00:00.000Z"
      },
      "publicKey": {
        "algorithm": "RSA",
        "size": 2048
      },
      "signature": {
        "algorithm": "SHA256withRSA"
      },
      "extensions": {
        "subjectAltName": {
          "dns": ["example.com", "www.example.com"]
        }
      }
    }
  ]
}
```

**Transformation**:
```json
{
  "transformation_list": [
    {
      "format": "json",
      "yields": "assets",
      "transformation": {
        "parser_settings": {
          "file_format_type": "json",
          "version": "omni.2.1"
        },
        "transform_declarations": {
          "FINAL_OUTPUT": {
            "xpath": "certificates[*]",
            "object": {
              "asset_type": {
                "const": "CERTIFICATE"
              },
              "certificate_pem": {
                "xpath": "pemData",
                "custom_func": "base64_decode"
              },
              "subject": {
                "xpath": "subjectDN"
              },
              "issuer": {
                "xpath": "issuerDN"
              },
              "serial_number": {
                "xpath": "serialNumber"
              },
              "not_before": {
                "xpath": "validity.notBefore"
              },
              "not_after": {
                "xpath": "validity.notAfter"
              },
              "key_algorithm": {
                "xpath": "publicKey.algorithm"
              },
              "key_length": {
                "xpath": "publicKey.size"
              },
              "signature_algorithm": {
                "xpath": "signature.algorithm"
              },
              "san_dns": {
                "xpath": "extensions.subjectAltName.dns",
                "type": "array"
              }
            }
          }
        }
      }
    }
  ]
}
```

**Output**:
```json
{
  "asset_type": "CERTIFICATE",
  "certificate_pem": "-----BEGIN CERTIFICATE-----\n...",
  "subject": "CN=example.com,O=Example Inc,C=US",
  "issuer": "CN=Example CA,O=Example Inc,C=US",
  "serial_number": "01:23:45:67:89:AB",
  "not_before": "2026-01-01T00:00:00.000Z",
  "not_after": "2027-01-01T00:00:00.000Z",
  "key_algorithm": "RSA",
  "key_length": 2048,
  "signature_algorithm": "SHA256withRSA",
  "san_dns": ["example.com", "www.example.com"]
}
# GCM Data Transformation Guide - Complete Testing Workflow

## Quick Start: Foolproof Transformation Testing

This guide ensures transformation testing works perfectly every time by following a systematic approach.

### Prerequisites Checklist
Before starting transformation testing, verify:
- [ ] Phase 2 playbooks executed successfully
- [ ] Output files exist in `test_output/crypto_asset_details_*.json`
- [ ] Output files contain valid JSON data
- [ ] MCP server `gcm-custom-adaptor` is accessible

### Complete Testing Workflow

#### Step 1: Read and Analyze Output Files
```xml
<read_file>
<args>
  <file>
    <path>test_output/crypto_asset_details_0_0.json</path>
  </file>
</args>
</read_file>
```

**Analyze the structure**:
- Is it a single object `{}` or array `[]`?
- What are the top-level field names?
- Are there nested objects or arrays?

#### Step 2: Test Root XPath with Simple Transformation
Create a minimal transformation to find the correct XPath:

```xml
<use_mcp_tool>
<server_name>gcm-custom-adaptor</server_name>
<tool_name>test_transformation_files</tool_name>
<arguments>
{
  "input_file_content": [{"field": "value"}],
  "transformation_file_content": {"transformation_list": [...]}
}
</arguments>
</use_mcp_tool>
```

**Expected Results**:
- ✅ `overall.assetsFound > 0` - Assets created (XPath is correct!)
- ⚠️ `overall.assetsFound: 0` - No assets (XPath needs adjustment)
- Check `warnings` count for data quality issues
- Review `data_quality_report` for field-level errors

#### Step 3: Adjust XPath if Needed
If `assetsFound: 0`, try these XPath patterns in order:

| Data Structure | XPath Pattern | Example |
|---|---|---|
| Single object at root | `"."` | `{"field": "value"}` |
| Array at root | `"*"` | `[{"field": "value"}]` |
| Explicit array | `"[*]"` | `[{"field": "value"}]` |
| Nested under key | `"data.*"` | `{"data": [{"field": "value"}]}` |
| Filtered array | `".[?(@.type=='cert')]"` | `[{"type": "cert", "field": "value"}]` |

**Test each pattern** until `assetsFound > 0`.

#### Step 4: Add Mandatory Fields Incrementally
Once correct XPath is found, add mandatory GCM fields one at a time:

```json
{
  "xpath": ".",  // Use the XPath that worked in Step 3
  "object": {
    // Start with category and asset_type
    "category": {"const": "CRYPTO_OBJECT"},
    "asset_type": {"const": "CRYPTO_OBJECT.CERTIFICATE"},
    
    // Add simple field mappings (no custom functions yet)
    "subject": {"xpath": "subject"},
    "issuer": {"xpath": "issuer"}
  }
}
```

**Test after adding each field** to catch errors early.

#### Step 5: Add Custom Functions Carefully
Add custom functions ONE AT A TIME:

**Level 1 - Simple custom function**:
```json
"certificate_serial_number": {
  "custom_func": {
    "name": "hex_to_int",
    "args": [{"xpath": "serial_number"}]
  }
}
```
→ Test → If successful, proceed

**Level 2 - Nested custom function**:
```json
"certificate_serial_number": {
  "custom_func": {
    "name": "hex_to_int",
    "args": [
      {
        "custom_func": {
          "name": "replace_matches",
          "args": [
            {"xpath": "serial_number"},
            {"const": "\\s|:"}
          ]
        }
      }
    ]
  }
}
```
→ Test → If 400 error, simplify

**STOP at Level 3** - Avoid deeper nesting to prevent 400 errors.

#### Step 6: Final Validation
Before marking transformation complete, verify:
- [ ] `overall.assetsFound > 0` (or valid reason for 0)
- [ ] `warnings` count is acceptable
- [ ] All mandatory GCM fields mapped in transformation
- [ ] Field data types match GCM expectations

### Troubleshooting Guide

| Problem | Cause | Solution |
|---|---|---|
| 400 Bad Request | Complex nested functions | Simplify to 2-3 nesting levels max |
| `assetsFound: 0` | Wrong XPath | Try different XPath patterns (Step 3) |
| High `warnings` count | Missing/invalid fields | Check field mappings and mandatory fields |

### Example: Complete Working Test

```xml
<use_mcp_tool>
<server_name>gcm-custom-adaptor</server_name>
<tool_name>test_transformation_files</tool_name>
<arguments>
{
  "input_file_content": [{"subject": "CN=test.com", "issuer": "CN=CA", "serial_number": "0A:1B:2C", "not_before": "2026-01-01T00:00:00Z", "expires": "2027-01-01T00:00:00Z", "certificate_data": "MIIFZjCCBE6..."}],
  "transformation_file_content": {
    "transformation_list": [{
      "format": "json",
      "yields": "certificate",
      "transformation": {
        "parser_settings": {
          "file_format_type": "json",
          "version": "omni.2.1"
        },
        "transform_declarations": {
          "FINAL_OUTPUT": {
            "xpath": ".",
            "object": {
              "category": {"const": "CRYPTO_OBJECT"},
              "asset_type": {"const": "CRYPTO_OBJECT.CERTIFICATE"},
              "subject": {"xpath": "subject"},
              "issuer": {"xpath": "issuer"},
              "certificate_serial_number": {
                "custom_func": {
                  "name": "hex_to_int",
                  "args": [
                    {
                      "custom_func": {
                        "name": "replace_matches",
                        "args": [
                          {"xpath": "serial_number"},
                          {"const": "\\s|:"}
                        ]
                      }
                    }
                  ]
                }
              },
              "not_before": {"xpath": "not_before"},
              "not_after": {"xpath": "expires"},
              "material": {"xpath": "certificate_data"}
            }
          }
        }
      }
    }]
  }
}
</arguments>
</use_mcp_tool>
```

**Expected Success Response**:
```json
{
  "message": "Transformation test completed successfully",
  "data": {
    "output_data": {
      "assets": [
        {
          "category": "CRYPTO_OBJECT",
          "asset_type": "CRYPTO_OBJECT.CERTIFICATE",
          "subject": "CN=test.com",
          "issuer": "CN=CA",
          "certificate_serial_number": 664124,
          "not_before": "2026-01-01T00:00:00Z",
          "not_after": "2027-01-01T00:00:00Z",
          "material": "MIIFZjCCBE6..."
        }
      ]
    },
    "summary": {
      "assets": [
        {
          "assetType": "certificate",
          "summary": {
            "assetsFound": 1,
            "warnings": 0
          }
        }
      ],
      "overall": {
        "assetsFound": 1,
        "warnings": 0
      }
    }
  },
  "files_extracted": ["output_data", "summary"]
}
```

**Expected Success Response**:
```json
{
  "assets": [
    {
      "assetType": "certificate",
      "summary": {
        "assetsFound": 1,
        "warnings": 0
      }
    }
  ],
  "files": [
    {
      "name": "output_data.json",
      "type": "data-file"
    }
  ],
  "overall": {
    "assetsFound": 1,
    "warnings": 0
  }
}
```

---
