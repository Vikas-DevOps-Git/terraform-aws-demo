# Enable Kubernetes auth method
resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "main" {
  backend            = vault_auth_backend.kubernetes.path
  kubernetes_host    = var.kubernetes_host
  kubernetes_ca_cert = var.kubernetes_ca_cert
}

# Secret engine for each environment
resource "vault_mount" "kv" {
  path        = "${var.environment}/secrets"
  type        = "kv-v2"
  description = "KV v2 secrets for ${var.environment}"
}

# Policy — least privilege, read-only for app pods
resource "vault_policy" "app_read" {
  name = "${var.environment}-app-read"
  policy = <<EOT
path "${var.environment}/secrets/data/{{identity.entity.aliases.${vault_auth_backend.kubernetes.accessor}.metadata.service_account_namespace}}/*" {
  capabilities = ["read", "list"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOT
}

# Role binding ServiceAccount to policy
resource "vault_kubernetes_auth_backend_role" "app" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "${var.environment}-app-role"
  bound_service_account_names      = var.service_account_names
  bound_service_account_namespaces = var.namespaces
  token_ttl                        = 3600
  token_policies                   = [vault_policy.app_read.name]
}

# Dynamic DB secret engine (demonstrates rotation)
resource "vault_database_secret_backend_engine" "postgres" {
  count   = var.enable_db_engine ? 1 : 0
  backend = vault_mount.kv.path
  name    = "postgres"
}
