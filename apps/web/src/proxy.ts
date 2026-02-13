import createIntlMiddleware from "next-intl/middleware";
import { type NextRequest } from "next/server";
import { routing } from "./i18n/routing";
import { updateSession } from "./lib/supabase/middleware";

const intlMiddleware = createIntlMiddleware(routing);

export default async function middleware(request: NextRequest) {
  // 1. Refresh the Supabase session (sets cookies on response)
  const supabaseResponse = await updateSession(request);

  // 2. Run the intl middleware for locale handling
  const intlResponse = intlMiddleware(request);

  // 3. Merge Supabase cookies into the intl response (preserve all attributes)
  supabaseResponse.cookies.getAll().forEach((cookie) => {
    intlResponse.cookies.set(cookie);
  });

  return intlResponse;
}

export const config = {
  matcher: ["/((?!api|_next|_vercel|.*\\..*).*)"],
};
