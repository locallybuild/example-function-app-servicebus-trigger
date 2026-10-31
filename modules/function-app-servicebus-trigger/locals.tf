locals {
  # A hash of everything in function/, node_modules included, so any change to
  # the code or its dependencies produces a new package name and a redeploy.
  function_dir  = "${path.module}/../../function"
  function_hash = substr(sha1(join(",", [for f in sort(fileset(local.function_dir, "**")) : "${f}:${filesha1("${local.function_dir}/${f}")}"])), 0, 12)

  # Terraform hands over the namespace's endpoint URL
  # ("https://<name>.servicebus.windows.net:443/"); the Service Bus extension
  # wants just its hostname as the fully qualified namespace.
  servicebus_fqdn = regex("^https://([^:/]+)", azurerm_servicebus_namespace.main.endpoint)[0]
}
