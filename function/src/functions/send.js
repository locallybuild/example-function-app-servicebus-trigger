// SendMessage - puts a message on the Service Bus queue.
//
//   GET  /api/send  a small form to type a message into
//   POST /api/send  sends the body: a form post, JSON ({"text": "..."}) or plain text
//
// The message leaves through the Service Bus output binding: whatever is set on
// it when the handler returns, the host sends to the queue. There's no Service
// Bus client or credential in this code.

const { randomUUID } = require("node:crypto");
const { app } = require("@azure/functions");
const { QUEUE_NAME, queueOutput } = require("../bindings");
const { escapeHtml, htmlResponse, wantsHtml } = require("../html");

const MAX_LENGTH = 1000;

async function readText(request) {
    const contentType = request.headers.get("content-type") || "";
    if (contentType.includes("application/json")) {
        const body = await request.json().catch(() => ({}));
        return String((body && body.text) || "");
    }
    if (contentType.includes("application/x-www-form-urlencoded")) {
        const form = await request.formData();
        return String(form.get("text") || "");
    }
    return request.text();
}

function sendForm(notice) {
    return htmlResponse("Send a message", `
      <h1>Send a message</h1>
      <p class="flow">HTTP function &rarr; <strong>Service Bus queue <code>${escapeHtml(QUEUE_NAME)}</code></strong> &rarr; Service Bus triggered function &rarr; Table Storage</p>
      ${notice || ""}
      <form class="send" method="post" action="/api/send">
        <input name="text" placeholder="Write a message..." required maxlength="${MAX_LENGTH}" autofocus>
        <button type="submit">Send</button>
      </form>
      <p><a href="/api/messages">See the stored messages</a></p>`);
}

app.http("SendMessage", {
    route: "send",
    methods: ["GET", "POST"],
    authLevel: "anonymous",
    extraOutputs: [queueOutput],
    handler: async (request, context) => {
        if (request.method === "GET") {
            return sendForm();
        }

        const text = (await readText(request)).trim();
        if (!text || text.length > MAX_LENGTH) {
            return { status: 400, jsonBody: { error: `text must be 1-${MAX_LENGTH} characters` } };
        }

        const id = randomUUID();
        context.extraOutputs.set(queueOutput, { id, text, sentAt: new Date().toISOString() });
        context.log(`SendMessage: queued message ${id} on ${QUEUE_NAME}`);

        if (wantsHtml(request)) {
            return sendForm(`<p class="notice">Sent message <code>${escapeHtml(id)}</code>. <a href="/api/messages">See it arrive &rarr;</a></p>`);
        }
        return { status: 202, jsonBody: { id, queue: QUEUE_NAME } };
    },
});
