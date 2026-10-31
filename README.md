```
ooooo                                      oooo  oooo              
`888'                                      `888  `888              
 888          .ooooo.   .ooooo.   .oooo.    888   888  oooo    ooo 
 888         d88' `88b d88' `"Y8 `P  )88b   888   888   `88.  .8'
 888         888   888 888        .oP"888   888   888    `88..8'
 888       o 888   888 888   .o8 d8(  888   888   888     `888'
o888ooooood8 `Y8bod8P' `Y8bod8P' `Y888""8o o888o o888o     .8'
                                                       .o..P'
                                                       `Y8P'
```

# Example: Pass messages from a Function App through Service Bus into Table Storage within Locally

This example shows how a Function App can send messages to an Azure Service Bus queue, pick them up again with a Service Bus trigger and store each one in Azure Table Storage on [Locally Build](https://locally.build). The function code holds no keys, connection strings or passwords, and makes no SDK calls of its own: every connection goes through a Functions binding, and the Functions host authenticates each one with the app's **user-assigned managed identity**.

```
 Function App (Linux, Node.js)
   │
   ├─ SendMessage   (HTTP POST /api/send)
   │     └─ Service Bus output binding ─▶ Service Bus queue "messages"
   │                                            │
   ├─ StoreMessage  (Service Bus trigger) ◀─────┘
   │     └─ Table output binding ─▶ Table Storage table "messages"
   │                                            │
   └─ ListMessages  (HTTP GET /api/messages)    │
         └─ Table input binding ◀───────────────┘
```

This is the serverless counterpart of [example-app-service-servicebus](https://github.com/locallybuild/example-app-service-servicebus): the same flow, but with the Functions host doing the sending, receiving and storing. The code lives in [`function/`](./function), written in JavaScript with the Node.js v4 programming model, alongside the infrastructure that runs it. There are three functions:

* **SendMessage** - `GET /api/send` serves a small form, and `POST /api/send` puts its body on the queue. The body can be a form post, JSON (`{"text": "..."}`) or plain text.
* **StoreMessage** - triggered by each message on the queue, and writes it as an entity in the table.
* **ListMessages** - `GET /api/messages` lists the stored messages, newest first. Browsers get a page that refreshes every few seconds; anything else gets JSON.

### Identity-based connections

Each binding names a connection, for example `connection: "ServiceBusConnection"` in [`function/src/bindings.js`](./function/src/bindings.js). Instead of a connection string, the host reads a group of app settings with that prefix:

| App setting | Value |
| --- | --- |
| `ServiceBusConnection__fullyQualifiedNamespace` | the namespace's hostname |
| `ServiceBusConnection__credential` | `managedidentity` |
| `ServiceBusConnection__clientId` | the identity's client ID |
| `TableConnection__tableServiceUri` | the Storage Account's table endpoint |
| `TableConnection__credential` | `managedidentity` |
| `TableConnection__clientId` | the identity's client ID |
| `AzureWebJobsStorage__accountName` | the Storage Account (set by `storage_uses_managed_identity`) |
| `AzureWebJobsStorage__credential` | `managedidentity` |
| `AzureWebJobsStorage__clientId` | the identity's client ID |

The `clientId` settings matter because the identity is user-assigned: without them the host asks for a system-assigned identity, which this app doesn't have. The last three cover the Functions host's own storage, where it keeps its keys and locks.

### Roles

The one identity holds only the roles the app needs:

| Role | Scope | Used by |
| --- | --- | --- |
| Azure Service Bus Data Sender | the `messages` queue | SendMessage's output binding |
| Azure Service Bus Data Receiver | the `messages` queue | StoreMessage's trigger |
| Storage Table Data Contributor | the Storage Account | the table bindings |
| Storage Blob Data Owner | the Storage Account | the Functions host's storage |
| Storage Queue Data Contributor | the Storage Account | the Functions host's storage |

Shared-key and SAS authentication are switched off on both the Service Bus namespace (`local_auth_enabled = false`) and the Storage Account (`shared_access_key_enabled = false`), so an Entra token is the only way in.

## Requirements

* [Locally Build](https://locally.build).
* Either [HashiCorp Terraform](https://terraform.io) or [OpenTofu](https://opentofu.org).
* Either [Docker](https://www.docker.com) or [Podman](https://podman.io) (recommended).
* [Node.js](https://nodejs.org) 22+, to install the functions' dependencies.
* The Locally Plugin for `Microsoft.ServiceBus` installed (`locally plugin install --name Microsoft.ServiceBus`).
* The Locally Plugin for `Microsoft.Storage` installed (`locally plugin install --name Microsoft.Storage`).
* The Locally Plugin for `Microsoft.Web` installed (`locally plugin install --name Microsoft.Web`).
* The Locally Plugin for `Microsoft.OperationalInsights` installed (`locally plugin install --name Microsoft.OperationalInsights`).
* The Locally Plugin for `Microsoft.Insights` installed (`locally plugin install --name Microsoft.Insights`).

## Running the example

First, make sure your container runtime (Docker or Podman) is running, then start Locally:

```bash
locally build
```

The Function App is deployed from a zip that Terraform builds from `function/`, and the zip has to include the functions' dependencies, so install them first:

```bash
cd function
npm install
cd ..
```

With Locally running, open another terminal and initialise Terraform. This downloads the providers and sets up the module:

```bash
cd environments/locally
terraform init
```

> [!NOTE]
> You can use OpenTofu instead by running `tofu` wherever this says `terraform`.

Once Terraform is initialised, provision the example:

```bash
locally run terraform apply
```

One apply creates the Service Bus queue, the Storage Account and table, the identity and its roles, and the Function App, and pushes the code into the app. When it finishes, the URLs are in the outputs:

```
send_url     = "https://locally-example-sbfunc-func.furnace.locally:5663/api/send"
messages_url = "https://locally-example-sbfunc-func.furnace.locally:5663/api/messages"
```

[Open the send page](https://locally-example-sbfunc-func.furnace.locally:5663/api/send) and send a message, then follow the link to [the stored messages](https://locally-example-sbfunc-func.furnace.locally:5663/api/messages). The message appears there once StoreMessage has taken it off the queue and written it to the table.

---

You can do the same from the command line:

```bash
curl -X POST -H 'Content-Type: application/json' -d '{"text": "hello"}' "$(locally run terraform output -raw send_url)"
curl "$(locally run terraform output -raw messages_url)"
```

To peek at messages still on the queue (it's normally empty, because StoreMessage drains it straight away):

```bash
locally servicebus queue peek --namespace locally-example-sbfunc-bus --name messages
```

The functions send their logs to a Log Analytics Workspace. You can query them in [the Monitoring section of the Locally Dashboard](https://localhost:5678/monitoring/components) by running:

```
FunctionAppLogs | order by TimeGenerated desc
```

## Notes

The HTTP functions use `authLevel: "anonymous"`, so anyone who can reach the app can send messages and read them. That keeps the example focused on the bindings and identity wiring. A real app would require a function key or sit behind authentication.

If StoreMessage throws, the message goes back on the queue and is retried. After 5 failed deliveries it moves to the dead-letter sub-queue. Each row's key comes from when the message was enqueued plus its ID, so a redelivered message overwrites its own row instead of being stored twice, and the partition reads back newest first.

Terraform writes the package to `.build/function-<hash>.zip`, where the hash covers everything in `function/`. The provider only redeploys the code when `zip_deploy_file` changes, so the hash in the name is what makes an edit to the code (or an `npm install`) reach the app on the next apply.

`host.json` pulls in the Functions extension bundle (v4), which provides the Service Bus and Tables bindings and their support for identity-based connections. `always_on` keeps the host running so the Service Bus trigger is always listening.

Because shared-key access is disabled on the Storage Account, the provider sets `storage_use_azuread = true` so that Terraform also uses Entra ID to manage the table.

## Tearing it down

```bash
cd environments/locally
locally run terraform destroy
```
