import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const { messages, stockContext } = await req.json();
    const LOVABLE_API_KEY = Deno.env.get("LOVABLE_API_KEY");
    if (!LOVABLE_API_KEY) throw new Error("LOVABLE_API_KEY is not configured");

    const systemPrompt = `You are **StockPro AI** — an expert Stock Management Assistant. You analyze inventory data and provide clear, actionable insights.

## Current Stock Data
${stockContext}

## Your Capabilities
- Stock level analysis & summaries
- Reorder recommendations
- Expired items alerts
- Stock movement trends (received vs issued)
- Optimal stock level recommendations
- Report generation & insights

## Response Formatting Rules (ALWAYS follow these)
1. **Use markdown** for ALL responses — headers, bold, tables, bullet points, and numbered lists.
2. **Start** with a brief 1-line summary in **bold**.
3. **Use tables** (with | header | format |) when comparing items, showing quantities, or listing data with 3+ rows.
4. **Use color-coded emoji indicators**:
   - 🟢 = Good / In Stock / Healthy
   - 🟡 = Warning / Low Stock / Attention Needed
   - 🔴 = Critical / Out of Stock / Expired / Urgent
   - 📦 = Received / Incoming
   - 📤 = Issued / Outgoing
   - ⚠️ = Damaged / Alert
5. **Use sections** with ### headers for different topics in longer responses.
6. **End with actionable recommendations** using a "### 💡 Recommendations" section when relevant.
7. **Reference specific item names and quantities** from the data — never be vague.
8. Keep responses **concise** but **visually rich**. Prefer structure over paragraphs.`;

    const response = await fetch(
      "https://ai.gateway.lovable.dev/v1/chat/completions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${LOVABLE_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "google/gemini-3-flash-preview",
          messages: [
            { role: "system", content: systemPrompt },
            ...messages,
          ],
          stream: true,
        }),
      }
    );

    if (!response.ok) {
      if (response.status === 429) {
        return new Response(
          JSON.stringify({ error: "Rate limit exceeded. Please try again in a moment." }),
          { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      if (response.status === 402) {
        return new Response(
          JSON.stringify({ error: "AI credits exhausted. Please add funds in Settings > Workspace > Usage." }),
          { status: 402, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      const t = await response.text();
      console.error("AI gateway error:", response.status, t);
      return new Response(
        JSON.stringify({ error: "AI service error" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(response.body, {
      headers: { ...corsHeaders, "Content-Type": "text/event-stream" },
    });
  } catch (e) {
    console.error("chat error:", e);
    return new Response(
      JSON.stringify({ error: e instanceof Error ? e.message : "Unknown error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
