// ListMessages - GET /api/messages lists the stored messages, newest first.
//
// The entities arrive through the Table Storage input binding, which reads the
// partition before the handler runs. Browsers get a page that refreshes every
// few seconds; anything else gets JSON.

const { app } = require("@azure/functions");
const { TABLE_NAME, tableInput } = require("../bindings");
const { escapeHtml, htmlResponse, wantsHtml } = require("../html");

app.http("ListMessages", {
    route: "messages",
    methods: ["GET"],
    authLevel: "anonymous",
    extraInputs: [tableInput],
    handler: async (request, context) => {
        // The binding hands over an array of entities. Locally currently passes
        // the Table service's response body ({"value": [...]}) instead, so
        // accept both.
        const raw = context.extraInputs.get(tableInput);
        const entities = Array.isArray(raw) ? raw : (raw && raw.value) || [];
        const messages = entities.map((e) => ({
            id: e.MessageId,
            text: e.Text,
            sentAt: e.SentAt,
            enqueuedAt: e.EnqueuedAt,
            deliveryCount: e.DeliveryCount,
        }));

        if (!wantsHtml(request)) {
            return { jsonBody: { count: messages.length, messages } };
        }

        const rows = messages.map((m) => `
          <tr>
            <td>${escapeHtml(m.text)}<br><small><code>${escapeHtml(m.id)}</code></small></td>
            <td><small>${escapeHtml(m.sentAt)}</small></td>
            <td><small>${escapeHtml(m.enqueuedAt)}</small></td>
          </tr>`).join("");
        return htmlResponse("Stored messages", `
          <h1>Stored messages</h1>
          <p class="flow">Read from Table Storage table <code>${escapeHtml(TABLE_NAME)}</code>. This page refreshes every 5 seconds.</p>
          <p><a href="/api/send">Send another message</a></p>
          ${messages.length === 0
            ? "<p>No messages yet.</p>"
            : `<table><thead><tr><th>Message</th><th>Sent</th><th>Enqueued</th></tr></thead><tbody>${rows}</tbody></table>`}`, 5);
    },
});
