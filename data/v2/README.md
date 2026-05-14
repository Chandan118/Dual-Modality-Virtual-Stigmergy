# Alloingo V2 — Chapter 7 Engineering Validation

## Purpose

V2 (Alloingo) is the **engineering validation platform** that closes every quantified gap identified in V1. Every V1 failure is addressed with a measurable improvement. Experiments V2-1 through V2-5 are the core engineering validation. Experiments V2-6 through V2-8 respond to Reviewer 2's feedback on portability, parameter selection, and scalability.

> **Key framing**: Every V1 failure has a V2 improvement. Every Reviewer 2 concern has a quantified response.

---

## Core Engineering Validation — V2-1 to V2-5

16/16 metrics PASS ✓

| Exp | Name | Result | Target | Evidence |
|-----|------|--------|--------|---------|
| V2-1 | Power Profiling | 0.669 W | <= 1.2 W | tegrastats + PDB INA3221; 10-min foraging mission |
| V2-2 | Maze Navigation | >= 89% | >= 89% | 20 trials; full LiDAR/SLAM Nav2 stack |
| V2-3 | Pheromone S2R Gap | 13.8% | < 15% | Gazebo sim vs TCRT5000 ADC; 28% decay limit documented |
| V2-4 | Fault Tolerance | < 0.5s recovery | < 0.5s | LiDAR kill; 30 trials; interrupt-driven power gating |
| V2-5 | Thermal Profile | CPU < 50°C | < 50°C | 30-min tegrastats; 0 throttle events; rise +3.5°C |

### V1 → V2 Core Delta

| Metric | V1 | V2 | Delta |
|--------|----|----|-------|
| Mean Power | 6.0 W | **0.669 W** | ~89% reduction |
| Voltage Sag | 450 mV | **< 50 mV** | 90% reduction |
| LiDAR RMSE | 1.2455 m | **0.015 m** | 62× improvement |
| IMU Drift | 3189 deg/min | **0.12 deg/min** | 26,575× reduction |
| Odometry Error | 4.11% | **1.8%** | 2× improvement |
| SLAM Coverage | 0% (killed) | **>= 95%** | Fail → pass |
| SLAM RMSE | N/A (failed) | **0.087 m** | New capability |
| CNN mAP | N/A (thermal kill) | **0.978** | New capability |
| CNN Endurance | Kill at t=45s | **> 10 min** | Indefinite |
| Maze Success | ~100% (reactive only) | **>= 89%** | Full SLAM |
| Fault Recovery | 1.8 s | **< 0.5 s** | 3.6× faster |
| Fault Success | N/A | **>= 73.2%** | New validation |
| Pheromone Dev | 1.5 cm | **<= 1.5 cm** | Matched |
| S2R Gap | 15.4% | **< 15%** | Improved |
| CPU Temp | ~80°C (throttle) | **< 50°C** | No throttle |
| Ambient Rise | ~15°C | **< +5°C** | 67% reduction |

---

## Reviewer 2 Responses — V2-6 to V2-8

3/3 PASS ✓

### V2-6: Cross-Platform Algorithm Portability

> *"Does the algorithm work on standard platforms, or only on custom hardware?"*

TurtleBot3 Burger (RPi 3B+ + LDS-01) runs the **identical** `bio_inspired_nav.launch.py` via topic remapping.

| Metric | Alloingo V2 | TurtleBot3 | Target |
|--------|-------------|------------|--------|
| Success Rate | 90% | **95%** | >= 90% |
| Compute | Jetson TX2 | RPi 3B+ | — |
| LIDAR | RPLIDAR A1 | LDS-01 | — |

### V2-7: Parameter Stability Heat Map

> *"Were parameters (ρ = 0.1) selected through scientific testing or lucky guesses?"*

500 simulation trials across ρ ∈ [0.05, 0.50] and CI ∈ [0.0, 1.0]. ρ = 0.10 sits in the **robust plateau** region (85–100% success across all CI levels). The algorithm tolerates **±100% variation** in the evaporation rate.

### V2-8: Multi-Robot Scalability

> *"How does the algorithm scale with swarm size?"*

Sim-to-Real bridge gap: **4.3%** (simulation 93% vs physical 89% — validated).

| n | Time (% Baseline) | Speedup | Path Reliability | Collision Rate |
|---|------------------|---------|-----------------|---------------|
| 1 | 100% | 1.00× | 45% | 0.00% |
| 2 | 59.4% | 1.68× | 65% | 0.00% |
| 3 | 44.2% | 2.27× | 78% | 0.00% |
| 5 | 30.8% | 3.25× | 90% | 0.00% |
| 10 | **19.6%** | **5.11×** | **95%** | 1.00% |

---

## Directory Structure

```
v2/
├── CONSOLIDATED_SUMMARY.md              # Master summary — all 8 experiments
├── README.md                             # This file
├── HARDWARE_TOPOLOGY.md                  # Tri-board architecture docs
├── v2_master.py                          # Unified runner for all 8 experiments
│
├── ANALYSIS:
│   ├── v2_consolidated_analysis.py        # Aggregates all experiments
│   └── v2_master_runner.py               # Experiment orchestration
│
├── CORE ENGINEERING (V2-1 to V2-5):
│   ├── exp1_power_profiling/
│   │   ├── protocol.md
│   │   └── scripts/v2_power_logger.py
│   ├── exp2_maze_navigation/
│   │   ├── protocol.md
│   │   └── scripts/v2_maze_runner.py
│   ├── exp3_pheromone_s2r/
│   │   ├── protocol.md
│   │   └── scripts/v2_s2r_analysis.py
│   ├── exp4_fault_tolerance/
│   │   ├── protocol.md
│   │   └── scripts/v2_fault_runner.py
│   └── exp5_thermal_profile/
│       ├── protocol.md
│       └── scripts/v2_thermal_logger.py
│
└── REVIEWER 2 RESPONSES (V2-6 to V2-8):
    ├── exp6_cross_platform/
    │   ├── protocol.md
    │   └── scripts/v2_turtlebot_runner.py
    ├── exp7_parameter_stability/
    │   ├── protocol.md
    │   └── scripts/
    │       ├── v2_param_sweep.py         # Batch simulation runner
    │       └── v2_heatmap_generator.py    # Heat map from sweep data
    └── exp8_scalability/
        ├── protocol.md
        └── scripts/v2_scalability_analysis.py  # Swarm simulation runner
```

---

## Quick Start

```bash
cd ~/formica_experiments/data/v2

# Run ALL experiments (V2-1 to V2-8)
python v2_master.py all

# Run by group
python v2_master.py core          # Core engineering (V2-1 to V2-5)
python v2_master.py r2            # Reviewer 2 responses (V2-6 to V2-8)

# Run individual experiments
python v2_master.py exp1          # Power profiling
python v2_master.py exp2          # Maze navigation
python v2_master.py exp3          # Pheromone S2R gap
python v2_master.py exp4          # Fault tolerance
python v2_master.py exp5          # Thermal profile
python v2_master.py exp6          # TurtleBot3 portability
python v2_master.py exp7          # Parameter heat map
python v2_master.py exp8          # Multi-robot scalability

# Analyse and summarise
python v2_master.py analyse
python v2_master.py summary
```

---

## SSH Access

```bash
# Sensing Motherboard (primary compute)
ssh unitree@192.168.123.12    # Password: 123

# Motion Control Motherboard
ssh unitree@192.168.123.220   # Password: 123

# Check connectivity
ping 192.168.123.12
ping 192.168.123.220
```
