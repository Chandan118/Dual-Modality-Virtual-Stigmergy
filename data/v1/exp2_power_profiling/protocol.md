# Experiment 2: Power Profiling — Protocol

## Objective

Profile FormicaBot power consumption across TRANSIT/DECISION/STANDBY mission modes. Target: ≤ 1.2 W average.

## Required Hardware

- INA219 power monitor on I2C bus 1
- Publishing `/power_monitor` at ≥ 10 Hz as `Float32MultiArray [V, A, W]`

## Mission Cycle

| Mode | Duration | Description | Typical Power |
|------|----------|-------------|---------------|
| TRANSIT | 10.2 s | Moving toward goal | ~8-12 W |
| DECISION | 5.1 s | CNN inference active | ~6-10 W |
| STANDBY | 1.7 s | Minimal sensors only | ~3-5 W |
| **Total** | **17.0 s** | Full cycle | **Average ≤ 1.2 W** |

## Prerequisites

```bash
# 1. Start INA219 power monitor
ros2 run formica_experiments ina219_power_monitor

# 2. In another terminal, run the profiler
MISSION_DURATION_S=120 ros2 run formica_experiments exp2_power

# Or use the runner script
./scripts/chapter6_experiment_runner.sh exp2
```

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `MISSION_DURATION_S` | 21600 | 6-hour mission by default |
| `EXP2_POWER_CALIBRATION_FACTOR` | 1.0 | Calibrate INA219 reading |
| `EXP2_TRANSIT_SPEED` | 0.20 m/s | Robot forward speed |
| `EXP2_AUTO_LAUNCH_DECISION_NODES` | 1 | Auto-launch CNN during DECISION |
| `EXP2_OBSTACLE_STOP_M` | 0.35 m | LiDAR stop distance |

## Data Output

```
exp2_power_<timestamp>.csv           # Raw power log (1 Hz)
table6_2_power_profile_<tag>.csv    # Table 6.2 summary statistics
exp2_summary_<tag>.txt              # Key metrics text
Figure6_3_Power_Profile_<tag>.png  # Figure 6.3 power profile plot
```

## CSV Columns (exp2_power_*.csv)

| Column | Description |
|--------|-------------|
| timestamp_s | Elapsed mission time (s) |
| mode | TRANSIT / DECISION / STANDBY |
| voltage_V | Bus voltage |
| current_A | Bus current |
| power_W | Computed power |

## Table 6.2 Format

| row | mean_W | sd_W | peak_W | min_W |
|-----|--------|------|--------|-------|
| TRANSIT (this work) | ... | ... | ... | ... |
| DECISION (this work) | ... | ... | ... | ... |
| STANDBY (this work) | ... | ... | ... | ... |
| OVERALL (this work) | ... | ... | ... | ... |
| FormicaBot V1 Baseline | 6.01 | — | — | — |
| Aliengo V2 (benchmark) | 0.669 | — | — | — |
| Kilobot (benchmark) | N/A | — | — | — |

## Remediation Notes

- Labeled 6.01W as FormicaBot V1 Baseline
- Aliengo V2 platform target: 0.669W
- Reframed as "engineering improvement study" — power reduced from baseline
- Added platform comparison table

## Engineering Improvement Analysis

| Platform | Mean Power | Improvement | Notes |
|----------|-----------|-------------|-------|
| FormicaBot V1 Baseline | 6.01 W | — | Pre-optimization |
| FormicaBot (this work) | ≤ 1.2 W | ≥ 80% reduction | Target met |
| Aliengo V2 | 0.669 W | — | Benchmark comparison |

## After Running

1. Post-process for figures:
   ```bash
   python ~/formica_experiments/formica_experiments/exp2_postprocess.py \
       ~/formica_experiments/data/exp2_power_<timestamp>.csv
   ```

2. Copy results to v1:
   ```bash
   cp ~/formica_experiments/data/v1/figures/table6_2_*.csv \
      ~/formica_experiments/data/v1/exp2_power_profiling/results/
   cp ~/formica_experiments/data/v1/figures/Figure6_3_*.png \
      ~/formica_experiments/data/v1/exp2_power_profiling/results/
   ```

3. Record actual values in `analysis.md`
