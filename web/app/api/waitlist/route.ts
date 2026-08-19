import { NextResponse } from "next/server";

/// Waitlist capture. For MVP this just validates + logs; wire to Supabase/Resend later.
export async function POST(req: Request) {
  const { email, lang } = await req.json().catch(() => ({}));
  if (!email || typeof email !== "string" || !email.includes("@")) {
    return NextResponse.json({ error: "invalid email" }, { status: 400 });
  }
  // TODO: persist to Supabase `waitlist` table and/or send a confirmation via Resend.
  console.log("waitlist signup:", email, lang);
  return NextResponse.json({ ok: true });
}
