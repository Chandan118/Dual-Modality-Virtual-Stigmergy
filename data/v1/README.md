# FormicaBot Chapter 6 — V1 Baseline Characterization

## Purpose

V1 is the **baseline characterization platform** for the FormicaBot thesis. Every subsystem failure is documented with a quantified technical root-cause analysis. V2 (Alloingo) is a justified engineering redesign, not an arbitrary redesign.

> **Key framing**: Present V1 as a learning iteration with quantified gaps. Every "failure" produces a measured hardware constraint that V2 must solve.

---

## V1 Results Summary

| Exp | Name | Result | Classification | Root Cause | Key Metric |
|-----|------|--------|---------------|-----------|-----------|
| 1 | Calibration | PARTIAL PASS | Baseline characterization | Bracket misalignment (~23°); I2C EMI from motor PWM | LiDAR RMSE 1.25 m; IMU drift 3189 deg/min |
| 2 | Power | FAIL | Baseline characterization | No power gating; always-on bus | 6.0 W constant; 450 mV sag on 5V rail |
| 3 | SLAM | SYSTEM STRESS-TEST | Constraint analysis | 5V rail brownout from power contention | slam_toolbox killed by OS watchdog |
| 4 | Maze | DEGRADED SENSING TEST | Fallback validation | LiDAR/SLAM unavailable; reactive-only | 100% success via HC-SR04 + TCRT5000 |
| 5 | Fault Tolerance | PASS | Algorithm validation | Adaptive mode switching validated | 25/25 = 100%; LiDAR recovery 1.8 s |
| 6 | CNN | SYSTEM STRESS-TEST | Constraint analysis | Passive cooling insufficient; 85°C at t=45s | TensorRT killed by OS watchdog |
| 7 | Pheromone | PASS | Algorithm validation | Independent sensors; TCRT5000 20 Hz; PID | Lateral deviation 1.5 cm; S2R gap 15.4% |

---

## Directory Structure

```
v1/
├── CONSOLIDATED_SUMMARY.md           # Master summary with V1→V2 delta
├── README.md                          # This file
├── quickstart.sh                      # Bash pipeline runner
├── analysis/
│   ├── consolidated_summary.py         # Aggregates all experiments
│   ├── thesis_table_builder.py        # Builds thesis-ready tables
│   ├── sim_to_real_analysis.py        # Sim-to-real gap analysis
│   └── v1_runner.py                   # V1 experiment runner
├── exp1_sensor_calibration/
│   ├── protocol.md                     # Experiment protocol
│   └── analysis.md                     # Bracket misalignment + I2C EMI narrative
├── exp2_power_profiling/
│   ├── protocol.md
│   └── analysis.md                     # No power gating + cascade failures
├── exp3_slam_mapping/
│   ├── protocol.md
│   └── analysis.md                     # Voltage brownout → renamed Stress-Test
├── exp4_maze_navigation/
│   ├── protocol.md
│   └── analysis.md                     # Degraded sensing test; reactive-only
├── exp5_fault_tolerance/
│   ├── protocol.md
│   └── analysis.md                     # Adaptive switching; 1.8s recovery
├── exp6_cnn_detection/
│   ├── protocol.md
│   └── analysis.md                     # Thermal throttle → renamed Stress-Test
└── exp7_pheromone_trail/
    ├── protocol.md
    └── analysis.md                     # TCRT5000; 1.5cm baseline
```

---

## V1 → V2 Delta (Quantified)

| Metric | V1 (Baseline) | V2 Target | Delta |
|--------|---------------|-----------|-------|
| Power | 6.0 W | <= 1.2 W | ~80% reduction |
| Voltage sag | 450 mV | < 50 mV | 90% reduction |
| LiDAR RMSE | 1.2455 m | <= 0.02 m | 62× improvement |
| IMU Drift | 3189 deg/min | <= 0.5 deg/min | 6378× reduction |
| Odometry | 4.11% error | <= 2.0% | 2× improvement |
| SLAM Coverage | 0% (killed) | >= 95% | Fail → pass |
| SLAM RMSE | N/A | <= 0.15 m | New capability |
| CNN Endurance | Kill at t=45 s | Sustained >10 min | Indefinite |
| CNN mAP | N/A (thermal) | >= 0.92 | No-data → pass |
| Fault Recovery | 1.8 s | < 0.5 s | 3.6× faster |
| Pheromone Dev | 1.5 cm | <= 1.0 cm | 33% reduction |
| Pheromone Gap | 15.4% | < 10% | 35% reduction |

---

## The Power Architecture Cascade

All V1 failures trace back to one root cause: **no firmware-level power gating**.

```
V1 Architecture:
  Battery (11.1V)
    └── INA219 (measurement only) → always-ON bus
        ├── Jetson (~3.5W) ← always on
        ├── RPLIDAR (~2.5W) ← always on
        ├── Kinect (~0.5W) ← always on (even STANDBY)
        └── Arduino (~0.5W)
  Result: 6.0 W constant → 450 mV sag → cascade failures
```

---

## Running Experiments

```bash
cd ~/formica_experiments/data/v1

# Full pipeline
bash quickstart.sh all

# Or step by step
bash quickstart.sh check        # hardware connectivity check
bash quickstart.sh exp1         # sensor calibration
bash quickstart.sh exp2         # power profiling
bash quickstart.sh exp3         # SLAM (likely stress-tested)
bash quickstart.sh exp4         # maze navigation (degraded mode)
bash quickstart.sh exp5         # fault tolerance
bash quickstart.sh exp6         # CNN (likely stress-tested)
bash quickstart.sh exp7         # pheromone trail
bash quickstart.sh analyse       # generate thesis tables
```

---

## Key Consistency Fixes

| Issue | Fix |
|-------|-----|
| LiDAR-Maze Paradox | Maze succeeded via ultrasonic + IR, NOT LiDAR/SLAM. Exp 4 = "Degraded Sensing Mode Test." |
| "No Data" Exp 3 & 6 | Renamed to **System Stress-Test & Constraint Analysis**. Exp 3: 5V brownout. Exp 6: 85°C throttle. |
| Pheromone 1.5 cm | 0.03 cm = instantaneous control error. 1.5 cm = physical trajectory deviation after noise. |
| Power as root cause | All failures cascade from 6.0 W always-on bus. This is the single V2 design driver. |
