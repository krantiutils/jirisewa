import type { Locale } from "@/lib/i18n";

const content = {
  en: {
    title: "JiriSewa",
    subtitle: "Farm to Consumer Marketplace",
    description:
      "Connecting Nepali farmers directly with consumers through community riders.",
  },
  ne: {
    title: "जिरीसेवा",
    subtitle: "किसानदेखि उपभोक्तासम्म",
    description:
      "सामुदायिक सवारी चालकहरूमार्फत नेपाली किसानलाई सिधै उपभोक्तासँग जोड्दै।",
  },
} as const;

export default async function HomePage({
  params,
}: {
  params: Promise<{ lang: string }>;
}) {
  const { lang } = await params;
  const t = content[lang as Locale] ?? content.ne;

  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-8">
      <h1 className="text-4xl font-bold text-green-700">{t.title}</h1>
      <p className="mt-2 text-xl text-gray-600">{t.subtitle}</p>
      <p className="mt-4 max-w-md text-center text-gray-500">
        {t.description}
      </p>
    </main>
  );
}
