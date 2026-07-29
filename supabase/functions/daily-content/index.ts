// ============================================================================
// Almuin · daily-content (Supabase Edge Function, Deno)
// ----------------------------------------------------------------------------
// Rotates the featured verse/hadith/dhikr of the day into `daily_content`
// so every device optionally sees the same pick. The app works without it
// (deterministic local rotation), this only keeps fleet-wide consistency.
//
// Schedule daily via Supabase Cron (e.g. every day at 00:15 UTC):
//   select cron.schedule('almuin-daily-content', '15 0 * * *',
//     $$select net.http_post(url:='<fn-url>', headers:='{"Authorization":
//     "Bearer <service-role-key>"}'::jsonb)$$);
// ============================================================================

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

serve(async (_req: Request) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const today = new Date().toISOString().slice(0, 10);

  async function pick<T extends { id: string }>(
    table: string,
  ): Promise<string | null> {
    const { data, error } = await supabase.from(table).select("id");
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

  return new Response(JSON.stringify({ ok: !error, row, error }), {
    headers: { "Content-Type": "application/json" },
    status: error ? 500 : 200,
  });
});
