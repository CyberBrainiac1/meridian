# Resident activity rollup

MeridianFamily can now show a daily, non-clinical room-movement update. It is
not meal tracking, location tracking, sleep tracking, or a health assessment.
The system is deliberately more willing to say “not enough to compare” than
to turn a missing camera observation into a story about a resident.

## What ships

The Hub produces one completed-day `ResidentActivityRollup` per provisioned
resident-room camera. The Family app receives the most recent completed day
(clearly labelled “Yesterday” when appropriate) through
`public.family_activity_rollup_feed`; staff can see the same latest category
in the resident detail page in Meridian Insights.

| Family/staff label | Exact backing observation | What it does not mean |
| --- | --- | --- |
| Usual room movement | The count of local 30-minute daytime buckets containing observed pose movement was within 30% of the median of the resident-room camera's recent eligible days. | It does not establish a medical status, gait quality, exercise, or a resident's location. |
| Lower/higher room movement than usual | The same local bucket count differed by at least 30% from that personal median, after sufficient observation. | It does not diagnose decline, agitation, sleep trouble, or an emergency. Care staff have the full context. |
| Usual/lower/higher overnight movement | The equivalent comparison for midnight–08:00 local facility time, only where sufficient night observation and history exist. | It does not measure sleep, waking, bathroom trips, breathing, or “rest quality.” |
| Building the usual rhythm | Fewer than seven eligible prior days exist. | It never calls a new resident “usual.” |
| Not enough to compare | Fewer than eight observed daytime half-hour buckets (four hours) exist for the day, or fewer than two at night. | It is not reported as low activity. It may mean out of view, multiple people, occlusion, or a camera limitation. |

The UI says “movement we saw in [name]'s room,” not “we know [name] was up
and about.” A room camera can contain staff or visitors and pose does not
identify a lone person. The Hub therefore treats zero-person and
multiple-person frames as unknown; only single-person frames contribute an
observation. This is a conservative room-associated signal, not identity
proof.

## Hub derivation and baseline

`meridian_hub/activity_rollup.py` owns the aggregation. `HubDaemon` accepts a
`ResidentActivityRollupAggregator` by dependency injection. For a single
tracked pose in a provisioned resident room, it compares consecutive hip
centres and treats motion above the existing `15 px/sec` intentional-movement
threshold as movement. The Hub stores only local bucket counts in
`SqliteActivityHistory`; it persists no pose sequence, coordinates, track IDs,
or bucket timestamps.

For each completed local calendar day, the aggregator compares the count of
active daytime half-hour buckets to the median of up to the prior 14 eligible
days. At least seven prior eligible days are required. Insufficient-observation
days are excluded from baseline history, so an absent resident or poor view
cannot pull the baseline down. The night comparison applies the same rule
independently.

The only outbound payload is:

```text
p_rollup_date
p_daytime_pattern
p_nighttime_pattern
p_baseline_status
p_observation_status
```

No count, timestamp within the day, room, camera, pose, track ID, coordinate,
or movement trace is sent. The Hub's authenticated RPC derives the resident
and facility from `resident_hub_devices`, rather than accepting either from a
device payload. `resident_activity_rollups` stores those five coarse
categories and the family view also requires both a family link and active
`family_visibility` consent.

## Deliberately refused metrics

- **Breakfast/meals attended:** a 17-point room pose cannot see or verify a
  meal. There is no meal-tracking pipeline.
- **Time out of room:** an absent pose may be out of frame, occluded, in bed,
  or a camera problem; it cannot prove that someone left.
- **Gait speed or mobility health:** pixels per second are not calibrated
  physical speed and are not a clinical mobility assessment.
- **Sleep quality, bathroom trips, or restfulness:** motion during the night
  is not evidence of any of those things.
- **A resident identity claim from pose:** the system does not use face data
  in this path and cannot prove that a lone tracked person is the resident.

## Verification boundaries

Pytest covers cold start, sparse coverage, a resident simply out of view, a
day genuinely lower than a personal baseline, category-only payloads, and the
injected Hub-to-offline-queue path. The Supabase migration is parsed
statically and asserted to create both the table and family view.

This machine has no Docker, Supabase CLI, `psql`, Deno, or live deployment
access, so the migration/RLS/RPC path is not executed against Supabase. A live
deployment must provision the Hub's authenticated `record-resident-activity-
rollup` RPC URL and its resident-Hub JWT before this route can deliver data.
The SwiftUI changes are intentionally minimal but remain uncompiled here
because there is no Mac/Xcode environment.
