package policies.zeta.authztest

import data.policies.zeta.authz

# Mock Data
mock_data = {
    "audiences": {
        "allowed_audiences": [
            "https://test-ik-nr.vsdm2.ti-dienste.de"
        ]
    },
    "professions": {
        "allowed_professions": [
            "1.2.276.0.76.4.50",
            "1.2.276.0.76.4.51",
            "1.2.276.0.76.4.52",
            "1.2.276.0.76.4.53",
            "1.2.276.0.76.4.54",
            "1.2.276.0.76.4.55",
            "1.2.276.0.76.4.56",
            "1.2.276.0.76.4.57",
            "1.2.276.0.76.4.59"
        ]
    },
    "products": {
        "allowed_products": {
            "vsdm_test_client": ["0.1.0"]
        }
    },
    "token": {
        "access_token_ttl": 300,
        "refresh_token_ttl": 86400,
        "allowed_scopes": [
            "vsdservice"
        ]
    },
    "http_methods": {
        "allowed_http_methods": [
            "GET",
            "POST"
        ]
    },
    "ip_blocklist": {
        "blocked_ips": []
    },
    "ip_blocklist_tor": {
        "blocked_ips": []
    },
    "ip_blocklist_vpn": {
        "blocked_ips": []
    },
    "ip_blocklist_countries": {
        "blocked_countries": []
    }
}

# Base input that is valid
base_input = {
    "user_info": {
        "professionOID": "1.2.276.0.76.4.50"
    },
    "client_assertion": {
        "posture": {
            "product_id": "vsdm_test_client",
            "product_version": "0.1.0"
        }
    },
    "authorization_request": {
        "scopes": ["vsdservice"],
        "audience": ["https://test-ik-nr.vsdm2.ti-dienste.de"],
        "http_method": "GET",
        "ip_address": "1.2.3.4",
        "country_code": "DE"
    }
}

# Helper to evaluate decision with mocks
evaluate_decision(inp) := result if {
    result := authz.decision with input as inp
        with data.audiences as mock_data.audiences
        with data.professions as mock_data.professions
        with data.products as mock_data.products
        with data.token as mock_data.token
        with data.http_methods as mock_data.http_methods
        with data.ip_blocklist as mock_data.ip_blocklist
        with data.ip_blocklist_tor as mock_data.ip_blocklist_tor
        with data.ip_blocklist_vpn as mock_data.ip_blocklist_vpn
        with data.ip_blocklist_countries as mock_data.ip_blocklist_countries
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

test_deny_missing_audience if {
    input_missing_audience := json.remove(base_input, ["authorization_request/audience"])
    result := evaluate_decision(input_missing_audience)
    result.allow == false
    result.reasons["One or more requested audiences are not allowed"]
}

test_deny_empty_audience if {
    input_empty_audience := json.patch(base_input, [{"op": "replace", "path": "/authorization_request/audience", "value": []}])
    result := evaluate_decision(input_empty_audience)
    result.allow == false
    result.reasons["One or more requested audiences are not allowed"]
}

test_deny_unauthorized_audience if {
    input_bad_audience := json.patch(base_input, [{"op": "add", "path": "/authorization_request/audience/-", "value": "https://invalid.com"}])
    result := evaluate_decision(input_bad_audience)
    result.allow == false
    result.reasons["One or more requested audiences are not allowed"]
}

# --- Profession Tests ---

test_deny_invalid_profession if {
    input_bad_prof := json.patch(base_input, [{"op": "replace", "path": "/user_info/professionOID", "value": "1.2.3.4.5"}])
    result := evaluate_decision(input_bad_prof)
    result.allow == false
    result.reasons["User profession is not allowed"]
}

test_deny_missing_user_info if {
    input_no_user_info := json.remove(base_input, ["user_info"])
    result := evaluate_decision(input_no_user_info)
    result.allow == false
    result.reasons["User profession is not allowed"]
}

# --- Product/Version Tests ---

test_deny_invalid_product_id if {
    input_bad_prod := json.patch(base_input, [{"op": "replace", "path": "/client_assertion/posture/product_id", "value": "Invalid-Product"}])
    result := evaluate_decision(input_bad_prod)
    result.allow == false
    result.reasons["Client product or version is not allowed"]
}

test_deny_invalid_product_version if {
    input_bad_ver := json.patch(base_input, [{"op": "replace", "path": "/client_assertion/posture/product_version", "value": "9.9.9"}])
    result := evaluate_decision(input_bad_ver)
    result.allow == false
    result.reasons["Client product or version is not allowed"]
}

test_deny_missing_client_assertion if {
    input_no_client_assertion := json.remove(base_input, ["client_assertion"])
    result := evaluate_decision(input_no_client_assertion)
    result.allow == false
    result.reasons["Client product or version is not allowed"]
}

# --- HTTP Method Tests ---

test_deny_invalid_http_method if {
    input_bad_method := json.patch(base_input, [{"op": "replace", "path": "/authorization_request/http_method", "value": "DELETE"}])
    result := evaluate_decision(input_bad_method)
    result.allow == false
    result.reasons["HTTP method is not allowed"]
}

test_deny_missing_http_method if {
    input_no_method := json.remove(base_input, ["authorization_request/http_method"])
    result := evaluate_decision(input_no_method)
    result.allow == false
    result.reasons["HTTP method is not allowed"]
}

# --- IP Blocklist Tests ---

test_deny_tor_exit_node if {
    mock_tor := {"blocked_ips": ["10.0.0.1"]}
    input_tor := json.patch(base_input, [{"op": "replace", "path": "/authorization_request/ip_address", "value": "10.0.0.1"}])
    result := authz.decision with input as input_tor
        with data.audiences as mock_data.audiences
        with data.professions as mock_data.professions
        with data.products as mock_data.products
        with data.token as mock_data.token
        with data.http_methods as mock_data.http_methods
        with data.ip_blocklist as mock_data.ip_blocklist
        with data.ip_blocklist_tor as mock_tor
        with data.ip_blocklist_vpn as mock_data.ip_blocklist_vpn
        with data.ip_blocklist_countries as mock_data.ip_blocklist_countries
    result.allow == false
    result.reasons["Source IP address is a known TOR exit node"]
}

test_deny_vpn_endpoint if {
    mock_vpn := {"blocked_ips": ["10.0.0.2"]}
    input_vpn := json.patch(base_input, [{"op": "replace", "path": "/authorization_request/ip_address", "value": "10.0.0.2"}])
    result := authz.decision with input as input_vpn
        with data.audiences as mock_data.audiences
        with data.professions as mock_data.professions
        with data.products as mock_data.products
        with data.token as mock_data.token
        with data.http_methods as mock_data.http_methods
        with data.ip_blocklist as mock_data.ip_blocklist
        with data.ip_blocklist_tor as mock_data.ip_blocklist_tor
        with data.ip_blocklist_vpn as mock_vpn
        with data.ip_blocklist_countries as mock_data.ip_blocklist_countries
    result.allow == false
    result.reasons["Source IP address is a known VPN endpoint"]
}

test_deny_blocked_ip_range if {
    mock_blocklist := {"blocked_ips": ["192.168.0.0/16"]}
    input_blocked := json.patch(base_input, [{"op": "replace", "path": "/authorization_request/ip_address", "value": "192.168.1.100"}])
    result := authz.decision with input as input_blocked
        with data.audiences as mock_data.audiences
        with data.professions as mock_data.professions
        with data.products as mock_data.products
        with data.token as mock_data.token
        with data.http_methods as mock_data.http_methods
        with data.ip_blocklist as mock_blocklist
        with data.ip_blocklist_tor as mock_data.ip_blocklist_tor
        with data.ip_blocklist_vpn as mock_data.ip_blocklist_vpn
        with data.ip_blocklist_countries as mock_data.ip_blocklist_countries
    result.allow == false
    result.reasons["Source IP address is in a blocked IP range"]
}

test_deny_blocked_country if {
    mock_countries := {"blocked_countries": ["RU", "CN"]}
    input_blocked_country := json.patch(base_input, [{"op": "replace", "path": "/authorization_request/country_code", "value": "RU"}])
    result := authz.decision with input as input_blocked_country
        with data.audiences as mock_data.audiences
        with data.professions as mock_data.professions
        with data.products as mock_data.products
        with data.token as mock_data.token
        with data.http_methods as mock_data.http_methods
        with data.ip_blocklist as mock_data.ip_blocklist
        with data.ip_blocklist_tor as mock_data.ip_blocklist_tor
        with data.ip_blocklist_vpn as mock_data.ip_blocklist_vpn
        with data.ip_blocklist_countries as mock_countries
    result.allow == false
    result.reasons["Source IP address originates from a blocked country"]
}
