import { setRequestLocale } from "next-intl/server";
import { HubForm } from "../_components/HubForm";
import {
  createHub,
  listHubOperators,
  listMunicipalitiesForHub,
} from "@/lib/admin/hubs";

export const dynamic = "force-dynamic";

export default async function NewHubPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  const [operators, municipalities] = await Promise.all([
    listHubOperators(),
    listMunicipalitiesForHub(),
  ]);

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold">New Hub</h1>
      <HubForm
        locale={locale}
        operators={operators}
        municipalities={municipalities}
        action={createHub}
      />
    </div>
  );
}
