"use client";

import { useEffect, useRef, useState } from "react";
import { demoSkeleton } from "@/lib/tokens";

// Bone pairs reference COCO-17 keypoint names, must match
// meridian_hub/vision/pose_types.py KEYPOINT_NAMES.
const BONES: [string, string][] = [
  ["nose", "left_eye"], ["nose", "right_eye"],
  ["left_eye", "left_ear"], ["right_eye", "right_ear"],
  ["left_shoulder", "right_shoulder"],
  ["left_shoulder", "left_elbow"], ["left_elbow", "left_wrist"],
  ["right_shoulder", "right_elbow"], ["right_elbow", "right_wrist"],
  ["left_shoulder", "left_hip"], ["right_shoulder", "right_hip"],
  ["left_hip", "right_hip"],
  ["left_hip", "left_knee"], ["left_knee", "left_ankle"],
  ["right_hip", "right_knee"], ["right_knee", "right_ankle"],
];

interface Keypoint {
  name: string;
  x: number;
  y: number;
  confidence: number;
}

interface PosePerson {
  confidence: number;
  bbox: [number, number, number, number];
  keypoints: Keypoint[];
}

interface PoseFrame {
  camera_id: string;
  timestamp: number;
  people: PosePerson[];
}

const RELAY_URL = process.env.NEXT_PUBLIC_DEMO_RELAY_WS_URL ?? "ws://localhost:8765/ws/pose";
const KEYPOINT_MIN_CONFIDENCE = 0.3;

export function SkeletonCanvas() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const frameRef = useRef<PoseFrame | null>(null);
  const [status, setStatus] = useState<"connecting" | "connected" | "disconnected">("connecting");
  const [lastFrameAt, setLastFrameAt] = useState<number | null>(null);
  const [isStale, setIsStale] = useState(false);

  useEffect(() => {
    let socket: WebSocket | null = null;
    let reconnectTimer: ReturnType<typeof setTimeout> | null = null;
    let cancelled = false;

    const connect = () => {
      if (cancelled) return;
      setStatus("connecting");
      socket = new WebSocket(RELAY_URL);

      socket.onopen = () => setStatus("connected");
      socket.onmessage = (event) => {
        try {
          frameRef.current = JSON.parse(event.data) as PoseFrame;
          setLastFrameAt(Date.now());
        } catch {
          // Ignore malformed frames — next one will arrive shortly.
        }
      };
      socket.onclose = () => {
        setStatus("disconnected");
        if (!cancelled) reconnectTimer = setTimeout(connect, 2000);
      };
      socket.onerror = () => socket?.close();
    };

    connect();

    return () => {
      cancelled = true;
      if (reconnectTimer) clearTimeout(reconnectTimer);
      socket?.close();
    };
  }, []);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    let raf: number;
    const resize = () => {
      canvas.width = window.innerWidth * window.devicePixelRatio;
      canvas.height = window.innerHeight * window.devicePixelRatio;
      canvas.style.width = `${window.innerWidth}px`;
      canvas.style.height = `${window.innerHeight}px`;
    };
    resize();
    window.addEventListener("resize", resize);

    const draw = () => {
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.fillStyle = demoSkeleton.background;
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.scale(window.devicePixelRatio, window.devicePixelRatio);

      const frame = frameRef.current;
      if (frame) {
        const scaleX = window.innerWidth / 640;
        const scaleY = window.innerHeight / 480;

        for (const person of frame.people) {
          const byName = new Map(person.keypoints.map((k) => [k.name, k]));

          ctx.strokeStyle = demoSkeleton.accent;
          ctx.lineWidth = 3;
          ctx.shadowColor = demoSkeleton.accent;
          ctx.shadowBlur = 8;
          for (const [a, b] of BONES) {
            const ka = byName.get(a);
            const kb = byName.get(b);
            if (!ka || !kb) continue;
            if (ka.confidence < KEYPOINT_MIN_CONFIDENCE || kb.confidence < KEYPOINT_MIN_CONFIDENCE) continue;
            ctx.beginPath();
            ctx.moveTo(ka.x * scaleX, ka.y * scaleY);
            ctx.lineTo(kb.x * scaleX, kb.y * scaleY);
            ctx.stroke();
          }

          ctx.shadowBlur = 0;
          ctx.fillStyle = demoSkeleton.accent;
          for (const kp of person.keypoints) {
            if (kp.confidence < KEYPOINT_MIN_CONFIDENCE) continue;
            ctx.beginPath();
            ctx.arc(kp.x * scaleX, kp.y * scaleY, 4, 0, Math.PI * 2);
            ctx.fill();
          }
        }
      }

      ctx.setTransform(1, 0, 0, 1, 0, 0);
      raf = requestAnimationFrame(draw);
    };
    raf = requestAnimationFrame(draw);

    return () => {
      window.removeEventListener("resize", resize);
      cancelAnimationFrame(raf);
    };
  }, []);

  useEffect(() => {
    const interval = setInterval(() => {
      setIsStale(lastFrameAt !== null && Date.now() - lastFrameAt > 3000);
    }, 500);
    return () => clearInterval(interval);
  }, [lastFrameAt]);

  return (
    <div style={{ background: demoSkeleton.background }} className="fixed inset-0 overflow-hidden">
      <canvas ref={canvasRef} className="absolute inset-0" />

      <div className="absolute top-6 left-6 flex items-center gap-3 font-mono text-sm" style={{ color: demoSkeleton.accent }}>
        <span
          className="h-2.5 w-2.5 rounded-full"
          style={{
            background: status === "connected" && !isStale ? demoSkeleton.accent : "#475569",
            boxShadow: status === "connected" && !isStale ? `0 0 8px ${demoSkeleton.accent}` : "none",
          }}
          aria-hidden="true"
        />
        <span>
          {status === "connected" && !isStale
            ? "SENSE — LIVE POSE FEED"
            : status === "connecting"
              ? "CONNECTING TO SENSE RELAY…"
              : "SENSE RELAY OFFLINE"}
        </span>
      </div>

      <div className="absolute bottom-6 left-6 right-6 flex items-end justify-between font-mono text-xs text-slate-400">
        <p>NO VIDEO TRANSMITTED — SKELETON DATA ONLY</p>
        <p>ws://{RELAY_URL.replace(/^wss?:\/\//, "")}</p>
      </div>
    </div>
  );
}
