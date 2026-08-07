# Hub alert-latency measurement — 2026-08-07

Hardware: Windows 11 laptop, Intel Core Ultra 9 275HX, NVIDIA GeForce RTX
5060 Laptop GPU. Python 3.13, ONNX Runtime DirectML, `yolo11s-pose` at
480x640. This is a Hub-to-HTTP-ingest measurement, not a caregiver-phone
notification measurement.

## Method

Run from the repository root:

```powershell
python tools/measure_alert_latency.py --runs 100 --real-inference --json-out benchmarks/alert_latency_2026-08-07.json
python tools/measure_multi_camera_capacity.py --seconds 5
```

`measure_alert_latency.py` sends a known synthetic COCO-17 pose timeline
through the real `HubDaemon` wiring: frame preprocessing, scripted pose result,
IoU tracking, kinematic features, fall state machine, event engine, SQLite
enqueue, and the production `NotificationDispatcher`. The dispatcher performs a
real HTTP POST to a fresh local loopback HTTP server and waits for its HTTP 202
ack. Separately, the same installed 480x640 ONNX model is warmed and measured
100 times, because the scripted timeline deliberately replaces model output to
make fall onset and each state transition reproducible.

**Fall onset definition:** the timestamp of the first sample that crosses both
the fall-candidate velocity and torso-angle thresholds. This is a rigorous,
repeatable detector definition; it is not a claim about the first physical
motion visible in a real camera frame. The confirmed trace is candidate at
0.4s, horizontal/still confirmation at 2.4s. The suspected trace deliberately
remains moving enough to avoid the early-stillness branch and reaches the
candidate-window fallback at 3.5s.

## Results (100 runs)

The direct measurement reported these p50 / p95 / max stage values in ms.
`inference` below is the scripted estimator's call cost; the real model row is
reported separately and is substituted into the end-to-end conservative total.

| Path | Stage | p50 | p95 | max |
|---|---|---:|---:|---:|
| Confirmed | capture | 0.000 | 0.000 | 0.000 |
| Confirmed | preprocess (scripted-chain) | 1.760 | 1.939 | 2.095 |
| Confirmed | track | 0.133 | 0.179 | 0.294 |
| Confirmed | features + state | 0.038 | 0.050 | 0.065 |
| Confirmed | event emit | 0.051 | 0.068 | 0.134 |
| Confirmed | SQLite enqueue | 0.083 | 0.111 | 0.177 |
| Confirmed | HTTP dispatch + 202 ack | 13.232 | 22.643 | 118.507 |
| Confirmed | detection clock | 2000.000 | 2000.000 | 2000.000 |
| Suspected | capture | 0.000 | 0.000 | 0.000 |
| Suspected | preprocess (scripted-chain) | 3.657 | 4.146 | 4.304 |
| Suspected | track | 0.422 | 0.510 | 0.556 |
| Suspected | features + state | 0.111 | 0.129 | 0.143 |
| Suspected | event emit | 0.066 | 0.080 | 0.107 |
| Suspected | SQLite enqueue | 0.106 | 0.131 | 0.267 |
| Suspected | HTTP dispatch + 202 ack | 9.921 | 26.238 | 28.084 |
| Suspected | detection clock | 3100.000 | 3100.000 | 3100.000 |

Real 480x640 DirectML pose stage: preprocessing **1.571 / 1.874 / 2.211ms**;
inference plus decode **5.785 / 6.221 / 6.369ms** (p50 / p95 / max).

There are three model frames in the confirmed trace and nine in the suspected
trace. Replacing the scripted estimator cost with the measured p95 model stage,
then adding the p95 remaining chain stages and local HTTP ack gives conservative
Hub-to-loopback-ack totals of **2.027s confirmed** and **3.200s suspected**.
Both are below five seconds on this machine.

## What this proves, and what it does not

This proves the specified Hub pipeline and an actual HTTP request/ack on this
machine fit beneath five seconds for both state-machine paths, with generous
margin. The deterministic test `test_detection_threshold_contract_stays_within_five_second_deck_budget`
prevents the 2.0s / 3.1s detection gates from silently exceeding that budget.

It does **not** measure USB/webcam capture delay, a real staged-fall clip's pose
accuracy, WAN latency to the deployed backend, backend processing, push-provider
latency, or phone/staff notification display. Therefore the deck wording
“alerts to staff in under 5 seconds” remains unproven end-to-end. The defensible
current wording is: **“Hub detection and local HTTP ingest acknowledgment p95:
under 3.2 seconds in a reproducible synthetic-pose test.”** A real camera clip
and authenticated production-backend/app timing trace are required before making
the stronger staff-alert claim.

## Concurrent-room capacity

`measure_multi_camera_capacity.py` uses one real shared 480x640 ONNX session,
synthetic normalized frames, and `InferenceScheduler` round-robin. Five seconds
per case produced:

| Cameras | Aggregate FPS | minimum room FPS | maximum room FPS |
|---:|---:|---:|---:|
| 1 | 193.6 | 193.6 | 193.6 |
| 2 | 197.4 | 98.6 | 98.8 |
| 4 | 190.6 | 47.6 | 47.8 |
| 8 | 196.6 | 24.4 | 24.6 |
| 12 | 183.8 | 15.2 | 15.4 |
| 16 | 189.0 | 11.8 | 12.0 |
| 20 | 191.2 | 9.4 | 9.6 |

Validated operating limit: **12 simultaneous synthetic 480p streams at at
least 15.2 effective FPS/room**. At 20 streams, the 9.4 FPS minimum is below
the conservative 15 FPS demo target, so 20 is not claimed as a validated
operating configuration. This is consistent with the earlier single-stream
GPU benchmark (~218 FPS on 2026-07-02), with the lower present figure reflecting
full decode and scheduler overhead. It does not measure real camera I/O or
multi-person accuracy; it establishes shared-inference scheduling capacity.
