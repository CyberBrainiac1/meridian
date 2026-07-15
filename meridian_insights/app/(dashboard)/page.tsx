import { verifySession } from "@/lib/dal";
import { createClient } from "@/lib/supabase/server";
import { getFloorView } from "@/lib/queries/floor";
import { FloorGrid } from "./floor-grid";

export const metadata = { title: "Floor status — Meridian Insights" };

export default async function FloorStatusPage() {
  const session = await verifySession();
  const supabase = await createClient();
  const initialRows = await getFloorView(supabase, session.facilityId);

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-semibold">Live floor status</h1>
        <p className="text-sm text-[var(--color-foreground)]/70 mt-1">
          One card per resident, updating live as incidents are detected and resolved.
        </p>
      </div>
      <FloorGrid facilityId={session.facilityId} initialRows={initialRows} />
    </div>
  );
}
