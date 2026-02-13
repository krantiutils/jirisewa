import { redirect } from "@/i18n/navigation";
import { use } from "react";

/**
 * /[locale]/produce redirects to /[locale]/marketplace.
 * Product detail lives at /[locale]/produce/[id].
 */
export default function ProducePage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = use(params);
  redirect({ href: "/marketplace", locale });
}
