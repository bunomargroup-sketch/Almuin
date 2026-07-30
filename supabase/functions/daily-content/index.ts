// ============================================================================
// Almuin · daily-content (Supabase Edge Function, Deno)
// ----------------------------------------------------------------------------
// Rotates the featured verse/hadith/dhikr of the day into `daily_content`
// so every device optionally sees the same pick. The app works without it
// (deterministic local rotation), this only keeps fleet-wide consistency.
//
// AUTH (review S3): runs with the service-role key — so the caller must be
// the cron job, not the public. Accepted callers:
//   * Authorization: Bearer <service-role JWT>  (role claim == service_role)
//   * Authorization: Bearer <CRON_SECRET>       (if that env var is set)
// Everything else gets 401 before any table is touched.
//
// Schedule daily via Supabase Cron (e.g. every day at 00:15 UTC):
//   select cron.schedule('almuin-daily-content', '15 0 * * *',
//     $$select net.http_post(url:='<fn-url>', headers:='{"Authorization":
//     "Bearer <service-role-key>"}'::jsonb)$$);
// ============================================================================

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

function callerAllowed(req: Request): boolean {
  const auth = req.headers.get("Authorization") ?? "";
  const cronSecret = Deno.env.get("CRON_SECRET");
  if (cronSecret && auth === `Bearer ${cronSecret}`) return true;
  const m = auth.match(/^Bearer\s+(.+)$/);
  if (!m) return false;
  try {
    // verify_jwt=true already validated the signature at the gateway —
    // here we only need the role claim from the payload.
    const payload = JSON.parse(
      atob(m[1].split(".")[1].replace(/-/g, "+").replace(/_/g, "/")),
    );
    return payload.role === "service_role";
  } catch {
    return false;
  }
}

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ error: "POST only" }, 405);
  }
  if (!callerAllowed(req)) {
    return json({ error: "unauthorized" }, 401);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const today = new Date().toISOString().slice(0, 10);

  async function pick<T extends { id: string }>(
    table: string,
  ): Promise<string | null> {
    // Review M10: ORDER BY is mandatory — without it Postgres row order is
    // unspecified, and two runs on the same day could pick different rows.
    const { data, error } = await supabase.from(table).select("id").order("id");
    if (error || !data?.length) return null;
    // Deterministic pick by day-of-epoch so re-runs are idempotent.
    const dayIdx = Math.floor(Date.now() / 86_400_000);
    return (data as T[])[dayIdx % data.length].id;
  }

  const row = {
    day: today,
    verse_id: await pick("verses"),
    hadith_id: await pick("hadiths"),
    dhikr_id: await pick("adhkar"),
  };

  const { error } = await supabase
    .from("daily_content")
    .upsert(row, { onConflict: "day" });

  return json({ ok: !error, row, error: error?.message ?? null }, error ? 500 : 200);
});

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
