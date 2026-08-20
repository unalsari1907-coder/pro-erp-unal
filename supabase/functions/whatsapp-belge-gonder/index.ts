const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-erp-whatsapp-key",
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
    },
  });
}

function base64ToBytes(base64: string) {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);

  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }

  return bytes;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ ok: false, error: "Yalnızca POST desteklenir." }, 405);
  }

  try {
    const clientKey = Deno.env.get("ERP_WHATSAPP_CLIENT_KEY");
    const accessToken = Deno.env.get("WHATSAPP_ACCESS_TOKEN");
    const phoneNumberId = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID");
    const graphVersion = Deno.env.get("WHATSAPP_GRAPH_VERSION");
    const templateName = Deno.env.get("WHATSAPP_TEMPLATE_NAME");
    const templateLanguage =
      Deno.env.get("WHATSAPP_TEMPLATE_LANGUAGE") ?? "tr";

    if (!clientKey || clientKey.length < 32) {
      throw new Error("ERP WhatsApp istemci anahtarı ayarlanmamış.");
    }

    if (request.headers.get("x-erp-whatsapp-key") !== clientKey) {
      return jsonResponse({ ok: false, error: "Yetkisiz istek." }, 401);
    }

    if (!accessToken || !phoneNumberId || !graphVersion) {
      throw new Error(
        "WhatsApp Business API sunucu ayarları eksik.",
      );
    }

    const body = await request.json();
    const telefon = String(body.telefon ?? "").replace(/\D/g, "");
    const mesaj = "Aldığınız parçaların belgeleri.";
    const dosyaAdi = String(body.dosya_adi ?? "belge.pdf")
      .replace(/[^a-zA-Z0-9._-]/g, "_")
      .slice(0, 120);
    const pdfBase64 = String(body.pdf_base64 ?? "");

    if (telefon.length < 10 || telefon.length > 15 || !pdfBase64) {
      return jsonResponse(
        { ok: false, error: "Telefon veya PDF eksik." },
        400,
      );
    }

    if (pdfBase64.length > 14_000_000) {
      return jsonResponse(
        { ok: false, error: "PDF dosyası çok büyük." },
        413,
      );
    }

    const graphUrl =
      `https://graph.facebook.com/${graphVersion}/${phoneNumberId}`;
    const pdfBytes = base64ToBytes(pdfBase64);

    if (
      pdfBytes.length < 5 ||
      new TextDecoder().decode(pdfBytes.slice(0, 5)) !== "%PDF-"
    ) {
      return jsonResponse(
        { ok: false, error: "Gönderilen dosya geçerli bir PDF değil." },
        400,
      );
    }

    const form = new FormData();
    form.append("messaging_product", "whatsapp");
    form.append(
      "file",
      new Blob([pdfBytes], { type: "application/pdf" }),
      dosyaAdi,
    );

    const mediaResponse = await fetch(`${graphUrl}/media`, {
      method: "POST",
      headers: { Authorization: `Bearer ${accessToken}` },
      body: form,
    });
    const mediaData = await mediaResponse.json();

    if (!mediaResponse.ok || !mediaData.id) {
      throw new Error(
        mediaData?.error?.message ?? "PDF WhatsApp'a yüklenemedi.",
      );
    }

    const messageBody = templateName
      ? {
          messaging_product: "whatsapp",
          recipient_type: "individual",
          to: telefon,
          type: "template",
          template: {
            name: templateName,
            language: { code: templateLanguage },
            components: [
              {
                type: "header",
                parameters: [
                  {
                    type: "document",
                    document: {
                      id: mediaData.id,
                      filename: dosyaAdi,
                    },
                  },
                ],
              },
            ],
          },
        }
      : {
          messaging_product: "whatsapp",
          recipient_type: "individual",
          to: telefon,
          type: "document",
          document: {
            id: mediaData.id,
            filename: dosyaAdi,
            caption: mesaj,
          },
        };

    const messageResponse = await fetch(`${graphUrl}/messages`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(messageBody),
    });
    const messageData = await messageResponse.json();

    if (!messageResponse.ok) {
      throw new Error(
        messageData?.error?.message ?? "WhatsApp mesajı gönderilemedi.",
      );
    }

    return jsonResponse({
      ok: true,
      message_id: messageData?.messages?.[0]?.id ?? null,
    });
  } catch (error) {
    return jsonResponse(
      {
        ok: false,
        error: error instanceof Error ? error.message : String(error),
      },
      500,
    );
  }
});
