# ---------------------------------------------------------------------------
# Storage Account - used twice over:
#
#   * as the Functions host's own storage (AzureWebJobsStorage), where it keeps
#     its keys, locks and bookkeeping.
#   * for the "messages" table, which StoreMessage writes each message into.
#
# Shared key access is disabled, so both the host and the table bindings
# authenticate with an Entra access token for the managed identity rather than
# an account key.
# ---------------------------------------------------------------------------
resource "azurerm_storage_account" "main" {
  name                            = substr(replace(var.name_prefix, "-", ""), 0, 24)
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false
  tags                            = var.tags
}

resource "azurerm_storage_table" "messages" {
  name               = "messages"
  storage_account_id = azurerm_storage_account.main.id
}

# ---------------------------------------------------------------------------
# Data-plane role assignments.
#
# Storage Table Data Contributor lets the table bindings read and write
# entities. Storage Blob Data Owner and Storage Queue Data Contributor are what
# the Functions host needs to use the account as its AzureWebJobsStorage over
# an identity connection (host keys and leases live in blobs, and some
# triggers use queues internally).
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "storage" {
  for_each = toset([
    "Storage Table Data Contributor",
    "Storage Blob Data Owner",
    "Storage Queue Data Contributor",
  ])

  scope                = azurerm_storage_account.main.id
  role_definition_name = each.value
  principal_id         = azurerm_user_assigned_identity.function.principal_id
  principal_type       = "ServicePrincipal"
}
