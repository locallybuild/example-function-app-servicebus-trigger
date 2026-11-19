# ---------------------------------------------------------------------------
# App Service Plan - hosts the Function App
# ---------------------------------------------------------------------------
resource "azurerm_service_plan" "main" {
  name                = "${var.name_prefix}-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = var.service_plan_sku
}

# ---------------------------------------------------------------------------
# Function App package - zips function/ from the inside, so host.json lands at
# the root of the archive (a zip containing a function/ directory deploys an
# app with no functions in it). Run `npm install` in function/ first so its
# node_modules are included in the archive.
#
# The archive's name carries a hash of function/ (see locals.tf). The provider
# only redeploys when zip_deploy_file changes, so a fixed name would leave
# code changes undeployed.
# ---------------------------------------------------------------------------
data "archive_file" "function" {
  type        = "zip"
  source_dir  = local.function_dir
  output_path = "${path.module}/../../.build/function-${local.function_hash}.zip"
}

# ---------------------------------------------------------------------------
# The Function App, with its code.
#
# zip_deploy_file pushes the package over the site's SCM plane during apply,
# so a single `terraform apply` leaves a running app rather than an empty one.
# WEBSITE_RUN_FROM_PACKAGE = "1" is what the provider requires alongside it.
#
# Every connection is identity-based. A binding's `connection` property in the
# code ("ServiceBusConnection", "TableConnection") names a prefix, and the
# host builds the connection from the app settings under that prefix: where to
# connect (fullyQualifiedNamespace / tableServiceUri), how to authenticate
# (credential = managedidentity) and which identity to use (clientId). The
# host's own storage works the same way under the AzureWebJobsStorage prefix:
# storage_uses_managed_identity sets AzureWebJobsStorage__accountName instead
# of a connection string, and the two settings below pick the identity.
# ---------------------------------------------------------------------------
resource "azurerm_linux_function_app" "main" {
  name                = "${var.name_prefix}-func"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true
  tags                = var.tags

  storage_account_name          = azurerm_storage_account.main.name
  storage_uses_managed_identity = true

  zip_deploy_file = data.archive_file.function.output_path

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.function.id]
  }

  site_config {
    # Keeps the host running, so the Service Bus trigger is always listening
    # rather than only once an HTTP request has woken the app.
    always_on = true

    application_stack {
      node_version = "24"
    }
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "node"

    # Required by the provider whenever zip_deploy_file is set.
    WEBSITE_RUN_FROM_PACKAGE = "1"

    # The host's own storage, over the managed identity.
    AzureWebJobsStorage__credential = "managedidentity"
    AzureWebJobsStorage__clientId   = azurerm_user_assigned_identity.function.client_id

    # The Service Bus trigger and output binding. The namespace only accepts
    # Entra access tokens.
    ServiceBusConnection__fullyQualifiedNamespace = local.servicebus_fqdn
    ServiceBusConnection__credential              = "managedidentity"
    ServiceBusConnection__clientId                = azurerm_user_assigned_identity.function.client_id
    SERVICEBUS_QUEUE                              = azurerm_servicebus_queue.messages.name

    # The table input and output bindings. Shared key access is disabled.
    TableConnection__tableServiceUri = trimsuffix(azurerm_storage_account.main.primary_table_endpoint, "/")
    TableConnection__credential      = "managedidentity"
    TableConnection__clientId        = azurerm_user_assigned_identity.function.client_id
    TABLE_NAME                       = azurerm_storage_table.messages.name
  }

  # The identity must hold its roles before the host starts and opens its
  # connections.
  depends_on = [
    azurerm_role_assignment.servicebus_sender,
    azurerm_role_assignment.servicebus_receiver,
    azurerm_role_assignment.storage,
  ]
}
