// The bindings the functions share.
//
// None of them holds a connection string. `connection` names a prefix, and the
// Functions host reads its settings from the app settings with that prefix
// (see 5-function-app.tf):
//
//   ServiceBusConnection__fullyQualifiedNamespace  the namespace to connect to
//   ServiceBusConnection__credential               "managedidentity"
//   ServiceBusConnection__clientId                 which user-assigned identity
//
// and likewise TableConnection__tableServiceUri / __credential / __clientId for
// Table Storage. The host asks the managed identity for an Entra token and the
// function code never sees a credential at all.

const { input, output } = require("@azure/functions");

const QUEUE_NAME = process.env.SERVICEBUS_QUEUE || "messages";
const TABLE_NAME = process.env.TABLE_NAME || "messages";

// Every message is stored in one partition. The row key orders the partition
// newest first (see store.js), so listing it needs no sort.
const PARTITION_KEY = "messages";

const queueOutput = output.serviceBusQueue({
    queueName: QUEUE_NAME,
    connection: "ServiceBusConnection",
});

const tableOutput = output.table({
    tableName: TABLE_NAME,
    connection: "TableConnection",
});

const tableInput = input.table({
    tableName: TABLE_NAME,
    partitionKey: PARTITION_KEY,
    take: 50,
    connection: "TableConnection",
});

module.exports = { QUEUE_NAME, TABLE_NAME, PARTITION_KEY, queueOutput, tableOutput, tableInput };
