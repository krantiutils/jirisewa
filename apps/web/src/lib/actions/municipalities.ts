"use server";

import { createServiceRoleClient } from "@/lib/supabase/server";
import type { MunicipalitySearchResult } from "@/lib/supabase/types";
import type { ActionResult } from "@/lib/types/action";

/**
 * Server action for searching municipalities via autocomplete.
 * Used by the MunicipalityPicker client component.
 */
export async function searchMunicipalitiesAction(
  query: string,
  province?: number,
): Promise<ActionResult<MunicipalitySearchResult[]>> {
  try {
    const supabase = createServiceRoleClient();

    const params: Record<string, unknown> = {
      p_query: query || null,
      p_limit: 15,
    };
    if (province != null) {
      params.p_province = province;
    }

    const { data, error } = await supabase
      .rpc("search_municipalities" as never, params as never) as {
        data: MunicipalitySearchResult[] | null;
        error: { message: string } | null;
      };

    if (error) {
      console.error("searchMunicipalitiesAction error:", error);
      return { error: error.message };
    }

    return { data: data ?? [] };
  } catch (err) {
    console.error("searchMunicipalitiesAction unexpected error:", err);
    return { error: "Failed to search municipalities" };
  }
}
