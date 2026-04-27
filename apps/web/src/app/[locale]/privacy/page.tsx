import { setRequestLocale } from "next-intl/server";
import { use } from "react";
import { Link } from "@/i18n/navigation";

export default function PrivacyPolicyPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = use(params);
  setRequestLocale(locale);

  return (
    <main className="mx-auto max-w-3xl px-4 py-12 sm:px-6 lg:px-8">
      <h1 className="text-3xl font-extrabold tracking-tight text-foreground sm:text-4xl">
        Privacy Policy
      </h1>
      <p className="mt-2 text-sm text-gray-500">
        Last updated: March 2026
      </p>

      <div className="mt-10 space-y-10 text-gray-700 leading-relaxed">
        {/* ─── INTRODUCTION ─── */}
        <section>
          <p>
            JiriSewa (operating as{" "}
            <a
              href="https://khetbata.xyz"
              className="text-primary underline hover:text-primary/80"
            >
              khetbata.xyz
            </a>
            ) is a farm-to-consumer marketplace based in Kathmandu, Nepal. We
            connect farmers, delivery riders, and consumers to bring fresh
            produce directly from farms to your door. This Privacy Policy
            explains how we collect, use, store, and protect your personal
            information when you use our platform.
          </p>
          <p className="mt-3">
            By using JiriSewa, you agree to the collection and use of
            information as described in this policy.
          </p>
        </section>

        {/* ─── INFORMATION WE COLLECT ─── */}
        <section>
          <h2 className="text-xl font-bold text-foreground">
            1. Information We Collect
          </h2>
          <p className="mt-3">
            We collect information that you provide directly and information
            generated through your use of our services:
          </p>

          <h3 className="mt-4 font-semibold text-foreground">
            Account Information
          </h3>
          <ul className="mt-2 list-disc space-y-1 pl-6">
            <li>Full name</li>
            <li>Phone number (used for OTP authentication)</li>
            <li>Email address (if you sign up via email or Google OAuth)</li>
            <li>Profile photo (optional)</li>
            <li>User role (consumer, farmer, or rider)</li>
          </ul>

          <h3 className="mt-4 font-semibold text-foreground">
            Location Data
          </h3>
          <ul className="mt-2 list-disc space-y-1 pl-6">
            <li>Delivery addresses provided by consumers</li>
            <li>Farm or pickup locations provided by farmers</li>
            <li>Route and trip data for riders during active deliveries</li>
          </ul>

          <h3 className="mt-4 font-semibold text-foreground">
            Transaction Data
          </h3>
          <ul className="mt-2 list-disc space-y-1 pl-6">
            <li>Order history and order details</li>
            <li>Payment method selected (cash on delivery, eSewa, Khalti, or ConnectIPS)</li>
            <li>Delivery fee calculations</li>
          </ul>

          <h3 className="mt-4 font-semibold text-foreground">
            Content You Provide
          </h3>
          <ul className="mt-2 list-disc space-y-1 pl-6">
            <li>Produce listing descriptions and photos uploaded by farmers</li>
            <li>Messages exchanged between users on the platform</li>
            <li>Reviews and ratings</li>
          </ul>

          <h3 className="mt-4 font-semibold text-foreground">
            Automatically Collected Data
          </h3>
          <ul className="mt-2 list-disc space-y-1 pl-6">
            <li>Device type and browser information</li>
            <li>IP address</li>
            <li>Usage patterns and page views</li>
          </ul>
        </section>

        {/* ─── HOW WE USE YOUR INFORMATION ─── */}
        <section>
          <h2 className="text-xl font-bold text-foreground">
            2. How We Use Your Information
          </h2>
          <ul className="mt-3 list-disc space-y-1 pl-6">
            <li>
              <strong>Providing our services:</strong> Processing orders,
              coordinating deliveries, and enabling communication between
              farmers, riders, and consumers.
            </li>
            <li>
              <strong>Authentication:</strong> Verifying your identity via
              phone OTP, email, or Google OAuth.
            </li>
            <li>
              <strong>Delivery coordination:</strong> Using location data to
              calculate delivery routes, fees, and estimated arrival times.
            </li>
            <li>
              <strong>Payments:</strong> Facilitating payments through your
              chosen payment method (eSewa, Khalti, ConnectIPS, or cash on
              delivery).
            </li>
            <li>
              <strong>Notifications:</strong> Sending order updates, delivery
              status, and relevant announcements.
            </li>
            <li>
              <strong>Platform improvement:</strong> Analyzing usage to improve
              our services, fix issues, and develop new features.
            </li>
            <li>
              <strong>Safety and fraud prevention:</strong> Detecting and
              preventing fraudulent or unauthorized activity.
            </li>
          </ul>
        </section>

        {/* ─── DATA STORAGE ─── */}
        <section>
          <h2 className="text-xl font-bold text-foreground">
            3. Data Storage and Security
          </h2>
          <p className="mt-3">
            Your data is stored securely using Supabase, a hosted PostgreSQL
            database service with built-in row-level security. File uploads
            (such as produce photos) are stored in Supabase Storage with
            access controls.
          </p>
          <p className="mt-3">
            We implement appropriate technical and organizational measures to
            protect your personal information against unauthorized access,
            alteration, disclosure, or destruction. These include:
          </p>
          <ul className="mt-2 list-disc space-y-1 pl-6">
            <li>Encrypted data transmission (HTTPS/TLS)</li>
            <li>Row-level security policies on all database tables</li>
            <li>Secure authentication via Supabase Auth</li>
            <li>Regular security reviews</li>
          </ul>
          <p className="mt-3">
            While we take reasonable steps to protect your data, no method of
            transmission or storage is completely secure. We cannot guarantee
            absolute security.
          </p>
        </section>

        {/* ─── THIRD-PARTY SERVICES ─── */}
        <section>
          <h2 className="text-xl font-bold text-foreground">
            4. Third-Party Services
          </h2>
          <p className="mt-3">
            We use the following third-party services to operate our platform:
          </p>
          <ul className="mt-2 list-disc space-y-1 pl-6">
            <li>
              <strong>Supabase:</strong> Database hosting, authentication, file
              storage, and real-time services.
            </li>
            <li>
              <strong>Google OAuth:</strong> Optional sign-in method.
            </li>
            <li>
              <strong>OpenStreetMap / Leaflet:</strong> Map display and
              geocoding for delivery addresses and routes.
            </li>
            <li>
              <strong>eSewa, Khalti, ConnectIPS:</strong> Payment processing
              (we do not store your full payment credentials; these are handled
              by the respective payment providers).
            </li>
          </ul>
          <p className="mt-3">
            Each third-party service operates under its own privacy policy. We
            encourage you to review their policies for information about how
            they handle your data.
          </p>
        </section>

        {/* ─── YOUR RIGHTS ─── */}
        <section>
          <h2 className="text-xl font-bold text-foreground">
            5. Your Rights
          </h2>
          <p className="mt-3">You have the right to:</p>
          <ul className="mt-2 list-disc space-y-1 pl-6">
            <li>
              <strong>Access your data:</strong> Request a copy of the personal
              information we hold about you.
            </li>
            <li>
              <strong>Correct your data:</strong> Update or correct inaccurate
              personal information through your account settings.
            </li>
            <li>
              <strong>Delete your data:</strong> Request deletion of your
              account and associated personal data. Note that some data may be
              retained as required by law or for legitimate business purposes
              (e.g., completed order records).
            </li>
            <li>
              <strong>Withdraw consent:</strong> You may stop using our
              services at any time. For specific data processing activities, you
              can withdraw consent by contacting us.
            </li>
          </ul>
          <p className="mt-3">
            To exercise any of these rights, please contact us at the email
            address below.
          </p>
        </section>

        {/* ─── CONTACT ─── */}
        <section>
          <h2 className="text-xl font-bold text-foreground">
            6. Contact Us
          </h2>
          <p className="mt-3">
            If you have any questions or concerns about this Privacy Policy or
            our data practices, please contact us:
          </p>
          <ul className="mt-2 space-y-1 pl-6">
            <li>
              <strong>Email:</strong>{" "}
              <a
                href="mailto:info@jirisewa.com"
                className="text-primary underline hover:text-primary/80"
              >
                info@jirisewa.com
              </a>
            </li>
            <li>
              <strong>Location:</strong> Kathmandu, Nepal
            </li>
          </ul>
        </section>

        {/* ─── UPDATES ─── */}
        <section>
          <h2 className="text-xl font-bold text-foreground">
            7. Updates to This Policy
          </h2>
          <p className="mt-3">
            We may update this Privacy Policy from time to time to reflect
            changes in our practices, technology, or legal requirements. When we
            make changes, we will update the &ldquo;Last updated&rdquo; date at
            the top of this page.
          </p>
          <p className="mt-3">
            We encourage you to review this policy periodically. Continued use
            of JiriSewa after any changes constitutes your acceptance of the
            updated policy.
          </p>
        </section>
      </div>

      {/* ─── BACK LINK ─── */}
      <div className="mt-12 border-t border-gray-200 pt-8">
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
