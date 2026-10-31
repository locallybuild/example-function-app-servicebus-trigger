# ---------------------------------------------------------------------------
# Service Bus - the queue the HTTP function sends to and the Service Bus
# triggered function receives from.
#
# Local (SAS key) authentication is disabled, so there's no connection string
# to leak: the only way in is an Entra access token, which the Functions host
# obtains for the app's managed identity.
# ---------------------------------------------------------------------------
resource "azurerm_servicebus_namespace" "main" {
  name                = "${var.name_prefix}-bus"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Standard"
  local_auth_enabled  = false
  tags                = var.tags
}

resource "azurerm_servicebus_queue" "messages" {
  name         = "messages"
  namespace_id = azurerm_servicebus_namespace.main.id

  # A message that fails processing this many times is moved to the
  # dead-letter sub-queue rather than being retried forever.
  max_delivery_count = 5
}

# ---------------------------------------------------------------------------
# Data-plane role assignments, scoped to the queue rather than the namespace.
#
# One Function App both sends (the output binding on SendMessage) and receives
# (the trigger on StoreMessage), so its identity needs both roles.
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "servicebus_sender" {
  scope                = azurerm_servicebus_queue.messages.id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = azurerm_user_assigned_identity.function.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "servicebus_receiver" {
  scope                = azurerm_servicebus_queue.messages.id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = azurerm_user_assigned_identity.function.principal_id
  principal_type       = "ServicePrincipal"
}
