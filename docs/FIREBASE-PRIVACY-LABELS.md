# App Store Connect — App Privacy update for Firebase Analytics (1.0.3)

We added **Google Analytics for Firebase** (Analytics SDK only — no AdMob, no
IDFA/AdSupport, no Crashlytics, no personal Analytics User ID). Before submitting
1.0.3, the App Privacy nutrition labels must declare what Analytics collects.
These are **added to** the existing 1.0.2 declarations (auth email, user content,
etc.) — don't remove those.

Source: Google's own guidance (support.google.com/analytics/answer/10285841) +
Apple App Privacy categories.

## Data types to ADD

All of the following are **NOT used for tracking** and **NOT linked to the
user's identity** (by default Analytics ties data only to the anonymous app
instance ID; we do not set a personal Analytics User ID, only user *properties*
like skill level). Purpose for each: **Analytics**.

| Apple data type | Category | Why (Firebase) | Linked? | Tracking? |
|---|---|---|---|---|
| **Device ID** | Identifiers | Firebase app instance ID | No | No |
| **Product Interaction** | Usage Data | screen_view + custom events + sessions | No | No |
| **Coarse Location** | Location | approximate, derived from a **masked** IP | No | No |
| **Purchase History** | Purchases | we log `subscription_started` to Analytics¹ | No | No |

¹ Only because a subscription event is logged to Analytics. If you'd rather not
declare Purchases, stop logging `subscription_started` to Firebase (keep it in
RevenueCat only). Declaring it is the safe, honest choice — keep it.

## Data used to track you: **NONE**
Confirmed: the app links **no** AdSupport.framework, runs **no** ads, reads **no**
IDFA, and shares nothing with data brokers. So "Used to Track You" stays empty →
**no ATT (App Tracking Transparency) prompt required.** Do not add one.

## ASC click-path
App Store Connect → **DropVolley** → left nav **App Privacy** → **Edit**.
For each of the 4 data types above:
1. **+ Add** the data type (under its category).
2. "Used for tracking?" → **No**.
3. "Linked to the user's identity?" → **No**.
4. Purposes → check **Analytics** (also **App Functionality** for Device ID if
   prompted — it's used to make the app work too).
5. Save.
Then **Publish** the changes. (Labels can be published independently, but they
must be accurate for the 1.0.3 build you submit.)

## Verify before submit
- No `import AdSupport` / no AdMob anywhere → `grep -rn "AdSupport\|GADApplication\|advertisingIdentifier" CourtIQ` should be empty.
- We only call `Analytics.setUserProperty` (properties), never `Analytics.setUserID` with a personal id → keeps everything "not linked".
- Firebase console: **Analytics → Data collection** — IP anonymization / masked IP is Google's default; leave it on.
