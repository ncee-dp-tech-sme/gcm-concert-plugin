# Intent Discovery Phase

## Overview

Before beginning plugin generation, Bob must gather essential information from the user through structured questions. All inputs in this section are MANDATORY.

## Step 1: Initial Plugin Request (MANDATORY USER INPUT)

**User Action**: User requests plugin creation for a specific product
- Example: "Create a plugin for HashiCorp Vault"
- Example: "Integrate with AWS Secrets Manager"
- Example: "Build discovery plugin for Rapid7"

**Bob Response**: Acknowledge request and proceed to gather detailed information

## Step 2: Product Details Collection (MANDATORY USER INPUT)

**Bob must ask the following questions**:

### 2.1 Product Name
**Question**: "What is the exact product name?"
- Example: "HashiCorp Vault", "AWS Secrets Manager", "Rapid7 InsightVM"

### 2.2 Product Deployment Model
**Question**: "Is this product SaaS, On-Premise, or Hybrid?"
- Options: "SaaS", "On-Premise", "Hybrid"
- Note: This determines whether version information is needed

### 2.3 Product Version Research and Selection

**IMPORTANT**: Bob must research available versions online before asking the user.

**Only ask for version if user selected "On-Premise" or "Hybrid" in step 2.2**

**If SaaS**:
- Skip version question entirely
- Set version to "SaaS" or "Cloud" in configuration
- Proceed to next step

**If On-Premise or Hybrid**:

**Step 1: Research Available Versions**
- Use browser tool to navigate directly to the product's official website
  - Common patterns: `https://{vendor}.com`, `https://www.{product}.com`, `https://{product}.io`
  - Examples: `https://www.hashicorp.com/products/vault`, `https://www.rapid7.com/products/insightvm/`
- Look for "Downloads", "Releases", "Documentation", or "Release Notes" sections
- Navigate to the releases or versions page
- Identify available versions (e.g., "1.15.0", "2.0.1", "Enterprise 2023.1")
- Note the latest stable version

**Note**: Avoid using Google search as it may trigger CAPTCHA. Navigate directly to the official product website.

**Step 2: Ask User for Version**

Present discovered versions to user:
> "I found the following available versions for {product name}:
> - {version 1} (latest stable)
> - {version 2}
> - {version 3}
> - Other (please specify)
>
> Which version are you using?"

**Note**: This helps identify compatible APIs and features for the specific version.

### 2.4 Product License
**Question**: "What license type do you have?"
- Options: "Community", "Enterprise", "Professional", "Open Source"
- Note: License type may affect available features and APIs

### 2.5 Test Credentials Availability
**Question**: "Do you have test credentials available for playbook validation?"
- Options: "Yes" or "No" or "I'll provide mock data instead"
- **IMPORTANT**: Never ask users to provide credentials in chat
- Note: If user has credentials, they will be asked to update `config/test_config.json` file in Phase 4 (Testing)
- If user doesn't have credentials, they can provide mock data files instead

## Step 3: Asset Type Selection (MANDATORY USER INPUT)

**Bob must ask**: "What types of crypto objects do you want to discover?"

**GCM Asset Types**:
- **Certificates**: X.509 certificates with subject, issuer, validity, and key information
- **Keys**: Cryptographic keys (symmetric/asymmetric) with algorithm, length, and usage details
- **Ciphers**: Cipher suites and protocol configurations (TLS/SSL versions, supported ciphers)
- **IT Assets**: Infrastructure context (hostnames, IPs, ports, services)

**Selection Options**:
- **All**: Certificates, Keys, Ciphers, and IT Assets (recommended)
- **Certificates Only**: Only X.509 certificates
- **Keys Only**: Only cryptographic keys
- **Ciphers Only**: Only cipher suites and protocol configurations
- **Certificates and Keys**: Both certificates and keys
- **Certificates and Ciphers**: Certificates with protocol/cipher information
- **Keys and Ciphers**: Keys with protocol/cipher information
- **Custom**: User specifies exact combination

**Default**: All (comprehensive discovery)

**Note**: IT asset discovery is automatically attempted when available from the target system to provide infrastructure context for crypto objects. Discovery will not fail if IT asset information is unavailable (e.g., HashiCorp Vault stores only crypto objects).

## Step 4: Confirmation and Summary

**Bob must present a summary**:
```
Plugin Configuration Summary:
- Product: [Product Name] [Version]
- License: [License Type]
- Integration Type: Discovery (crypto asset discovery and inventory)
- Asset Types: [Selected Types]
- Test Data: [Credentials available / Mock data will be provided]

Proceed with plugin generation? (Yes/No)
```

**User Action**: Confirm to proceed or request modifications

## Mandatory Input Validation

Before proceeding to Phase 1 (Environment Setup), Bob must verify:
- [ ] Product name is provided
- [ ] Product version is specified
- [ ] License type is identified
- [ ] Test credentials availability is confirmed
- [ ] Asset types are defined
- [ ] User has confirmed the summary

**If any input is missing**: Bob must request the missing information before proceeding.

## Next Phase

Once all mandatory inputs are collected and confirmed:
- Proceed to [Setup.md](Setup.md) for environment setup
- Document all collected information for use in subsequent phases