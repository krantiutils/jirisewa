import { setRequestLocale } from "next-intl/server";
import { notFound } from "next/navigation";
import { HubForm } from "../_components/HubForm";
import {
  createHub,
  disableHub,
  getHub,
  listHubOperators,
  listMunicipalitiesForHub,
  updateHub,
} from "@/lib/admin/hubs";

export const dynamic = "force-dynamic";

export default async function EditHubPage({
  params,
}: {
  params: Promise<{ locale: string; id: string }>;
}) {
  const { locale, id } = await params;
  setRequestLocale(locale);

  const [hub, operators, municipalities] = await Promise.all([
    getHub(locale, id),
    listHubOperators(),
    listMunicipalitiesForHub(),
  ]);

  if (!hub) notFound();

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold">Edit hub: {hub.name_en}</h1>
      <HubForm
        locale={locale}
        initial={hub}
        operators={operators}
        municipalities={municipalities}
        action={createHub}
        updateAction={updateHub}
        disableAction={disableHub}
      />
    </div>
  );
}
