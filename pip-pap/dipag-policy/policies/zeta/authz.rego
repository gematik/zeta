package policies.zeta.authz

import future.keywords.if
import future.keywords.in

# ---------------------------------------------------------------------------
# Hauptentscheidung: FEHLERFALL
# ---------------------------------------------------------------------------
decision := response if {
	failures := reasons
	count(failures) > 0
	response := {
		"allow": false,
		"reasons": failures,
	}
}

# Hauptentscheidung: ERFOLGSFALL
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

# ---------------------------------------------------------------------------
# Fehlersammlung
# ---------------------------------------------------------------------------

reasons[msg] if {
	not user_profession_is_allowed
	msg := "User profession is not allowed for DiPag"
}

reasons[msg] if {
	user_profession_is_allowed
	not scopes_match_role
	msg := "Requested scopes do not match the role of the user's profession"
}

reasons[msg] if {
	not scopes_are_valid
	msg := "One or more requested scopes are not valid DiPag scopes"
}

# ---------------------------------------------------------------------------
# Hilfsfunktionen
# ---------------------------------------------------------------------------

# Liefert die ProfessionOID des Nutzers aus dem Token-Claim
user_oid := input.user_info.professionOID

# Ist die Profession grundsätzlich für DiPag zugelassen?
user_profession_is_allowed if {
	user_oid in data.professions.profession_to_role
}

# Ermittelt die Rolle des Nutzers anhand seiner ProfessionOID
user_role := data.professions.profession_to_role[user_oid]

# Die erlaubten Scopes für die Rolle des Nutzers
allowed_scopes_for_role := {s | s := data.professions.role_to_scopes[user_role][_]}

# Angeforderte Scopes als Menge
requested_scope_set := {s | s := input.authorization_request.scopes[_]}

# Alle gültigen DiPag-Scopes (union aller Rollen)
all_valid_scopes := {s |
	some role
	data.professions.role_to_scopes[role]
	s := data.professions.role_to_scopes[role][_]
}

# Sind die angeforderten Scopes eine Teilmenge der Rolle?
scopes_match_role if {
	count(requested_scope_set) > 0
	requested_scope_set - allowed_scopes_for_role == set()
}

# Sind die angeforderten Scopes überhaupt gültige DiPag-Scopes?
scopes_are_valid if {
	count(requested_scope_set) > 0
	requested_scope_set - all_valid_scopes == set()
}

# ---------------------------------------------------------------------------
# Weitere Helper (optional nutzbar, aktuell nicht als Fehler aktiviert)
# ---------------------------------------------------------------------------

client_product_is_allowed if {
	allowed_versions := data.products.allowed_products[input.client_registration_data.product_id]
	some i
	input.client_registration_data.product_version == allowed_versions[i]
}

audience_is_allowed if {
	allowed_audience_set := {s | s := data.audiences.allowed_audiences[_]}
	requested_audience_set := {audience | audience := input.authorization_request.audience[_]}
	count(requested_audience_set) > 0
	requested_audience_set - allowed_audience_set == set()
}
