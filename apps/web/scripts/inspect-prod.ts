import fs from "node:fs";
import path from "node:path";
import { createClient } from "@supabase/supabase-js";

for (const file of [".env.local.prod", ".env.local"]) {
  const p = path.resolve(__dirname, "..", file);
  if (!fs.existsSync(p)) continue;
  for (const line of fs.readFileSync(p, "utf8").split("\n")) {
    const m = line.match(/^([A-Z_][A-Z0-9_]*)=(.*)$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2];
  }
}

const supa = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
  { auth: { persistSession: false } },
);

(async () => {
  const { data: admins } = await supa
    .from("users")
    .select("id,name,phone,role,is_admin")
    .eq("is_admin", true);
  console.log("admins on prod:", admins);
  const { data: usersAll } = await supa
    .from("users")
    .select("id,name,phone,role,is_admin");
  console.log("ALL users.users rows:", usersAll);

  const { data: list, error } = await supa.auth.admin.listUsers();
  if (error) {
    console.log("listUsers err:", error.message);
    return;
  }
  const hub = list.users.find(
    (u) => u.email === "jiri-hub-operator@jirisewa.local",
  );
  console.log("hub operator exists in auth.users:", hub ? hub.id : "NO");
  console.log("total auth.users:", list.users.length);
  console.log(
    "auth.users emails sample:",
    list.users.slice(0, 8).map((u) => u.email),
  );

  const { data: hubs } = await supa.from("pickup_hubs").select("*");
  console.log("pickup_hubs:", hubs);
})();
