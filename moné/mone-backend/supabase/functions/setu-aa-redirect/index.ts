function htmlResponse(html: string, status = 200) {
  return new Response(html, {
    status,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
    },
  });
}

Deno.serve(async (req) => {
  const url = new URL(req.url);

  const success = url.searchParams.get("success");
  const consentId = url.searchParams.get("id");
  const errorCode = url.searchParams.get("errorcode");
  const errorMessage = url.searchParams.get("errormsg");

  console.log("setu_aa_redirect_received", {
    success,
    consentId,
    errorCode,
    errorMessage,
  });

  const isSuccess = success === "true";

  return htmlResponse(`
    <!doctype html>
    <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Moné</title>
        <style>
          body {
            margin: 0;
            background: #0b0b0b;
            color: #f4f1eb;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            padding: 32px;
          }
          .card {
            max-width: 420px;
            text-align: center;
          }
          .brand {
            font-family: Georgia, serif;
            font-size: 42px;
            margin-bottom: 48px;
          }
          h1 {
            font-family: Georgia, serif;
            font-size: 36px;
            line-height: 1.1;
            margin: 0 0 16px;
          }
          p {
            color: #b8b5ad;
            line-height: 1.5;
          }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="brand">moné</div>
          <h1>${isSuccess ? "Consent received" : "Consent not completed"}</h1>
          <p>
            ${isSuccess
              ? "You can return to the Moné app now."
              : "The consent flow was cancelled, rejected, or could not be completed."}
          </p>
        </div>
      </body>
    </html>
  `);
});