output "send_url" {
  description = "The page (GET) and endpoint (POST) that sends a message to the queue."
  value       = "https://${azurerm_linux_function_app.main.default_hostname}/api/send"
}

output "messages_url" {
  description = "Lists the messages the Service Bus triggered function has stored in the table."
  value       = "https://${azurerm_linux_function_app.main.default_hostname}/api/messages"
}

output "function_app_name" {
  description = "The name of the deployed Function App."
  value       = azurerm_linux_function_app.main.name
}

output "resource_group" {
  description = "The resource group containing the deployed resources."
  value       = azurerm_resource_group.main.name
}

output "servicebus_namespace" {
  description = "The Service Bus namespace whose queue the functions send to and receive from."
  value       = azurerm_servicebus_namespace.main.name
}

output "storage_account" {
  description = "The Storage Account used as host storage and holding the messages table."
  value       = azurerm_storage_account.main.name
}
