# GCM UI Configuration Guide

## Overview

This document provides guidance for creating UI configuration schemas for GCM plugin integrations. Two JSON schema files control how integration configuration is validated and rendered in the GCM user interface.

**IMPORTANT**: Only create fields that are actually used in your `src/integration/test_connection.yaml` and `src/discovery/discover.yaml` playbooks. Analyze these files first to identify required configuration parameters.

## Configuration Files

### 1. integration-json-schema.json

**Location**: `config/integration/integration-json-schema.json`

**Purpose**: Defines validation rules, data types, and constraints for integration configuration parameters.

#### Basic Structure

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["field1", "field2"],
  "properties": {
    "field1": {
      "type": "string",
      "description": "Field description"
    }
  }
}
```

#### Field Identification Process

**CRITICAL**: Before creating UI schemas, analyze your playbooks:

1. **Read Integration Playbooks**:
   - Open `src/integration/test_connection.yaml`
   - Open `src/discovery/discover.yaml`
   
2. **Identify Used Variables**:
   - Look for `{{ config.field_name }}` patterns
   - Look for `{{ config_item.field_name }}` patterns
   - Look for `{{ integration_config.field_name }}` patterns
   
3. **Create Only Required Fields**:
   - Only add fields to schemas that are referenced in playbooks
   - Mark fields as required if they're essential for operation
   - Don't add speculative or "nice to have" fields

**Example Analysis**:
```yaml
# In test_connection.yaml
vars:
  hostname: "{{ config.hostname }}"
  api_key: "{{ config.apiKey }}"
  
# This means you need: hostname, apiKey
```

#### Common Field Types

Only use these field types for parameters actually referenced in your playbooks:

**String Field** (for URLs, hostnames, paths):
```json
"url": {
  "type": "string",
  "description": "Target system URL",
  "minLength": 1
}
```

**String Field with Pattern** (for API keys, tokens):
```json
"apiKey": {
  "type": "string",
  "description": "API authentication key",
  "minLength": 1
}
```

**Integer Field** (for ports, timeouts):
```json
"port": {
  "type": "integer",
  "description": "Port number",
  "minimum": 1,
  "maximum": 65535,
  "default": 443
}
```

**Boolean-like Field** (CRITICAL - GCM does not support native boolean type):
```json
"verifySsl": {
  "type": "string",
  "enum": ["true", "false"],
  "default": "true",
  "description": "Verify SSL certificates (recommended: true)"
}
```
**Note**: Always use string enum for boolean values. See "GCM Boolean Field Limitation" section below for details.

**Enum Field** (for predefined choices):
```json
"authType": {
  "type": "string",
  "enum": ["apiKey", "basic"],
  "description": "Authentication method"
}
```

#### Validation Patterns (Use Only When Needed)

**URL Validation**:
```json
"url": {
  "type": "string",
  "format": "uri",
  "description": "Target system URL"
}
```

**Custom Pattern** (only if format is strictly enforced):
```json
"apiKey": {
  "type": "string",
  "pattern": "^[A-Za-z0-9]{32}$",
  "description": "32-character alphanumeric API key"
}
```

#### Conditional Validation (Only If Your Playbooks Support Multiple Auth Methods)

**If-Then-Else** (for multiple authentication types):
```json
{
  "properties": {
    "authType": {
      "type": "string",
      "enum": ["apiKey", "basic"]
    },
    "apiKey": {
      "type": "string"
    },
    "username": {
      "type": "string"
    },
    "password": {
      "type": "string"
    }
  },
  "if": {
    "properties": {
      "authType": {
        "const": "apiKey"
      }
    }
  },
  "then": {
    "required": ["apiKey"]
  },
  "else": {
    "required": ["username", "password"]
  }
}
```

**Note**: Only use conditional validation if your playbooks actually handle different authentication methods.

### 2. integration-ui-schema.json

**Location**: `config/integration/integration-ui-schema.json`

**Purpose**: Defines how configuration fields are rendered in the GCM UI, including widget types, ordering, and help text.

#### Basic Structure

```json
{
  "ui:order": ["field1", "field2", "field3"],
  "field1": {
    "ui:widget": "text",
    "ui:placeholder": "Enter value",
    "ui:help": "Help text for field"
  }
}
```

#### Common Widget Types

**Text Input** (for URLs, hostnames, usernames):
```json
"url": {
  "ui:widget": "text",
  "ui:placeholder": "https://api.example.com",
  "ui:help": "Enter the base URL of your target system"
}
```

**Password Input** (for API keys, passwords, tokens):
```json
"apiKey": {
  "ui:widget": "password",
  "ui:help": "API key from system settings"
}
```

**Textarea** (for certificates, large text):
```json
"certificate": {
  "ui:widget": "textarea",
  "ui:options": {
    "rows": 10
  },
  "ui:placeholder": "-----BEGIN CERTIFICATE-----",
  "ui:help": "Paste PEM-encoded certificate"
}
```

**Select Dropdown** (for boolean-like fields):
```json
"verifySsl": {
  "ui:widget": "select",
  "ui:help": "Enable SSL certificate verification (recommended: true)"
}
```
**Note**: GCM does not support checkbox widget for boolean values. Always use select dropdown with string enum.

**Select Dropdown** (for enum fields):
```json
"authType": {
  "ui:widget": "select",
  "ui:placeholder": "Select authentication method"
}
```

**Number Input** (for ports, timeouts):
```json
"port": {
  "ui:widget": "updown",
  "ui:help": "Port number (1-65535)"
}
```

#### Field Ordering

**Simple Order**:
```json
{
  "ui:order": [
    "url",
    "apiKey",
    "verifySsl",
    "timeout"
  ]
}
```

**Grouped Fields**:
```json
{
  "ui:order": [
    "url",
    "authType",
    "apiKey",
    "username",
    "password",
    "*"
  ]
}
```
Note: `"*"` represents all remaining fields not explicitly listed.

#### Field Visibility

**Conditional Display**:
```json
"apiKey": {
  "ui:widget": "password",
  "ui:options": {
    "condition": {
      "field": "authType",
      "value": "apiKey"
    }
  }
}
```

**Hidden Field**:
```json
"internalId": {
  "ui:widget": "hidden"
}
```

**Disabled Field**:
```json
"systemVersion": {
  "ui:widget": "text",
  "ui:disabled": true,
  "ui:help": "Auto-detected system version"
}
```

#### Custom Styling

**Field Classes**:
```json
"url": {
  "ui:widget": "text",
  "ui:classNames": "custom-url-field"
}
```

**Field Options**:
```json
"description": {
  "ui:widget": "textarea",
  "ui:options": {
    "rows": 5,
    "cols": 50,
    "maxLength": 500
  }
}
```

## Configuration Pattern Examples

**REMEMBER**: Only use patterns that match fields actually used in your playbooks!

### Pattern 1: Simple Hostname/URL Only

If your playbooks only use `hostname`:

**JSON Schema**:
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["hostname"],
  "properties": {
    "hostname": {
      "type": "string",
      "description": "Target system hostname or URL"
    }
  }
}
```

**UI Schema**:
```json
{
  "ui:order": ["hostname"],
  "hostname": {
    "ui:widget": "text",
    "ui:placeholder": "https://api.example.com",
    "ui:help": "Enter the target system URL or hostname"
  }
}
```

### Pattern 2: URL with API Key Authentication

If your playbooks use `url` and `apiKey`:

**JSON Schema**:
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["url", "apiKey"],
  "properties": {
    "url": {
      "type": "string",
      "format": "uri",
      "pattern": "^https://",
      "description": "API endpoint URL"
    },
    "apiKey": {
      "type": "string",
      "minLength": 20,
      "description": "API authentication key"
    },
    "verifySsl": {
      "type": "string",
      "enum": ["true", "false"],
      "default": "true",
      "description": "Verify SSL certificates (recommended: true)"
    },
    "timeout": {
      "type": "integer",
      "minimum": 5,
      "maximum": 300,
      "default": 30,
      "description": "Request timeout in seconds"
    }
  }
}
```

**UI Schema**:
```json
{
  "ui:order": ["url", "apiKey", "verifySsl", "timeout"],
  "url": {
    "ui:widget": "text",
    "ui:placeholder": "https://api.example.com",
    "ui:help": "Base URL of the target system"
  },
  "apiKey": {
    "ui:widget": "password",
    "ui:help": "Generate API key from system settings"
  },
  "verifySsl": {
    "ui:widget": "select",
    "ui:help": "Enable SSL certificate verification"
  },
  "timeout": {
    "ui:widget": "updown",
    "ui:help": "Connection timeout (5-300 seconds)"
  }
}
```

### Pattern 3: Multiple Authentication Methods (Only If Playbooks Support It)

**JSON Schema**:
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["url", "authType"],
  "properties": {
    "url": {
      "type": "string",
      "format": "uri"
    },
    "authType": {
      "type": "string",
      "enum": ["apiKey", "basic", "oauth"],
      "description": "Authentication method"
    },
    "apiKey": {
      "type": "string"
    },
    "username": {
      "type": "string"
    },
    "password": {
      "type": "string"
    },
    "oauthToken": {
      "type": "string"
    }
  },
  "allOf": [
    {
      "if": {
        "properties": {
          "authType": {"const": "apiKey"}
        }
      },
      "then": {
        "required": ["apiKey"]
      }
    },
    {
      "if": {
        "properties": {
          "authType": {"const": "basic"}
        }
      },
      "then": {
        "required": ["username", "password"]
      }
    },
    {
      "if": {
        "properties": {
          "authType": {"const": "oauth"}
        }
      },
      "then": {
        "required": ["oauthToken"]
      }
    }
  ]
}
```

**UI Schema**:
```json
{
  "ui:order": ["url", "authType", "apiKey", "username", "password", "oauthToken"],
  "url": {
    "ui:widget": "text",
    "ui:placeholder": "https://api.example.com"
  },
  "authType": {
    "ui:widget": "select",
    "ui:help": "Select authentication method"
  },
  "apiKey": {
    "ui:widget": "password",
    "ui:options": {
      "condition": {
        "field": "authType",
        "value": "apiKey"
      }
    }
  },
  "username": {
    "ui:widget": "text",
    "ui:options": {
      "condition": {
        "field": "authType",
        "value": "basic"
      }
    }
  },
  "password": {
    "ui:widget": "password",
    "ui:options": {
      "condition": {
        "field": "authType",
        "value": "basic"
      }
    }
  },
  "oauthToken": {
    "ui:widget": "password",
    "ui:options": {
      "condition": {
        "field": "authType",
        "value": "oauth"
      }
    }
  }
}
```

### Pattern 4: Username/Password Authentication

If your playbooks use `url`, `username`, and `password`:

**JSON Schema**:
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["url", "username", "password"],
  "properties": {
    "url": {
      "type": "string",
      "format": "uri",
      "description": "Target system URL"
    },
    "username": {
      "type": "string",
      "description": "Username for authentication"
    },
    "password": {
      "type": "string",
      "description": "Password for authentication"
    }
  }
}
```

**UI Schema**:
```json
{
  "ui:order": ["url", "username", "password"],
  "url": {
    "ui:widget": "text",
    "ui:placeholder": "https://api.example.com"
  },
  "username": {
    "ui:widget": "text",
    "ui:placeholder": "Enter username"
  },
  "password": {
    "ui:widget": "password",
    "ui:help": "Enter password"
  }
}
```

## GCM Boolean Field Limitation

**CRITICAL**: GCM does not support native boolean types in UI configuration schemas. All boolean-like fields must be implemented as string enums with values `"true"` and `"false"`.

### Correct Implementation Pattern

**JSON Schema (integration-json-schema.json)**:
```json
"verifySsl": {
  "type": "string",
  "enum": ["true", "false"],
  "default": "true",
  "description": "Verify SSL certificates (recommended: true)"
}
```

**UI Schema (integration-ui-schema.json)**:
```json
"verifySsl": {
  "ui:widget": "select",
  "ui:help": "Enable SSL certificate verification"
}
```

### Playbook String-to-Boolean Conversion

Since GCM passes boolean values as strings (`"true"` or `"false"`), playbooks must convert them to actual booleans using the `| bool` Jinja2 filter:

```yaml
validate_certs: "{{ verifySsl | bool }}"
```
OR
```yaml
validate_certs: "{{ (instance.verify_ssl | default('true')) == 'true' }}"
```

## Validation Messages

### Custom Error Messages

```json
{
  "url": {
    "type": "string",
    "format": "uri",
    "pattern": "^https://",
    "errorMessage": {
      "format": "Must be a valid URL",
      "pattern": "URL must use HTTPS protocol"
    }
  },
  "apiKey": {
    "type": "string",
    "minLength": 32,
    "maxLength": 32,
    "errorMessage": {
      "minLength": "API key must be exactly 32 characters",
      "maxLength": "API key must be exactly 32 characters"
    }
  }
}
```

## Security Considerations

### Sensitive Fields

Always mark sensitive fields appropriately:

**Password Fields**:
```json
"apiKey": {
  "ui:widget": "password"
}
```

**Hidden in Logs**:
```json
"secretKey": {
  "type": "string",
  "writeOnly": true,
  "description": "Secret key (never logged or displayed)"
}
```

### SSL/TLS Configuration

```json
{
  "verifySsl": {
    "type": "string",
    "enum": ["true", "false"],
    "default": "true",
    "description": "Verify SSL certificates (disable only for testing)"
  },
  "caCertPath": {
    "type": "string",
    "description": "Path to custom CA certificate bundle"
  }
}
```

## Best Practices

1. **Analyze Playbooks First**: Always read `src/integration/test_connection.yaml` and `src/discovery/discover.yaml` to identify required fields
2. **Only Required Fields**: Create schemas only for fields actually used in playbooks
3. **Mark as Required**: Mark fields as required if they're essential for operation
4. **Help Text**: Include clear, concise help text for all fields
5. **Security**: Mark sensitive fields (passwords, API keys, tokens) with password widget
6. **Placeholders**: Provide example values in placeholders
7. **Simple Validation**: Use minimal validation - only what's necessary
8. **Field Order**: List fields in logical order of importance
9. **No Speculation**: Don't add "nice to have" fields that aren't used
10. **Testing**: Test with actual playbook execution

## Testing UI Schemas

### Validation Testing

Test with various inputs:
- Valid values
- Invalid formats
- Missing required fields
- Boundary values (min/max)
- Empty strings
- Special characters

### UI Testing

Verify in GCM UI:
- Field rendering
- Widget functionality
- Conditional visibility
- Help text display
- Error message display
- Field ordering
- Form submission

## Complete Example (Based on Actual Playbook Usage)

**Example Playbook Analysis**:
```yaml
# src/integration/test_connection.yaml
vars:
  hostname: "{{ config.hostname }}"
  
# src/discovery/discover.yaml
vars:
  config_list: "{{ pluginConfig.integration }}"
tasks:
  - debug:
      msg: "Processing config: {{ config_item.hostname }}"
```

**Result**: Only `hostname` field is needed

**integration-json-schema.json**:
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["hostname"],
  "properties": {
    "hostname": {
      "type": "string",
      "description": "Target system hostname or URL"
    }
  }
}
```

**integration-ui-schema.json**:
```json
{
  "ui:order": ["hostname"],
  "hostname": {
    "ui:widget": "text",
    "ui:placeholder": "https://api.example.com",
    "ui:help": "Enter the target system URL or hostname"
  }
}
```

## Next Phase

Once UI schemas are created:
- Proceed to [BundlePlugIn.md](BundlePlugIn.md) for plugin packaging
- Ensure schemas are tested with actual playbook execution