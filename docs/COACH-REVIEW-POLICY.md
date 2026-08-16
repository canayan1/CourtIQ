# Coach Review — video rights, consent & enforcement policy

*Answers "what happens if a coach records / uses / shares the video" —
as product copy, contract clauses, and technical controls. Lawyer formalizes
the contract text; this is the binding intent.*

## 1. Video usage matrix (the one-page answer)

| Action by coach | Allowed? | Mechanism |
|---|---|---|
| Stream & watch during review window | ✅ | Short-TTL signed URL, dashboard player |
| Download / export / screen-record | ❌ | No download UI + agreement clause 3 + access logs; watermark on roadmap |
| Keep access after delivery | ❌ | Access auto-revoked at Deliver; URL expires |
| Share with anyone (incl. other coaches) | ❌ | Agreement clause 3; breach = termination + liability |
| Post on social media / own marketing | ❌ default | ONLY via platform promo flow (below) |
| Use to train AI/models | ❌ | Explicit agreement clause |
| Platform promo use (our IG, store) | ❌ default | Separate per-order user opt-in toggle, default OFF, revocable |

**Promo flow (the only legitimate share path):** user flips an explicit
per-order toggle ("This clip + review may be used in DropVolley marketing").
Off by default, revocable in-app, revocation cascades to takedown. Coach NEVER
posts directly; platform posts, coach may reshare the platform post.

## 2. User-facing consent screen (shown at order, separate from AI consent)

**EN:**
> **A real coach will watch this video.**
> Your video is shared with one certified DropVolley coach — only to create
> your review. They can stream it, not download it, and their access ends
> when your review is delivered.
> • Never posted or shared. Marketing use only if YOU opt in per video.
> • Original video auto-deletes 90 days after delivery. Delete anytime.
> • Make sure people visible in the clip are okay with it being reviewed.
> • 18+ feature.
> [I understand — continue]

**TR:**
> **Bu videoyu gerçek bir antrenör izleyecek.**
> Videon yalnızca incelemeni hazırlamak için tek bir sertifikalı DropVolley
> antrenörüyle paylaşılır — izleyebilir, indiremez; erişimi inceleme teslim
> edildiğinde biter.
> • Asla paylaşılmaz/yayınlanmaz. Pazarlama kullanımı ancak SEN her video için
> ayrıca izin verirsen.
> • Orijinal video teslimattan 90 gün sonra otomatik silinir. İstediğin an sil.
> • Karede görünen kişilerin buna itirazı olmadığından emin ol.
> • 18 yaş ve üzeri içindir.
> [Anladım — devam]

## 3. Coach agreement — video clauses (plain-language draft for the lawyer)

1. **Purpose limitation:** Coach accesses user videos solely to produce the
   commissioned review. Any other use is prohibited.
2. **Data processing (KVKK/GDPR DPA annex):** Coach acts as processor on
   platform instructions; must report any suspected breach within 24h.
3. **No retention or reproduction:** No downloading, recording, screen
   capture, storage, or reproduction in any form. Access ends at delivery.
4. **No disclosure:** No sharing with any third party; no public posting; no
   use in coach's own marketing. Platform promo only via §1's opt-in flow.
5. **No AI training** on user content.
6. **Breach consequences:** immediate termination, forfeiture of unpaid
   platform-side amounts, liability for damages incl. regulatory fines caused
   (KVKK idari para cezası rücu), takedown cooperation.
7. **Conduct:** no medical/injury advice; boundaries per the review template.
8. **Audit:** platform logs access (who/when/which order) and may sample
   deliverables for quality.

## 4. Technical enforcement (what actually stops misuse)

- Private Supabase bucket; per-order **signed URLs with short TTL** (~2h,
  re-issuable while order open), issued only to the assigned coach's session.
- Dashboard player is **stream-only** (no download control, no raw link
  surfaced); right-click/save disabled — deterrence, not DRM.
- **Access log table** (`coach_access_log`: coach, order, ts, ip) — every
  play recorded; visible in admin.
- **Delivery revokes**: order → `delivered` flips bucket policy off for that
  path; deliverables live separately.
- Roadmap (P1): burned-in per-coach watermark (coach id + order id corner
  overlay via ffmpeg on ingest) → any leak is attributable.
- Honest limit: a phone can always film a screen. The real controls are
  small trusted supply, attribution (watermark), contract liability, and
  fast offboarding. Founding phase = Can himself, so the standard starts
  self-enforced.

## 5. Retention & deletion

- Raw video: auto-delete **90 days** after delivery (cron) or instantly on
  user deletion (cascades: storage object + coach access + case file).
- Deliverables (voice/notes/scorecard): kept in user account until user
  deletes; included in account-deletion flow.
- Waitlist (G0): stores only an analytics event + local flag — no new PII.

## 6. Doc/label updates required before P0 launch (not G0)

- Privacy policy: human-reviewer processing, processor category "certified
  coaches under contract", retention terms above.
- ToS: marketplace terms, refund policy (24h no-questions at P0), 18+ gate.
- App Privacy labels: user content (video) linked to user, shared with
  service providers. *(Web UI — user does this.)*
- G0 "notify me" card needs NONE of these (no purchase, no upload sharing,
  no new data) — safe to ship immediately.
