package policies.zeta.authztest

import future.keywords.if
import future.keywords.in

import data.policies.zeta.authz

# Mock Data
mock_data = {
    "audiences": {
        "allowed_audiences": []
    },
    "professions": {
        "allowed_professions": []
    },
    "products": {
        "allowed_products": {
            "dipag-client": ["0.1.0"]
        }
    },
    "token": {
        "access_token_ttl": 300,
        "refresh_token_ttl": 86400,
        "allowed_scopes": [
            "dipag"
        ]
    }
}

# Base input that is valid
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
        "scopes": ["dipag"],
        "audience": ["https://example.com/dipag"]
    }
}

# Helper to evaluate decision with mocks
evaluate_decision(inp) := result if {
    result := authz.decision with input as inp
        with data.token as mock_data.token
}

test_allow_valid_request if {
    result := evaluate_decision(base_input)
    result.allow == true
}

# --- Scope Tests ---

test_deny_missing_scopes if {
    input_missing_scopes := json.remove(base_input, ["authorization_request/scopes"])
    result := evaluate_decision(input_missing_scopes)
    result.allow == false
    result.reasons["One or more requested scopes are not allowed"]
}

test_deny_empty_scopes if {
    input_empty_scopes := json.patch(base_input, [{"op": "replace", "path": "/authorization_request/scopes", "value": []}])
    result := evaluate_decision(input_empty_scopes)
    result.allow == false
    result.reasons["One or more requested scopes are not allowed"]
}

test_deny_unauthorized_scope if {
    input_bad_scope := json.patch(base_input, [{"op": "add", "path": "/authorization_request/scopes/-", "value": "invalid_scope"}])
    result := evaluate_decision(input_bad_scope)
    result.allow == false
    result.reasons["One or more requested scopes are not allowed"]
}

# --- Audience Tests ---
# Audience-Regel ist in der Policy deaktiviert (auskommentiert).

#test_deny_missing_audience if {
#    input_missing_audience := json.remove(base_input, ["authorization_request/audience"])
#    result := evaluate_decision(input_missing_audience)
#    result.allow == false
#    result.reasons["One or more requested audiences are not allowed"]
#}

#test_deny_empty_audience if {
#    input_empty_audience := json.patch(base_input, [{"op": "replace", "path": "/authorization_request/audience", "value": []}])
#    result := evaluate_decision(input_empty_audience)
#    result.allow == false
#    result.reasons["One or more requested audiences are not allowed"]
#}

#test_deny_unauthorized_audience if {
#    input_bad_audience := json.patch(base_input, [{"op": "add", "path": "/authorization_request/audience/-", "value": "https://invalid.com"}])
#    result := evaluate_decision(input_bad_audience)
#    result.allow == false
#    result.reasons["One or more requested audiences are not allowed"]
#}

# --- Profession Tests ---
# Profession-Regel ist in der Policy deaktiviert (auskommentiert).

#test_deny_invalid_profession if {
#    input_bad_prof := json.patch(base_input, [{"op": "replace", "path": "/user_info/professionOID", "value": "1.2.3.4.5"}])
#    result := evaluate_decision(input_bad_prof)
#    result.allow == false
#    result.reasons["User profession is not allowed"]
#}

#test_deny_missing_user_info if {
#    input_no_user_info := json.remove(base_input, ["user_info"])
#    result := evaluate_decision(input_no_user_info)
#    result.allow == false
#    result.reasons["User profession is not allowed"]
#}

# --- Product/Version Tests ---
# Product-Regel ist in der Policy deaktiviert (auskommentiert).

#test_deny_invalid_product_id if {
#    input_bad_prod := json.patch(base_input, [{"op": "replace", "path": "/client_assertion/posture/product_id", "value": "Invalid-Product"}])
#    result := evaluate_decision(input_bad_prod)
#    result.allow == false
#    result.reasons["Client product or version is not allowed"]
#}

#test_deny_invalid_product_version if {
#    input_bad_ver := json.patch(base_input, [{"op": "replace", "path": "/client_assertion/posture/product_version", "value": "9.9.9"}])
#    result := evaluate_decision(input_bad_ver)
#    result.allow == false
#    result.reasons["Client product or version is not allowed"]
#}

#test_deny_missing_client_assertion if {
#    input_no_client_assertion := json.remove(base_input, ["client_assertion"])
#    result := evaluate_decision(input_no_client_assertion)
#    result.allow == false
#    result.reasons["Client product or version is not allowed"]
#}
