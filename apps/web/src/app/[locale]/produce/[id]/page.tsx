import { setRequestLocale } from "next-intl/server";
import { getTranslations } from "next-intl/server";
import { notFound } from "next/navigation";
import { use } from "react";
import { fetchProduceById } from "@/lib/queries/produce";
import { ProduceDetail } from "@/components/marketplace/ProduceDetail";
import type { Metadata } from "next";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string; id: string }>;
}): Promise<Metadata> {
  const { locale, id } = await params;
  const t = await getTranslations({ locale, namespace: "produce" });
  const listing = await fetchProduceById(id);

  if (!listing) {
    return { title: t("notFound") };
  }

  const name = locale === "ne" ? listing.name_ne : listing.name_en;
  const farmerName = listing.farmer.name;
  const description = listing.description ?? t("shareTitle", { name, farmer: farmerName });
  const photo = listing.photos?.[0];
  const baseUrl = process.env.NEXT_PUBLIC_BASE_URL ?? "https://jirisewa.com";

  return {
    title: `${name} — NPR ${listing.price_per_kg}/kg`,
    description,
    openGraph: {
      title: t("shareTitle", { name, farmer: farmerName }),
      description,
      type: "website",
      url: `${baseUrl}/${locale}/produce/${id}`,
      ...(photo ? { images: [{ url: photo, width: 800, height: 600, alt: name }] } : {}),
    },
    twitter: {
      card: photo ? "summary_large_image" : "summary",
      title: t("shareTitle", { name, farmer: farmerName }),
      description,
      ...(photo ? { images: [photo] } : {}),
    },
  };
}

export default function ProduceDetailPage({
  params,
}: {
  params: Promise<{ locale: string; id: string }>;
}) {
  const { locale, id } = use(params);
  setRequestLocale(locale);

  return <ProduceDetailLoader id={id} />;
}

async function ProduceDetailLoader({ id }: { id: string }) {
  const listing = await fetchProduceById(id);

  if (!listing) {
    notFound();
  }

  return <ProduceDetail listing={listing} />;
}
