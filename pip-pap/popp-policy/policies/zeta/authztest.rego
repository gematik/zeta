package policies.zeta.authztest

import future.keywords.if
import future.keywords.in

import data.policies.zeta.authz

# Mock Data
mock_data = {
    "audiences": {
        "allowed_audiences": [
            "https://popp-server:30300",
            "https://192.168.49.2:30300",
            "https://popp-ru-dev-interim.int.epa.rise-link.de:443",
            "https://popp-ru-dev-interim.int.epa.rise-link.de:8443"
        ]
    },
    "audiences_for_user_allowlist": {
        "audiences": [
            "https://popp-server:30300",
            "https://192.168.49.2:30300",
            "https://popp-ru-dev-interim.int.epa.rise-link.de:443",
            "https://popp-ru-dev-interim.int.epa.rise-link.de:8443"
        ]
    },
    "professions": {
        "allowed_professions": []
    },
    "products": {
        "allowed_products": {
            "popp-client": ["0.1.0"]
        }
    },
    "token": {
        "access_token_ttl": 300,
        "refresh_token_ttl": 86400,
        "allowed_scopes": [
            "popp"
        ]
    },
    "http_methods": {
        "allowed_http_methods": ["GET", "POST"]
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
    },
    "user_blocklist": {
        "blocked_users": {}
    },
    "user_allowlist": {
        "allowed_users": [
            "3-SMC-B-Testkarte--883110000168789",    "1-SMC-B-Testkarte--883110000168754"
        ]
    }
}

# Base input that is valid
base_input = {
    "user_info": {
        "professionOID": "1.2.276.0.76.4.50",
        "identifier": "3-SMC-B-Testkarte--883110000168789"
    },
    "client_assertion": {
        "posture": {
            "product_id": "popp-client",
            "product_version": "0.1.0"
        }
    },
    "authorization_request": {
        "scopes": ["popp"],
        "audience": ["https://popp-server:30300"],
        "http_method": "GET",
        "ip_address": "1.2.3.4",
        "country_code": "DE"
    }
}

# Helper to evaluate decision with mocks
evaluate_decision(inp) := result if {
    result := authz.decision with input as inp
        with data.token as mock_data.token
        with data.http_methods as mock_data.http_methods
        with data.ip_blocklist as mock_data.ip_blocklist
        with data.ip_blocklist_tor as mock_data.ip_blocklist_tor
        with data.ip_blocklist_vpn as mock_data.ip_blocklist_vpn
        with data.ip_blocklist_countries as mock_data.ip_blocklist_countries
        with data.user_blocklist as mock_data.user_blocklist
        with data.user_allowlist as mock_data.user_allowlist
        with data.audiences_for_user_allowlist as mock_data.audiences_for_user_allowlist
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

# --- IP-Sperrlisten Tests ---

test_deny_tor_exit_node if {
    mock_tor := {"blocked_ips": ["10.0.0.1"]}
    input_tor := json.patch(base_input, [{"op": "replace", "path": "/authorization_request/ip_address", "value": "10.0.0.1"}])
    result := authz.decision with input as input_tor
        with data.token as mock_data.token
        with data.http_methods as mock_data.http_methods
        with data.ip_blocklist as mock_data.ip_blocklist
        with data.ip_blocklist_tor as mock_tor
        with data.ip_blocklist_vpn as mock_data.ip_blocklist_vpn
        with data.ip_blocklist_countries as mock_data.ip_blocklist_countries
        with data.user_blocklist as mock_data.user_blocklist
        with data.user_allowlist as mock_data.user_allowlist
    result.allow == false
    result.reasons["Source IP address is a known TOR exit node"]
}

test_deny_vpn_endpoint if {
    mock_vpn := {"blocked_ips": ["10.0.0.2"]}
    input_vpn := json.patch(base_input, [{"op": "replace", "path": "/authorization_request/ip_address", "value": "10.0.0.2"}])
    result := authz.decision with input as input_vpn
        with data.token as mock_data.token
        with data.http_methods as mock_data.http_methods
        with data.ip_blocklist as mock_data.ip_blocklist
        with data.ip_blocklist_tor as mock_data.ip_blocklist_tor
        with data.ip_blocklist_vpn as mock_vpn
        with data.ip_blocklist_countries as mock_data.ip_blocklist_countries
        with data.user_blocklist as mock_data.user_blocklist
        with data.user_allowlist as mock_data.user_allowlist
    result.allow == false
    result.reasons["Source IP address is a known VPN endpoint"]
}

test_deny_blocked_ip_range if {
    mock_blocklist := {"blocked_ips": ["192.168.0.0/16"]}
    input_blocked := json.patch(base_input, [{"op": "replace", "path": "/authorization_request/ip_address", "value": "192.168.1.100"}])
    result := authz.decision with input as input_blocked
        with data.token as mock_data.token
        with data.http_methods as mock_data.http_methods
        with data.ip_blocklist as mock_blocklist
        with data.ip_blocklist_tor as mock_data.ip_blocklist_tor
        with data.ip_blocklist_vpn as mock_data.ip_blocklist_vpn
        with data.ip_blocklist_countries as mock_data.ip_blocklist_countries
        with data.user_blocklist as mock_data.user_blocklist
        with data.user_allowlist as mock_data.user_allowlist
    result.allow == false
    result.reasons["Source IP address is in a blocked IP range"]
}

test_deny_blocked_country if {
    mock_countries := {"blocked_countries": ["RU", "CN"]}
    input_blocked_country := json.patch(base_input, [{"op": "replace", "path": "/authorization_request/country_code", "value": "RU"}])
    result := authz.decision with input as input_blocked_country
        with data.token as mock_data.token
        with data.http_methods as mock_data.http_methods
        with data.ip_blocklist as mock_data.ip_blocklist
        with data.ip_blocklist_tor as mock_data.ip_blocklist_tor
        with data.ip_blocklist_vpn as mock_data.ip_blocklist_vpn
        with data.ip_blocklist_countries as mock_countries
        with data.user_blocklist as mock_data.user_blocklist
        with data.user_allowlist as mock_data.user_allowlist
    result.allow == false
    result.reasons["Source IP address originates from a blocked country"]
}

# --- Nutzer-Sperrliste (Blocklist) Tests ---

test_deny_blocked_user if {
    mock_user_blocklist := {"blocked_users": {"1-20014060625": true}}
    input_blocked_user := json.patch(base_input, [{"op": "add", "path": "/user_info/identifier", "value": "1-20014060625"}])
    result := authz.decision with input as input_blocked_user
        with data.token as mock_data.token
        with data.http_methods as mock_data.http_methods
        with data.ip_blocklist as mock_data.ip_blocklist
        with data.ip_blocklist_tor as mock_data.ip_blocklist_tor
        with data.ip_blocklist_vpn as mock_data.ip_blocklist_vpn
        with data.ip_blocklist_countries as mock_data.ip_blocklist_countries
        with data.user_blocklist as mock_user_blocklist
        with data.user_allowlist as mock_data.user_allowlist
    result.allow == false
    result.reasons["User is on the blocklist"]
}

# --- Nutzer-Freigabeliste (Allowlist) Tests ---

# Leere Allowlist => keine Einschränkung, jeder Nutzer ist erlaubt.
test_allow_when_allowlist_empty if {
    mock_empty_allowlist := {"allowed_users": []}
    input_user := json.patch(base_input, [{"op": "replace", "path": "/user_info/identifier", "value": "irgendeine-id"}])
    result := authz.decision with input as input_user
        with data.token as mock_data.token
        with data.http_methods as mock_data.http_methods
        with data.ip_blocklist as mock_data.ip_blocklist
        with data.ip_blocklist_tor as mock_data.ip_blocklist_tor
        with data.ip_blocklist_vpn as mock_data.ip_blocklist_vpn
        with data.ip_blocklist_countries as mock_data.ip_blocklist_countries
        with data.user_blocklist as mock_data.user_blocklist
        with data.user_allowlist as mock_empty_allowlist
        with data.audiences_for_user_allowlist as mock_data.audiences_for_user_allowlist
    result.allow == true
}

# Befüllte Allowlist => nur gelistete Nutzer sind erlaubt.
test_allow_user_on_allowlist if {
    mock_allowlist := {"allowed_users": ["1-20014060625", "3-SMC-B-Testkarte--883110000168789"]}
    input_user := json.patch(base_input, [{"op": "add", "path": "/user_info/identifier", "value": "1-20014060625"}])
    result := authz.decision with input as input_user
        with data.token as mock_data.token
        with data.http_methods as mock_data.http_methods
        with data.ip_blocklist as mock_data.ip_blocklist
        with data.ip_blocklist_tor as mock_data.ip_blocklist_tor
        with data.ip_blocklist_vpn as mock_data.ip_blocklist_vpn
        with data.ip_blocklist_countries as mock_data.ip_blocklist_countries
        with data.user_blocklist as mock_data.user_blocklist
        with data.user_allowlist as mock_allowlist
        with data.audiences_for_user_allowlist as mock_data.audiences_for_user_allowlist
    result.allow == true
}

test_deny_user_not_on_allowlist if {
    mock_allowlist := {"allowed_users": ["1-20014060625", "3-SMC-B-Testkarte--883110000168789"]}
    input_user := json.patch(base_input, [{"op": "add", "path": "/user_info/identifier", "value": "FREMDE-USER-ID-999"}])
    result := authz.decision with input as input_user
        with data.token as mock_data.token
        with data.http_methods as mock_data.http_methods
        with data.ip_blocklist as mock_data.ip_blocklist
        with data.ip_blocklist_tor as mock_data.ip_blocklist_tor
        with data.ip_blocklist_vpn as mock_data.ip_blocklist_vpn
        with data.ip_blocklist_countries as mock_data.ip_blocklist_countries
        with data.user_blocklist as mock_data.user_blocklist
        with data.user_allowlist as mock_allowlist
        with data.audiences_for_user_allowlist as mock_data.audiences_for_user_allowlist
    result.allow == false
    result.reasons["User is not on the allowlist"]
}

test_deny_missing_identifier_with_enforced_allowlist if {
    mock_allowlist := {"allowed_users": ["1-20014060625"]}
    input_no_id := json.remove(base_input, ["user_info/identifier"])
    result := authz.decision with input as input_no_id
        with data.token as mock_data.token
        with data.http_methods as mock_data.http_methods
        with data.ip_blocklist as mock_data.ip_blocklist
        with data.ip_blocklist_tor as mock_data.ip_blocklist_tor
        with data.ip_blocklist_vpn as mock_data.ip_blocklist_vpn
        with data.ip_blocklist_countries as mock_data.ip_blocklist_countries
        with data.user_blocklist as mock_data.user_blocklist
        with data.user_allowlist as mock_allowlist
        with data.audiences_for_user_allowlist as mock_data.audiences_for_user_allowlist
    result.allow == false
    result.reasons["User is not on the allowlist"]
}

# Allowlist wird NICHT erzwungen, wenn die Audience nicht in
# 'audiences_for_user_allowlist' enthalten ist.
test_allow_user_not_on_allowlist_when_audience_not_enforced if {
    mock_allowlist := {"allowed_users": ["1-20014060625", "3-SMC-B-Testkarte--883110000168789"]}
    mock_audiences := {"audiences": ["https://andere-audience:8443"]}
    input_user := json.patch(base_input, [{"op": "add", "path": "/user_info/identifier", "value": "FREMDE-USER-ID-999"}])
    result := authz.decision with input as input_user
        with data.token as mock_data.token
        with data.http_methods as mock_data.http_methods
        with data.ip_blocklist as mock_data.ip_blocklist
        with data.ip_blocklist_tor as mock_data.ip_blocklist_tor
        with data.ip_blocklist_vpn as mock_data.ip_blocklist_vpn
        with data.ip_blocklist_countries as mock_data.ip_blocklist_countries
        with data.user_blocklist as mock_data.user_blocklist
        with data.user_allowlist as mock_allowlist
        with data.audiences_for_user_allowlist as mock_audiences
    result.allow == true
}
