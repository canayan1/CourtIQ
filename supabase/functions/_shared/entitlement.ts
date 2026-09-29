// The premium gate, in one place.
//
// It was copy-pasted into ai-chat, swing-analysis, match-analysis and
// doubles-analysis — four copies that had already drifted apart in whitespace
// and would eventually drift apart in behaviour. This is that block, once.
//
// ## Why this cannot simply be switched on
//
// The old comment said the gate "fails OPEN on any RevenueCat error so an
// outage never locks out paying users". That is true and it is not enough,
// because the case that actually locks out a paying user is not an error.
//
// `GET /v1/subscribers/{id}` CREATES the subscriber when RevenueCat has never
// seen that id, and answers **200 with no entitlements**. So these two are
// byte-identical to the server:
//
//   * a free rider on an anonymous account who never paid       → deny, correct
//   * a subscriber whose RevenueCat alias has not landed yet    → deny, wrong
//
// The alias is `Purchases.logIn(supabaseUserID)`, fired from the app as
// `Task { _ = try? await ... }` — fire and forget, errors swallowed. It runs on
// every session establishment and heals itself on the next launch with network,
// so the window is small. Small is not zero, and the people inside it are the
// ones who paid.
//
// `reason` below exists to size that window with evidence instead of nerve.
// `rcSilent` means RevenueCat holds no purchase history at all for this id:
// expected for a free user, alarming for anyone who bought something. Run in
// shadow first (ENTITLEMENT_SHADOW=true), read the log, and flip only once the
// denials look like free riders.

const REVENUECAT_SECRET_KEY = Deno.env.get("REVENUECAT_SECRET_KEY") ?? "";
const REQUIRE_ENTITLEMENT = (Deno.env.get("REQUIRE_ENTITLEMENT") ?? "false").toLowerCase() === "true";
/// Decide, log, and then allow anyway. The measurement that has to happen
/// before REQUIRE_ENTITLEMENT is worth flipping.
const ENTITLEMENT_SHADOW = (Deno.env.get("ENTITLEMENT_SHADOW") ?? "false").toLowerCase() === "true";

const ENTITLEMENT_TTL_MS = 10 * 60 * 1000;
const entitlementCache = new Map<string, { entitled: boolean; reason: Reason; at: number }>();

export type Reason =
  | "gate_off"      // neither enforcing nor shadowing — nothing was asked
  | "no_secret"     // misconfigured; allowed
  | "cached"
  | "rc_active"     // an unexpired entitlement
  | "rc_expired"    // RevenueCat knows this id and its entitlement has lapsed
  | "rc_silent"     // 200, but no entitlement AND no purchase history at all
  | "rc_error"      // non-2xx; allowed
  | "rc_unreachable"; // threw; allowed

export interface Decision {
  /// What the gate concluded.
  entitled: boolean;
  /// Whether that conclusion is allowed to block the request. False in shadow.
  enforced: boolean;
  reason: Reason;
}

/// True when the caller should be let through — which in shadow mode is always.
export function allows(d: Decision): boolean {
  return d.entitled || !d.enforced;
}

interface RCEntitlement { expires_date?: string | null }
interface RCSubscriber {
  entitlements?: Record<string, RCEntitlement>;
  subscriptions?: Record<string, unknown>;
  non_subscriptions?: Record<string, unknown>;
}

export async function checkEntitlement(userId: string): Promise<Decision> {
  const enforced = REQUIRE_ENTITLEMENT && !ENTITLEMENT_SHADOW;

  // Nobody is asking the question, so don't spend a RevenueCat call answering
  // it. Shadow mode is what makes the question get asked before it counts.
  if (!REQUIRE_ENTITLEMENT && !ENTITLEMENT_SHADOW) {
    return { entitled: true, enforced: false, reason: "gate_off" };
  }
  if (!REVENUECAT_SECRET_KEY) {
    return { entitled: true, enforced: false, reason: "no_secret" };
  }

  const hit = entitlementCache.get(userId);
  if (hit && Date.now() - hit.at < ENTITLEMENT_TTL_MS) {
    return { entitled: hit.entitled, enforced, reason: "cached" };
  }

  try {
    const res = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}`,
      { headers: { Authorization: `Bearer ${REVENUECAT_SECRET_KEY}` } },
    );
    // An outage must never bill a paying customer for our downtime.
    if (!res.ok) return { entitled: true, enforced: false, reason: "rc_error" };

    const subscriber = ((await res.json())?.subscriber ?? {}) as RCSubscriber;

    // One premium entitlement in this project, and its RevenueCat identifier is
    // a display-style string, so any unexpired entitlement counts rather than
    // matching an exact key. Survives a rename.
    const ents = subscriber.entitlements ?? {};
    const now = Date.now();
    const entitled = Object.values(ents).some(
      (e) => e && (e.expires_date == null || new Date(e.expires_date).getTime() > now),
    );

    // Has RevenueCat ever seen money from this id? If not, a denial is either a
    // free user (fine) or a broken alias (not fine), and only the log can tell
    // those apart in aggregate.
    const hasHistory =
      Object.keys(subscriber.subscriptions ?? {}).length > 0 ||
      Object.keys(subscriber.non_subscriptions ?? {}).length > 0 ||
      Object.keys(ents).length > 0;

    const reason: Reason = entitled ? "rc_active" : hasHistory ? "rc_expired" : "rc_silent";
    entitlementCache.set(userId, { entitled, reason, at: Date.now() });
    return { entitled, enforced, reason };
  } catch {
    return { entitled: true, enforced: false, reason: "rc_unreachable" };
  }
}

/// One greppable line per decision, for `supabase functions logs`.
///
/// The user id is hashed: these logs exist to be read in bulk for weeks, and a
/// question about how many people were denied does not need to name them. The
/// hash is stable within a deploy, which is all "how many distinct users" needs.
export async function logDecision(fn: string, userId: string, d: Decision): Promise<void> {
  if (!REQUIRE_ENTITLEMENT && !ENTITLEMENT_SHADOW) return;
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(userId));
  const who = Array.from(new Uint8Array(digest).slice(0, 6))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  console.log(
    `ENTITLEMENT fn=${fn} user=${who} entitled=${d.entitled} enforced=${d.enforced} reason=${d.reason}`,
  );
}

/// The whole gate for a call site: decide, log, answer.
export async function entitlementAllows(fn: string, userId: string): Promise<boolean> {
  const decision = await checkEntitlement(userId);
  await logDecision(fn, userId, decision);
  return allows(decision);
}
