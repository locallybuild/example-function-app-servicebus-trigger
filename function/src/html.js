// Minimal HTML helpers for the two pages the functions serve.

function escapeHtml(value) {
    return String(value)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#39;");
}

function renderPage(title, body, refreshSeconds) {
    return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  ${refreshSeconds ? `<meta http-equiv="refresh" content="${refreshSeconds}">` : ""}
  <title>${escapeHtml(title)}</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 52rem; margin: 2rem auto; padding: 0 1rem; }
    form.send { display: flex; gap: 0.5rem; margin-bottom: 1rem; }
    form.send input { flex: 1; padding: 0.4rem; }
    .flow { color: #555; }
    .notice { background: #eef7ee; border: 1px solid #9c9; padding: 0.5rem 0.75rem; }
    table { border-collapse: collapse; width: 100%; }
    th, td { text-align: left; padding: 0.4rem; border-bottom: 1px solid #ddd; vertical-align: top; }
    td small { color: #666; }
  </style>
</head>
<body>
${body}
</body>
</html>`;
}

function htmlResponse(title, body, refreshSeconds) {
    return {
        headers: { "Content-Type": "text/html; charset=utf-8" },
        body: renderPage(title, body, refreshSeconds),
    };
}

// Browsers ask for text/html; curl and API clients get JSON.
function wantsHtml(request) {
    return (request.headers.get("accept") || "").includes("text/html");
}

module.exports = { escapeHtml, htmlResponse, wantsHtml };
