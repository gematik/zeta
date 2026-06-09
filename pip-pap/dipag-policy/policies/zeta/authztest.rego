package policies.zeta.authztest

import future.keywords.if
import future.keywords.in

import data.policies.zeta.authz

# Mock Data for Token TTLs
mock_data = {
    "token": {
        "access_token_ttl": 300,
        "refresh_token_ttl": 86400
    }
}

# Base input that is valid (Rechnungsersteller with valid scope)
base_input = {
    "user_info": {
        "professionOID": "1.2.276.0.76.4.50"
    },
    "client_assertion": {
        "posture": {
            "product_id": "dipag-client",
            "product_version": "0.1.0"
        }
    },
    "authorization_request": {
        "scopes": ["invoiceDoc.r"],
        "audience": ["https://example.com/dipag"]
    }
}

# Helper to evaluate decision with mock token TTLs
evaluate_decision(inp) := result if {
    result := authz.decision with input as inp
        with data.token as mock_data.token
}

# --- Success Path Tests ---

test_allow_valid_request if {
    result := evaluate_decision(base_input)
    result.allow == true
    result.ttl.access_token == 300
    result.ttl.refresh_token == 86400
}

test_allow_valid_request_other_role if {
    # 1.2.276.0.76.4.49 -> Rechnungsempfaenger, which allows invoiceDoc.ruds
    inp := json.patch(base_input, [
        {"op": "replace", "path": "/user_info/professionOID", "value": "1.2.276.0.76.4.49"},
        {"op": "replace", "path": "/authorization_request/scopes", "value": ["invoiceDoc.ruds"]}
    ])
    result := evaluate_decision(inp)
    result.allow == true
}

# --- Profession Tests ---

test_deny_invalid_profession if {
    inp := json.patch(base_input, [
        {"op": "replace", "path": "/user_info/professionOID", "value": "1.2.3.4.5"}
    ])
    result := evaluate_decision(inp)
    result.allow == false
    result.reasons["User profession is not allowed for DiPag"]
}

test_deny_missing_profession if {
    inp := json.remove(base_input, ["user_info/professionOID"])
    result := evaluate_decision(inp)
    result.allow == false
    result.reasons["User profession is not allowed for DiPag"]
}

# --- Scope Tests ---

test_deny_unauthorized_scope_for_role if {
    # Rechnungsersteller tries to request auditEvent.rs (which is only allowed for Rechnungsempfaenger/Rechnungseinreicher)
    inp := json.patch(base_input, [
        {"op": "replace", "path": "/authorization_request/scopes", "value": ["auditEvent.rs"]}
    ])
    result := evaluate_decision(inp)
    result.allow == false
    result.reasons["Requested scopes do not match the role of the user's profession"]
}

test_deny_invalid_scope if {
    # Requesting a scope that does not exist in any role
    inp := json.patch(base_input, [
        {"op": "replace", "path": "/authorization_request/scopes", "value": ["invalid_scope"]}
    ])
    result := evaluate_decision(inp)
    result.allow == false
    result.reasons["One or more requested scopes are not valid DiPag scopes"]
}

test_deny_empty_scopes if {
    inp := json.patch(base_input, [
        {"op": "replace", "path": "/authorization_request/scopes", "value": []}
    ])
    result := evaluate_decision(inp)
    result.allow == false
    # With empty scopes:
    # 1. scopes_match_role fails -> "Requested scopes do not match the role of the user's profession"
    # 2. scopes_are_valid fails -> "One or more requested scopes are not valid DiPag scopes"
    result.reasons["Requested scopes do not match the role of the user's profession"]
    result.reasons["One or more requested scopes are not valid DiPag scopes"]
}
