// =====================================================================
// CORNERWORK: estimate-food (a Supabase Edge Function)
//
// GOAL: the app sends a meal description and/or a photo. This function
// asks Claude to estimate calories and protein, and sends the numbers back.
//
// WHY A SERVER PIECE: the AI key costs money per use, so it must stay
// secret. A web page is public; anyone could copy a key out of it.
// This function runs on Supabase's servers, where the key is hidden.
// Analogy: the app passes a note through the kitchen window; only the
// kitchen has the key to the pantry.
//
// Only signed-in CornerWork users can call it (Supabase checks the login).
// =====================================================================

// Lets the app (on github.io) talk to this function (on supabase.co).
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// The instructions we give the AI every time.
const PROMPT = `You estimate nutrition for an athlete's food log.
Estimate the TOTAL calories and protein for everything described or shown.
If amounts are missing, assume one typical portion and say what you assumed.
Reply with ONLY this JSON and nothing else:
{"calories": number, "protein_g": number, "summary": "short list of items with assumed amounts"}`;

// Small helper: send a JSON reply.
function reply(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  // Browsers send a quick "may I?" check first. Always say yes.
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { description, image } = await req.json();

    // Basic checks so nobody sends empty or huge requests.
    if (!description && !image) {
      return reply({ error: "Describe the food or add a photo." }, 400);
    }
    if (description && description.length > 1000) {
      return reply({ error: "Description is too long. Keep it under 1000 characters." }, 400);
    }
    if (image && image.length > 3_000_000) {
      return reply({ error: "Photo is too large." }, 400);
    }

    // Build the message: optional photo first, then the text.
    const content: unknown[] = [];
    if (image) {
      content.push({
        type: "image",
        source: { type: "base64", media_type: "image/jpeg", data: image },
      });
    }
    content.push({
      type: "text",
      text: PROMPT + (description ? "\n\nFood: " + description : ""),
    });

    // Ask Claude. Haiku is the fast, low-cost model: right for small estimates.
    const aiResponse = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": Deno.env.get("ANTHROPIC_API_KEY") ?? "",
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: "claude-haiku-5-5",
        max_tokens: 300,
        messages: [{ role: "user", content }],
      }),
    });

    const data = await aiResponse.json();
    if (!aiResponse.ok) {
      return reply({ error: data?.error?.message ?? "The AI request failed." }, 502);
    }

    // Pull the JSON out of the AI's answer.
    const text: string = data.content?.[0]?.text ?? "";
    const match = text.match(/\{[\s\S]*\}/);
    if (!match) {
      return reply({ error: "Couldn't read the estimate. Try describing it differently." }, 502);
    }
    const estimate = JSON.parse(match[0]);

    return reply({
      calories: Math.round(Number(estimate.calories)),
      protein_g: Math.round(Number(estimate.protein_g) * 10) / 10,
      summary: String(estimate.summary ?? ""),
    });
  } catch (error) {
    return reply({ error: String(error) }, 500);
  }
});
