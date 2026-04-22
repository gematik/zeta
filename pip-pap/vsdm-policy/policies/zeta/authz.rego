package policies.zeta.authz

import future.keywords.if
import future.keywords.in

# Regel 1: Definiert 'decision' für den FEHLERFALL.
decision := response if {
	failures := reasons
	count(failures) > 0
	response := {
		"allow": false,
		"reasons": failures,
	}
}

# Regel 2: Definiert 'decision' für den ERFOLGSFALL.
decision := response if {
	count(reasons) == 0
	response := {
		"allow": true,
		"ttl": {
			"access_token": data.token.access_token_ttl,
			"refresh_token": data.token.refresh_token_ttl,
		},
	}
}

# Regel zum Sammeln von Fehlern
reasons[msg] if {
	not user_profession_is_allowed
	msg := "User profession is not allowed"
}

reasons[msg] if {
	not client_product_is_allowed
	msg := "Client product or version is not allowed"
}

reasons[msg] if {
	not scopes_are_allowed
	msg := "One or more requested scopes are not allowed"
}

reasons[msg] if {
	not audience_is_allowed
	msg := "One or more requested audiences are not allowed"
}

reasons[msg] if {
	not http_method_is_allowed
	msg := "HTTP method is not allowed"
}

reasons[msg] if {
	ip_is_tor_exit_node
	msg := "Source IP address is a known TOR exit node"
}

reasons[msg] if {
	ip_is_vpn_endpoint
	msg := "Source IP address is a known VPN endpoint"
}

reasons[msg] if {
	ip_is_in_blocked_range
	msg := "Source IP address is in a blocked IP range"
}

reasons[msg] if {
	country_is_blocked
	msg := "Source IP address originates from a blocked country"
}

# --- HELPER-REGELN ---

user_profession_is_allowed if {
	some i
	input.user_info.professionOID == data.professions.allowed_professions[i]
}

client_product_is_allowed if {
	posture := input.client_assertion.posture

	allowed_versions := data.products.allowed_products[posture.product_id]
	some i
	posture.product_version == allowed_versions[i]
}

scopes_are_allowed if {
	allowed_scope_set := {s | s := data.token.allowed_scopes[_]}
	requested_scope_set := {s | s := input.authorization_request.scopes[_]}
	count(requested_scope_set) > 0
	requested_scope_set - allowed_scope_set == set()
}

audience_is_allowed if {
	allowed_audience_set := {s | s := data.audiences.allowed_audiences[_]}
	requested_audience_set := {audience | audience := input.authorization_request.audience[_]}
	count(requested_audience_set) > 0
	requested_audience_set - allowed_audience_set == set()
}

http_method_is_allowed if {
	some i
	input.authorization_request.http_method == data.http_methods.allowed_http_methods[i]
}

# --- IP-SPERRLISTEN-HILFSFUNKTIONEN ---

# Trifft für einen einzelnen Eintrag (IP oder CIDR) zu.
ip_matches_entry(entry) if entry == input.authorization_request.ip_address
ip_matches_entry(entry) if net.cidr_contains(entry, input.authorization_request.ip_address)

# Trifft zu wenn mindestens ein Eintrag der übergebenen Liste passt.
any_ip_matches(blocklist) if {
	some entry in blocklist
	ip_matches_entry(entry)
}

# TOR-Exitknoten-Sperrliste
ip_is_tor_exit_node if any_ip_matches(data.ip_blocklist_tor.blocked_ips)

# VPN-Endpunkt-Sperrliste
ip_is_vpn_endpoint if any_ip_matches(data.ip_blocklist_vpn.blocked_ips)

# Generische IP/Range-Sperrliste
ip_is_in_blocked_range if any_ip_matches(data.ip_blocklist.blocked_ips)

# Länder-Sperrliste (country_code wird von AuthS per GeoIP befüllt)
country_is_blocked if {
	input.authorization_request.country_code in data.ip_blocklist_countries.blocked_countries
}

# Nutzer-spezifische Sperrliste
user_is_blocked if {
	user_id := input.user_info.identifier
	user_blocklist := data.user_blocklist.blocked_users[user_id]
	user_blocklist == true
}
