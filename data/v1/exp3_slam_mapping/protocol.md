# Experiment 3: SLAM Mapping — Protocol

## Objective

Construct a globally consistent 2D occupancy grid map using RPLIDAR A1 + slam_toolbox. Target: ≥ 95% map coverage and localization RMSE ≤ 0.15 m at 4 landmark positions.

## Required Hardware

- RPLIDAR A1M8 (or compatible)
- Wheel odometry via Arduino
- 4 pre-placed ArUco markers with known ground-truth positions

## Prerequisites

```bash
# 1. Bringup the robot
ros2 launch formica_experiments bringup_launch.py

# 2. Launch Nav2 stack
ros2 launch formica_experiments nav_stack_launch.py

# 3. Run the SLAM experiment
ros2 run formica_experiments exp3_slam

# Or with auto-start trials
EXP3_AUTO_START=1 ros2 run formica_experiments exp3_slam

# Force cmd_vel autonomy mode (no Nav2)
EXP3_FORCE_CMDVEL_AUTONOMY=1 ros2 run formica_experiments exp3_slam
```

## Landmark Positions

Edit `LANDMARK_POSITIONS_M` in `exp3_slam_mapping.py` to match physical measurements:

```python
LANDMARK_POSITIONS_M = [
    (1.00, 0.00),   # Landmark 1 (ArUco ID 0)
    (1.00, 2.00),   # Landmark 2 (ArUco ID 1)
    (0.00, 2.00),   # Landmark 3 (ArUco ID 2)
    (2.00, 2.00),   # Landmark 4 (ArUco ID 3)
]
```

## Mapping Sweep Pattern (cmd_vel mode)

The robot executes this sweep sequence automatically:

1. Forward 7.5 m
2. Turn left 90° (2.6 rad)
3. Forward 6.8 m
4. Turn left 90°
5. Forward 7.5 m
6. Turn left 90°
7. Forward 6.8 m

## Thresholds

| Metric | Target |
|--------|--------|
| Map coverage | ≥ 95% |
| Localization RMSE | ≤ 0.15 m |
| Trial timeout | 900 s |

## Data Output

```
exp3_slam_<timestamp>.csv           # Per-landmark error log
```

## CSV Columns

| Column | Description |
|--------|-------------|
| trial | Trial number (1-10) |
| landmark_id | Landmark index (0-3) |
| gt_x, gt_y | Ground truth position (m) |
| est_x, est_y | Estimated position (m) |
| error_m | Euclidean error (m) |
| coverage_pct | Map coverage at time of reading |

## Analysis

RMSE is computed per trial and overall:

```
trial_rmse = sqrt(mean(error^2)) across 4 landmarks
overall_rmse = sqrt(mean(all_errors^2)) across all trials
```

## After Running

1. Save the map:
   ```bash
   ros2 run nav2_map_server map_saver_cli -f ~/maps/arena_map
   ```

2. Copy results to v1:
   ```bash
   cp ~/formica_experiments/data/exp3_slam_<timestamp>.csv \
      ~/formica_experiments/data/v1/exp3_slam_mapping/results/
   ```

3. Record RMSE and coverage in `analysis.md`
