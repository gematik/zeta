insecure_tls       = true                          # Aktivieren bei selbst signierten Zertifikaten (optional, Default ist false)
keycloak_url       = "https://example.domain/auth" # Externe URL des Keycloak-Servers
keycloak_namespace = "zeta-demo"                   # Namespace des Authservers im Cluster
pdp_scopes         = ["zero:read", "zero:write"]   # Zusätzliche PDP-Scopes
