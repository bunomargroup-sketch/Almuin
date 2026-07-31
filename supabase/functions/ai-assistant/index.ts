// ============================================================================
// Almuin · ai-assistant (Supabase Edge Function, Deno)
// ----------------------------------------------------------------------------
// HARD SAFETY CONTRACT
//   * Input: a user message + candidate items fetched from the *verified*
//     local/DB content (id, arabic, reference, grade).
//   * The model may ONLY: (a) pick a subset of those ids, and (b) write one
//     short empathetic line (NOT Islamic content) in Arabic.
//   * It may NEVER produce a verse, hadith, or dhikr text. Output is
//     schema-validated twice: JSON shape + subset-of-candidates check.
//   * Without an LLM key, deterministic keyword ranking runs instead.
// ============================================================================

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

interface Candidate {
  id: string;
  arabic: string;
  reference: string;
  grade: string;
}

interface Req {
  user_text: string;
  locale?: string;
  candidates: Candidate[];
}

const SYSTEM_PROMPT = `You are "Almuin", a careful Islamic companion.
STRICT RULES — violating any of them is a critical failure:
1. You receive a numbered list of AUTHENTIC candidates (Quran/hadith/adhkar)
   with references. You may ONLY select among them by their "id".
2. NEVER write, quote, paraphrase, or invent any Quran, hadith, or dhikr text.
   The only Arabic religious text the user will see comes from the candidates.
3. Output JSON ONLY, exactly: {"selected_ids":[...], "empathy":"<one short
   caring Arabic sentence about the user's feeling, no religious text>"}.
4. Rank by relevance to the user's described situation. Prefer quran/sahih
   grades. Never output ids that are not in the candidate list.
5. If nothing fits, return an empty selected_ids list.`;

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ error: "POST only" }, 405);
  }

  let body: Req;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const userText = (body.user_text ?? "").slice(0, 600);
  // Review S2: the requester must never grow the prompt (and our OpenAI
  // bill) without bound — cap item count and serialized field sizes.
  const candidates = (body.candidates ?? [])
    .slice(0, 30)
    .map((c) => ({
      id: String(c.id ?? "").slice(0, 80),
      arabic: String(c.arabic ?? "").slice(0, 600),
      reference: String(c.reference ?? "").slice(0, 200),
      grade: String(c.grade ?? "").slice(0, 20),
    }));

  if (candidates.length === 0) {
    return json({ selected_ids: [], empathy: "" });
  }

  const candidateIds = new Set(candidates.map((c) => c.id));
  const apiKey = Deno.env.get("OPENAI_API_KEY");

  // ---- No LLM key configured: deterministic keyword re-ranking ----------
  if (!apiKey) {
    return json({
      selected_ids: localRank(userText, candidates),
      empathy: "",
      mode: "local",
    });
  }

  // ---- LLM re-rank with hard subset validation ---------------------------
  try {
    const res = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-mini",
        temperature: 0.2,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          {
            role: "user",
            content: JSON.stringify({
              user_situation: userText,
              candidates: candidates.map((c) => ({
                id: c.id,
                reference: c.reference,
                grade: c.grade,
              })),
            }),
          },
        ],
      }),
    });

    if (!res.ok) throw new Error(`LLM ${res.status}`);
    const data = await res.json();
    const parsed = JSON.parse(
      data.choices?.[0]?.message?.content ?? "{}",
    ) as { selected_ids?: unknown; empathy?: unknown };

    const selected = Array.isArray(parsed.selected_ids)
      ? parsed.selected_ids.filter(
          (x): x is string => typeof x === "string" && candidateIds.has(x),
        )
      : [];

    // If the model returned anything outside the subset, discard ALL of it.
    const rawIds = Array.isArray(parsed.selected_ids)
      ? parsed.selected_ids
      : [];
    if (rawIds.some((x) => !candidateIds.has(x as string))) {
      return json({ selected_ids: localRank(userText, candidates), empathy: "", mode: "fallback" });
    }

    const empathy = sanitizeEmpathy(parsed.empathy);

    return json({ selected_ids: selected, empathy, mode: "llm" });
  } catch (_e) {
    return json({
      selected_ids: localRank(userText, candidates),
      empathy: "",
      mode: "fallback",
    });
  }
});

// Review S4: the app renders this line directly above a "verified sources"
// footer — anything that looks like Quran/hadith text is dropped, the rest
// is trimmed to one short sentence. The deterministic template intro stays
// the default; this line only adds warmth.
function sanitizeEmpathy(raw: unknown): string {
  if (typeof raw !== "string") return "";
  const s = raw.trim().replace(/\s+/g, " ");
  if (!s) return "";
  const markers = [
    "ﷺ", "﴿", "﴾", "قال رسول", "قال النبي", "رواه", "عن أبي", "عن عبد",
    "حديث", "آية", "ﷲ",
    // Quran attribution. Without these, "قال الله تعالى ..." passed straight
    // through and was rendered under the verified-sources footer.
    "قال الله", "قال تعالى", "قال عز", "يقول الله", "يقول تعالى",
    "في القرآن", "سورة", "الآية", "صدق الله",
  ];
  if (markers.some((m) => s.includes(m))) return "";
  return s.slice(0, 120);
}

// Simple keyword mirror of the on-device ranker (kept dependency-free).
function localRank(text: string, candidates: Candidate[]): string[] {
  const t = text.toLowerCase();
  const gradeWeight: Record<string, number> = {
    quran: 3, sahih: 2, hasan: 1, daif: -99, custom: -1,
  };
  return candidates
    .map((c) => ({
      id: c.id,
      score: (gradeWeight[c.grade] ?? 0) +
        (t.split(/\s+/).some((w) => w.length > 3 && c.arabic.includes(w)) ? 1 : 0),
    }))
    .sort((a, b) => b.score - a.score)
    .slice(0, 5)
    .map((x) => x.id);
}

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
