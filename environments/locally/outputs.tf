output "send_url" {
  description = "The page (GET) and endpoint (POST) that sends a message to the queue."
  value       = module.function-app-servicebus-trigger.send_url
}

output "messages_url" {
  description = "Lists the messages the Service Bus triggered function has stored in the table."
  value       = module.function-app-servicebus-trigger.messages_url
}

output "function_app_name" {
  description = "The name of the deployed Function App."
  value       = module.function-app-servicebus-trigger.function_app_name
}

output "servicebus_namespace" {
  description = "The Service Bus namespace whose queue the functions send to and receive from."
  value       = module.function-app-servicebus-trigger.servicebus_namespace
}

output "storage_account" {
  description = "The Storage Account used as host storage and holding the messages table."
  value       = module.function-app-servicebus-trigger.storage_account
}
