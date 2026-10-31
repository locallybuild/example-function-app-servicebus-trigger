# ---------------------------------------------------------------------------
# User-Assigned Managed Identity - the Function App runs as this identity.
#
# The Functions host uses it for every connection it makes: to the Service Bus
# queue (for the trigger and the output binding), to the table (for the table
# bindings), and to its own host storage. There are no keys or connection
# strings anywhere in the app's settings.
#
# A user-assigned (rather than system-assigned) identity exists before the
# Function App does, so its role assignments are granted up front - the host
# has access from the moment it starts, rather than racing a grant that lands
# later.
# ---------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "function" {
  name                = "${var.name_prefix}-id"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags
}
