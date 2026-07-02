import time
import numpy as np
import onnxruntime as ort

MODEL_PATH = "/home/pranav/yolo11n-pose.onnx"
N_WARMUP = 5
N_RUNS = 50

so = ort.SessionOptions()
so.intra_op_num_threads = 4
so.inter_op_num_threads = 1
session = ort.InferenceSession(MODEL_PATH, sess_options=so, providers=["CPUExecutionProvider"])

input_info = session.get_inputs()[0]
input_name = input_info.name
_, c, h, w = input_info.shape
print(f"Model input: {input_name} shape=(1,{c},{h},{w})")

rng = np.random.default_rng(0)
frame = rng.random((1, c, h, w), dtype=np.float32)

for _ in range(N_WARMUP):
    session.run(None, {input_name: frame})

latencies = []
for _ in range(N_RUNS):
    t0 = time.perf_counter()
    session.run(None, {input_name: frame})
    latencies.append(time.perf_counter() - t0)

latencies = np.array(latencies)
mean_ms = latencies.mean() * 1000
p50_ms = np.percentile(latencies, 50) * 1000
p95_ms = np.percentile(latencies, 95) * 1000
max_ms = latencies.max() * 1000
fps = 1.0 / latencies.mean()

print(f"\n=== YOLO11n-pose ONNX Runtime CPU benchmark on this Pi 4B ===")
print(f"runs: {N_RUNS} (after {N_WARMUP} warmup)")
print(f"mean:  {mean_ms:.1f} ms")
print(f"p50:   {p50_ms:.1f} ms")
print(f"p95:   {p95_ms:.1f} ms")
print(f"max:   {max_ms:.1f} ms")
print(f"max sustainable FPS (mean-based): {fps:.2f}")
