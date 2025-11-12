package policies.zeta.authz

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

# --- HELPER-REGELN ---

user_profession_is_allowed if {
	# KORRIGIERTER PFAD
	some i
	input.user_info.professionOID == data.professions.allowed_professions[i]
}

client_product_is_allowed if {
	posture := input.client_assertion.posture

	# KORRIGIERTER PFAD
	allowed_versions := data.products.allowed_products[posture.product_id]
	some i
	posture.product_version == allowed_versions[i]
}

scopes_are_allowed if {
	# KORRIGIERTER PFAD
	allowed_scope_set := {s | s := data.token_config.allowed_scopes[_]}
	requested_scope_set := {s | s := input.authorization_request.scopes[_]}
	requested_scope_set - allowed_scope_set == set()
}

audience_is_allowed if {
	# KORRIGIERTER PFAD
	allowed_audience_set := {s | s := data.audiences.allowed_audiences[_]}
	requested_audience_set := {audience | audience := input.authorization_request.audience[_]}
	requested_audience_set - allowed_audience_set == set()
}
