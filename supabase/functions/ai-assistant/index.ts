// ============================================================================
// Almuin · ai-assistant (Supabase Edge Function, Deno)
// ----------------------------------------------------------------------------
// HARD SAFETY CONTRACT
//   * Input: the user's described situation + candidate items already selected
//     from the *verified* corpus (id, reference, grade, tags).
//   * The model may do EXACTLY ONE thing: return a ranked subset of those ids.
//     It returns no prose at all. There is no free-text field in the response
//     schema, so there is nothing for a sanitizer to miss.
//   * The candidates' Arabic text is never sent: the model ranks on reference,
//     grade and tags. Less payload, less exposure, and it cannot echo text it
//     never received.
//   * Any id outside the candidate set voids the whole response and the
//     deterministic ranking is used instead.
//   * Without an LLM key, deterministic ranking runs instead.
//
// PRIVACY
//   `user_situation` is the most sensitive thing this app handles — illness,
//   debt, grief. It is forwarded to the model and then dropped. It is NEVER
//   logged, and NEVER written to any table. Keep it that way.
//
// COST
//   Every call is metered per authenticated user via bump_ai_usage(). The
//   anon key ships inside the APK, so without this an extracted key is an
//   uncapped bill.
// ============================================================================

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

interface Candidate {
  id: string;
  reference: string;
  grade: string;
  tags: string[];
}

interface Req {
  user_text: string;
  locale?: string;
  candidates: Candidate[];
}

const DAILY_CALL_LIMIT = Number(Deno.env.get("AI_DAILY_LIMIT") ?? "20");

const SYSTEM_PROMPT = `You are a retrieval ranker for an Islamic app.

You receive a person's described situation and a list of ALREADY-VERIFIED
supplications, each with an id, a source reference, an authenticity grade and
topical tags. You do not see their text and you do not need it.

Your ONLY task: return the ids that best fit the situation, most relevant
first.

Output JSON only, exactly: {"selected_ids": ["...", "..."]}

Rules:
1. Every id you return MUST appear in the candidate list. Never invent one.
2. Never write Arabic. Never write religious text of any kind. Never explain.
   The response contains ids and nothing else.
3. Prefer quran and sahih grades when relevance is comparable.
4. Return at most 5 ids. If nothing genuinely fits, return an empty list —
   an empty list is a correct and useful answer.`;

serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  // verify_jwt=true means the gateway already checked the signature; we only
  // need the subject to meter usage.
  const userId = subjectOf(req.headers.get("Authorization"));
  if (!userId) return json({ error: "forbidden" }, 403);

  let body: Req;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const userText = (body.user_text ?? "").slice(0, 600);
  const candidates = (body.candidates ?? [])
    .slice(0, 30)
    .map((c) => ({
      id: String(c.id ?? "").slice(0, 80),
      reference: String(c.reference ?? "").slice(0, 200),
      grade: String(c.grade ?? "").slice(0, 20),
      tags: (Array.isArray(c.tags) ? c.tags : [])
        .slice(0, 8)
        .map((t) => String(t).slice(0, 40)),
    }));

  if (candidates.length === 0) return json({ selected_ids: [] });

  const candidateIds = new Set(candidates.map((c) => c.id));
  const apiKey = Deno.env.get("OPENAI_API_KEY");

  if (!apiKey) {
    return json({ selected_ids: localRank(userText, candidates), mode: "local" });
  }

  // Metered before the paid call, not after.
  const allowed = await bumpUsage(userId);
  if (!allowed) {
    return json({
      selected_ids: localRank(userText, candidates),
      mode: "quota",
    });
  }

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
              candidates,
            }),
          },
        ],
      }),
    });

    if (!res.ok) throw new Error(`LLM ${res.status}`);
    const data = await res.json();
    const parsed = JSON.parse(
      data.choices?.[0]?.message?.content ?? "{}",
    ) as { selected_ids?: unknown };

    const rawIds = Array.isArray(parsed.selected_ids) ? parsed.selected_ids : [];

    // One id outside the set voids the entire response — a model that
    // invents an id has demonstrably ignored the contract, so nothing it
    // returned in that call is trustworthy.
    if (rawIds.some((x) => typeof x !== "string" || !candidateIds.has(x))) {
      return json({
        selected_ids: localRank(userText, candidates),
        mode: "fallback",
      });
    }

    return json({ selected_ids: rawIds.slice(0, 5) as string[], mode: "llm" });
  } catch (_e) {
    // Deliberately not logging the error object: it can contain the request
    // body, and the request body is the user's situation.
    return json({
      selected_ids: localRank(userText, candidates),
      mode: "fallback",
    });
  }
});

/// Reads `sub` from an already-gateway-verified JWT. No signature check here
/// on purpose — verify_jwt=true has done it before we run.
function subjectOf(authHeader: string | null): string | null {
  if (!authHeader?.startsWith("Bearer ")) return null;
  const parts = authHeader.slice(7).split(".");
  if (parts.length !== 3) return null;
  try {
    const pad = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const payload = JSON.parse(atob(pad + "=".repeat((4 - pad.length % 4) % 4)));
    const sub = payload?.sub;
    return typeof sub === "string" && sub.length > 0 ? sub : null;
  } catch {
    return null;
  }
}

/// Atomically increments today's counter, returning false once the cap is hit.
/// The atomicity lives in the SQL function: doing read-then-write here would
/// let concurrent requests slip past the limit.
async function bumpUsage(userId: string): Promise<boolean> {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  // Fail OPEN if metering is misconfigured: a broken counter should not deny
  // someone a supplication. The cap protects the bill, not correctness.
  if (!url || !key) return true;
  try {
    const res = await fetch(`${url}/rest/v1/rpc/bump_ai_usage`, {
      method: "POST",
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ p_user: userId, p_limit: DAILY_CALL_LIMIT }),
    });
    if (!res.ok) return true;
    return (await res.json()) !== false;
  } catch {
    return true;
  }
}

/// Deterministic mirror of the on-device ranker. Tag overlap plus grade —
/// no Arabic text is available here by design.
function localRank(text: string, candidates: Candidate[]): string[] {
  const words = text.toLowerCase().split(/\s+/).filter((w) => w.length > 3);
  const gradeWeight: Record<string, number> = {
    quran: 3, sahih: 2, hasan: 1, daif: -99, custom: -1,
  };
  return candidates
    .map((c) => ({
      id: c.id,
      score: (gradeWeight[c.grade] ?? 0) +
        c.tags.filter((t) => words.some((w) => t.toLowerCase().includes(w)))
          .length,
    }))
    .sort((a, b) => b.score - a.score)
    .slice(0, 5)
    .map((x) => x.id);
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
