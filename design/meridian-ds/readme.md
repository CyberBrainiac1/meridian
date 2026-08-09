# Meridian Design System

Design system for **Meridian — "The Care Intelligence Layer for Senior Living"**: an ambient, camera-based fall-detection and care-intelligence platform for senior-living facilities, built by a 3-person team (Dhairya Gurnani — software, Pranav Emmadi — hardware, Megan — UI/UX/brand) for the YBVC competition.

**Sources:**
- `github.com/CyberBrainiac1/meridian` (connected repo, branch `main`) — the canonical source. `meridian_software/design-tokens/tokens.json` is the single source of truth for color/type/spacing/radius/motion, hand-mirrored into `meridian_care`/`meridian_family` (SwiftUI `Tokens.swift`) and `meridian_hub_ui`/`meridian_insights` (Tailwind `globals.css`). `PRD.md` is the product/content source.
- `uploads/Meridian AI Pitch Deck (A).pdf` — a separate marketing artifact with its own visual language (see "Pitch deck vs. product" below). Extracted assets live in `assets/` and `extracted/`.

## Products
- **Meridian Sense** — the camera + edge-compute hardware unit (on-device pose estimation, no UI).
- **Meridian Care** (`meridian_care/`, SwiftUI, iOS) — caregiver app: real-time alert feed, acknowledge/resolve flow, shift handoff. → `ui_kits/meridian_care/`
- **Meridian Family** (`meridian_family/`, SwiftUI, iOS) — family app: daily "good day" summaries, visitor log, staff-response updates, explicit privacy controls (no video player exists anywhere in the app). → `ui_kits/meridian_family/`
- **Meridian Insights** (`meridian_insights/`, Next.js + Tailwind + Supabase) — facility dashboard: live floor status, response-time analytics, incident reports, visitor observations. → `ui_kits/meridian_insights/`
- **MeridianHub** (`meridian_hub_ui/`, Next.js kiosk) — oversized-touch-target resident-facing kiosk: request help, verify visitors. → `ui_kits/meridian_hub/`

## Pitch deck vs. product — READ THIS FIRST
The repo's PRD explicitly flagged this as an open question ("Does Meridian keep the lumi-slate palette or rebrand fully?"). The two now genuinely differ:
- **The shipped product** (all four surfaces above) uses a clinical sky-blue/cyan palette (`--color-primary:#0369A1`), Figtree/Noto Sans/Fira Code, and an accessibility-audited contrast system. This is canonical — use it for any new product screen.
- **The pitch deck** (`uploads/Meridian AI Pitch Deck (A).pdf`) uses an unrelated oxblood/cornflower marketing palette (Raleway/Instrument Sans/Geist). It's real and intentional (Megan owns pitch-deck design separately per the PRD), but it is marketing collateral, not the product's design language. Its tokens live in `tokens/marketing.css` under a `--deck-*` prefix so they can never be confused with the product's `--color-*` tokens. See the "Pitch Deck" group in the Design System tab.

## CONTENT FUNDAMENTALS
- **Resident-first copy, by hard rule**: alerts read *"Maggie needs help in Room 12,"* never *"Event #4471 triggered."* This is enforced in the type system, not just a style guide — `IncidentEventType.label` is a short category tag, while the resident-facing sentence is a separate `summary` field.
- **Calm, plain, declarative.** Hub kiosk copy: *"Choose what you need. Your care team is here to help."* Family: *"Maggie had a good day."* No exclamation points, no hype.
- **Privacy copy is exact and structural, never euphemistic**: *"New visitor detected at Main Entrance"* — never a name, because the system never resolves one. *"This app has no video player, because there's nothing for it to play."*
- **No emoji anywhere** (`tokens.json`: "No emoji as icons anywhere, including severity/status icons").
- **Status labels are fixed strings, reused verbatim everywhere**: Info / Needs attention (warning) / Emergency (critical). Never invent a synonym.
- **First person for the resident (Hub), third person + relationship for family** ("Ask your consented family contact to call you"), professional/operational for staff (Care/Insights).

## VISUAL FOUNDATIONS
- **Palette**: primary `#0369A1`, primary-alt `#0891B2`, foreground `#0C4A6E` on white/`#F0F9FF`(web)/`#ECFEFF`(mobile). Severity: info=primary, warning=`#B45309`, critical=`#DC2626`, success=`#059669`. Every severity has a `*Strong` text variant (`#92400E`/`#991B1B`/`#047857`) because the base color fails 4.5:1 as text-on-its-own-tint — a real accessibility audit is baked into the tokens, not decorative.
- **Never dim text with opacity** for secondary/caption copy — `foregroundMuted (#2F5D77)` is a solid replacement; opacity-based dimming measured 2.55–4.25:1 and failed.
- **Type**: Figtree (headings, 500/600/700) + Noto Sans (body) on web. Fira Code is reserved for Insights' dense/raw-data tables only — never Care, never Family. iOS apps use San Francisco at matching weights instead of bundling web fonts (documented substitution, not a gap).
- **Radii differ by surface, deliberately**: Insights (web) 16/10, Care 12/10 (tighter, clinical), Family 20/14 (warmer, more whitespace) — "never a separate design language," per the repo comment, just a warmed dial on the same system.
- **Cards**: white surface, 1px `--color-border`, `--shadow-soft` (a very soft double shadow, not a hard drop shadow). The Hub kiosk's status card uses a 10px colored left border instead (a distinct, older CSS pattern kept for its kiosk-specific stakes).
- **Motion**: 150–300ms ease-in-out. The calm/emergency two-state principle is load-bearing: alerts get **exactly one** scale/pop-in on arrival, then hold steady — never continuous flashing or pulsing. Loading states are a skeleton-shimmer, never a spinner. Everything respects `prefers-reduced-motion`.
- **Touch targets**: 44×44pt minimum, 8pt minimum spacing, called out as a *"critical severity issue if violated on Care — a mis-tap on the wrong resident's resolve button during a real emergency is a real failure mode,"* not a nicety.
- **The Hub kiosk is visually distinct on purpose**: 20px base font (vs 16px elsewhere), 112px-min action buttons — designed for residents, some with vision/mobility impairment, to use unassisted.
- **No illustration, no photography, no gradients, no textures** anywhere in the product (that's the pitch deck's language, not the product's). Product surfaces are plain color + type + data.
- **Focus states are always visible**, never suppressed — a 2–4px outline in primary blue.

## ICONOGRAPHY
- **Lucide** on web (Insights, MeridianHub) — `status-badge.tsx` uses `CheckCircle2`/`AlertTriangle`/`OctagonAlert`/`WifiOff`; `nav.tsx` uses `LayoutGrid`/`Gauge`/`ClipboardList`/`DoorOpen`; `hub-surface.tsx` uses `HeartHandshake`/`PhoneCall`/`BellRing`/`ShieldCheck`/`UserRoundCheck`.
- **SF Symbols** on iOS (Care, Family) — e.g. `checkmark.shield`, `exclamationmark.triangle.fill`, `lock.shield.fill`, `video.slash.fill`.
- **Hard rule, from the canonical tokens file**: *"No emoji as icons anywhere, including severity/status icons."*
- No custom icon font, no SVG sprite sheet — each surface pulls from its native icon system.

## Components
`components/forms/`: Button, IconButton, Input, Select, Checkbox, Radio, Switch. `components/display/`: Card, Badge, Tag. `components/navigation/`: Tabs. `components/feedback/`: Dialog, Toast, Tooltip. `components/charts/`: BulletChart, TrendLineChart.
Button/Card/Badge are direct recreations of the real `MeridianButtonStyle`/`CardBackground`/`SeverityBadge` (SwiftUI) and `RoomStatusBadge`/`SeverityBadge` (React) — exact color/radius/touch-target values. BulletChart/TrendLineChart are lightweight recreations of the real Recharts-based Insights components (same palette, same qualitative bands, same "counts are never color-only" text-table pattern).

### Intentional additions
No component library is enumerated in the repo beyond what each screen inlines — these are extracted into reusable primitives, not invented from scratch: IconButton, Select, Radio, Switch, Tag, Tabs, Dialog, Tooltip. All styled strictly from the canonical tokens, never the pitch-deck palette.

## Fonts — substitution note
Figtree, Noto Sans, and Fira Code are all on Google Fonts and loaded via `tokens/fonts.css` (matching `next/font/google` usage in the real `meridian_insights/app/layout.tsx`). No font files needed shipping.

## Index
- `styles.css` — imports `tokens/fonts.css`, `colors.css`, `typography.css`, `spacing.css`, `effects.css` (canonical product tokens) and `tokens/marketing.css` (`--deck-*`, pitch-deck-only).
- `assets/` — logo lockup/shield (from the deck — no product app icon exists yet), pitch-deck illustrations/photos, team photos.
- `guidelines/` — foundation cards: Colors, Type, Spacing, Motion (canonical), Brand, Pitch Deck (marketing reference).
- `components/` — forms, display, navigation, feedback, charts (see above).
- `ui_kits/meridian_insights/` — facility dashboard. `ui_kits/meridian_care/` — caregiver app. `ui_kits/meridian_family/` — family app. `ui_kits/meridian_hub/` — resident kiosk. `ui_kits/deck_slides/` — pitch-deck slide recreations (marketing only).
- `extracted/` — working files from the original PDF extraction pass.
- `github.md` — repo sync record. `SKILL.md` — agent skill entry point.

## Caveats
- Insights' incidents/visitors pages and Care's Residents tab are simplified from the real Next.js/SwiftUI screens (filters, pagination, RLS-backed data) — structure and copy are faithful, but not every prop/state was read in depth.
- TrendLineChart is a lightweight inline-SVG stand-in for the real Recharts `LineChart` — same data shape, palette, and legend-table pattern, not a Recharts port.
