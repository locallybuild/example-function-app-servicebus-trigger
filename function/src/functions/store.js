// StoreMessage - the Service Bus triggered function.
//
// The host receives from the queue and calls this once per message; whatever is
// set on the table output binding is written to Table Storage as an entity. If
// the handler throws, the message is abandoned and redelivered, and after the
// queue's max delivery count it moves to the dead-letter sub-queue.

const { app } = require("@azure/functions");
const { QUEUE_NAME, PARTITION_KEY, tableOutput } = require("../bindings");

// Row keys sort as strings, so subtracting the enqueue time from a fixed
// maximum orders the partition newest first. The message ID keeps the key
// unique, and a redelivered message overwrites its own row rather than being
// stored twice.
const MAX_TICKS = 9999999999999;

function rowKey(enqueuedTimeUtc, messageId) {
    const ms = Date.parse(enqueuedTimeUtc) || Date.now();
    return `${String(MAX_TICKS - ms).padStart(13, "0")}-${messageId}`;
}

app.serviceBusQueue("StoreMessage", {
    queueName: QUEUE_NAME,
    connection: "ServiceBusConnection",
    extraOutputs: [tableOutput],
    handler: async (message, context) => {
        const meta = context.triggerMetadata || {};
        // The body is JSON when it came from SendMessage, but anything sent to
        // the queue by other means is stored as-is.
        const body = typeof message === "object" && message !== null ? message : { text: String(message) };

        const entity = {
            PartitionKey: PARTITION_KEY,
            RowKey: rowKey(meta.enqueuedTimeUtc, meta.messageId),
            // The ID SendMessage returned to its caller, so the two can be matched.
            MessageId: String(body.id || meta.messageId || ""),
            Text: String(body.text || ""),
            SentAt: String(body.sentAt || ""),
            EnqueuedAt: String(meta.enqueuedTimeUtc || ""),
            DeliveryCount: Number(meta.deliveryCount || 1),
        };
        context.extraOutputs.set(tableOutput, entity);
        context.log(`StoreMessage: stored message ${entity.MessageId} (delivery ${entity.DeliveryCount}) as ${entity.RowKey}`);
    },
});
