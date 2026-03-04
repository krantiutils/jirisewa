import { setRequestLocale } from "next-intl/server";
import { use } from "react";
import { Link } from "@/i18n/navigation";

export default function DeleteAccountPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = use(params);
  setRequestLocale(locale);

  return (
    <main className="mx-auto max-w-3xl px-4 py-12 sm:px-6 lg:px-8">
      <h1 className="text-3xl font-extrabold tracking-tight text-foreground sm:text-4xl">
        Delete Your Account
      </h1>
      <p className="mt-2 text-sm text-gray-500">
        Last updated: March 2026
      </p>

      <div className="mt-10 space-y-8 text-gray-700 leading-relaxed">
        <section>
          <p>
            We respect your right to control your personal data. If you wish to
            delete your JiriSewa account and all associated data, you can do so
            using one of the methods below.
          </p>
        </section>

        <section>
          <h2 className="text-xl font-bold text-foreground">
            How to Delete Your Account
          </h2>

          <h3 className="mt-4 font-semibold text-foreground">
            Option 1: In-App Deletion
          </h3>
          <ol className="mt-2 list-decimal space-y-1 pl-6">
            <li>Open JiriSewa and sign in to your account.</li>
            <li>
              Go to <strong>Settings</strong> (tap your profile icon in the top
              right).
            </li>
            <li>
              Scroll down and tap <strong>Delete Account</strong>.
            </li>
            <li>Confirm the deletion when prompted.</li>
          </ol>

          <h3 className="mt-6 font-semibold text-foreground">
            Option 2: Email Request
          </h3>
          <p className="mt-2">
            Send an email to{" "}
            <a
              href="mailto:info@jirisewa.com?subject=Account%20Deletion%20Request"
              className="text-primary underline hover:text-primary/80"
            >
              info@jirisewa.com
            </a>{" "}
            with the subject line &ldquo;Account Deletion Request&rdquo; and
            include the phone number or email address associated with your
            account. We will process your request within 7 business days.
          </p>
        </section>

        <section>
          <h2 className="text-xl font-bold text-foreground">
            What Gets Deleted
          </h2>
          <p className="mt-3">
            When you delete your account, the following data is permanently
            removed:
          </p>
          <ul className="mt-2 list-disc space-y-1 pl-6">
            <li>Your profile information (name, phone number, email, photo)</li>
            <li>Your saved delivery addresses</li>
            <li>Your produce listings (if you are a farmer)</li>
            <li>Your trip history (if you are a rider)</li>
            <li>Your cart and saved preferences</li>
            <li>Push notification subscriptions</li>
          </ul>
        </section>

        <section>
          <h2 className="text-xl font-bold text-foreground">
            What May Be Retained
          </h2>
          <p className="mt-3">
            Certain data may be retained for legal, regulatory, or legitimate
            business purposes:
          </p>
          <ul className="mt-2 list-disc space-y-1 pl-6">
            <li>
              Completed order records (anonymized, for accounting and tax
              compliance)
            </li>
            <li>
              Payment transaction records (as required by Nepali financial
              regulations)
            </li>
            <li>
              Data necessary to resolve disputes or enforce our terms of service
            </li>
          </ul>
          <p className="mt-3">
            Retained data is anonymized where possible and is not used for
            marketing or profiling purposes.
          </p>
        </section>

        <section>
          <h2 className="text-xl font-bold text-foreground">
            Questions?
          </h2>
          <p className="mt-3">
            If you have any questions about account deletion, please contact us
            at{" "}
            <a
              href="mailto:info@jirisewa.com"
              className="text-primary underline hover:text-primary/80"
            >
              info@jirisewa.com
            </a>
            .
          </p>
        </section>
      </div>

      <div className="mt-12 border-t border-gray-200 pt-8 flex gap-6">
        <Link
          href="/privacy"
          className="text-sm font-medium text-primary hover:text-primary/80 underline"
        >
          Privacy Policy
        </Link>
        <Link
          href="/"
          className="text-sm font-medium text-primary hover:text-primary/80 underline"
        >
          &larr; Back to home
        </Link>
      </div>
    </main>
  );
}
