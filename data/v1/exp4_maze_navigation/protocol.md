# Experiment 4: Maze Navigation — Protocol

## Objective

Validate Nav2 autonomous navigation through a physical maze. Target: ≥ 89% success rate across 20 trials.

## Prerequisites

```bash
# 1. Bringup and navigation stack
ros2 launch formica_experiments bringup_launch.py
ros2 launch formica_experiments nav_stack_launch.py

# 2. Run the maze experiment
ros2 run formica_experiments exp4_maze

# Or with mock mode (no Nav2 required)
ros2 run formica_experiments exp4_maze --ros-args -p mock_nav:=true
```

## Maze Configuration (Remediation Summary Applied)

| Parameter | Old Value | New Value | Rationale |
|-----------|-----------|-----------|-----------|
| inflation_radius | 0.24 m | 0.15 m | Fit through corridors |
| cost_scaling_factor | 2.8 | 1.8 | Tighter path following |

Edit `config/nav2_params.yaml` before running:

```yaml
controller_server:
  ros__parameters:
    inflation_radius: 0.15
    cost_scaling_factor: 1.8
```

## Positions

| Position | Coordinates (m) |
|----------|----------------|
| Start | (0.0, 0.0) |
| Target | (2.525, 3.035) |

Euclidean distance: ~3.91 m

## Trial Parameters

| Parameter | Value |
|-----------|-------|
| Number of trials | 20 |
| Trial timeout | 420 s |
| Max allowed path | Euclidean × 1.5 ≈ 5.87 m |
| AMCL jump rejection | 0.55 m |

## Data Output

```
exp4_maze_<timestamp>.csv           # Per-trial results
```

## CSV Columns

| Column | Description |
|--------|-------------|
| trial | Trial number |
| outcome | SUCCESS / FAIL |
| path_length_m | Actual path length (m) |
| time_to_target_s | Navigation time (s) |
| replan_events | Number of Nav2 replans |
| failure_mode | none / path_too_long / timeout / obstacle_abort |
| efficiency_pct | Running success rate (%) |

## Failure Modes

| Code | Description |
|------|-------------|
| none | Trial passed |
| path_too_long | Path exceeded 5.87 m |
| timeout | Exceeded 420 s |
| obstacle_abort | LiDAR/ultrasonic emergency stop |
| goal_rejected | Nav2 rejected goal |

## Obstacle Safety Parameters

| Parameter | Value |
|-----------|-------|
| Obstacle stop distance | 0.52 m (LiDAR) / 48 cm (ultrasonic) |
| Obstacle critical distance | 0.28 m |
| Obstacle abort grace | 2.5 s |
| Speed limit at 1.2 m | 0.20 × scale m/s |

## Expected Results

With remediation (inflation_radius=0.15, cost_scaling=1.8):
- Expected success rate: > 89%
- Mean path efficiency: within 1.5× Euclidean

## After Running

1. Copy results to v1:
   ```bash
   cp ~/formica_experiments/data/exp4_maze_<timestamp>.csv \
      ~/formica_experiments/data/v1/exp4_maze_navigation/results/
   ```

2. Record success rate and mean path length in `analysis.md`
