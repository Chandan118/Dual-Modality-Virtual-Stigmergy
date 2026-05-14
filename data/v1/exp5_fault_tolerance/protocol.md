# Experiment 5: Fault Tolerance — Protocol

## Objective

Evaluate navigation robustness under dynamic obstacle injection and sensor failure simulation. Target: ≥ 73.2% overall success rate.

## Prerequisites

```bash
# 1. Bringup and navigation stack
ros2 launch formica_experiments bringup_launch.py
ros2 launch formica_experiments nav_stack_launch.py

# 2. Run the fault tolerance experiment
ros2 run formica_experiments exp5_fault

# Or with mock mode
ros2 run formica_experiments exp5_fault --ros-args -p mock_nav:=true
```

## Two Conditions

### Condition A: Dynamic Obstacle Injection

- 10 trials
- Inject obstacle at 50% path distance
- Measure: detect latency, replan count, recovery time

### Condition B: Sensor Failure Simulation

- 3 sensor types × 5 trials each = 15 trials
- Kill sensor node mid-navigation at 50% path
- Measure: recovery time, alternative path success

## Sensor Nodes for Kill Testing

| Sensor | Node Name | Topic |
|--------|-----------|-------|
| LiDAR | rplidar_composition | /scan |
| Camera | azure_kinect_node | /rgb/image_raw |
| Line Sensor | line_sensor_node | /line_sensors |

## Positions

| Position | Coordinates (m) |
|----------|----------------|
| Start | (0.0, 0.0) |
| Target | (3.5, 2.5) |

Trial timeout: 120 s

## Data Output

```
exp5_fault_<timestamp>.csv           # All condition results
```

## CSV Columns

| Column | Description |
|--------|-------------|
| condition | A_obstacle / B_sensor |
| trial | Trial number |
| perturbation | dynamic_box / LiDAR / Camera / LineSensor |
| inject_time_s | Time when perturbation injected (s) |
| detect_latency_s | Time to detect (s) |
| replan_count | Nav2 replans triggered |
| outcome | SUCCESS / FAIL |
| recovery_time_s | Time to recover (s) |

## Fallback Strategies

| Sensor Failure | Fallback Strategy |
|----------------|-------------------|
| LiDAR | Ultrasonic + wheel odometry for obstacle detection |
| Camera | LiDAR-only navigation, reduced CNN confidence |
| Line Sensor | Gas sensor backup, dead reckoning |

## Alternative Sensor Path

| Primary Sensor | Alternative | Recovery Strategy |
|----------------|-------------|------------------|
| /scan | /sensor/distance (ultrasonic) | Stop-and-wait, then proceed |
| /rgb/image_raw | LiDAR path only | Replan without CNN |
| /line_sensors | /gas_sensor | Chemical gradient following |

## Remediation Notes (Applied)

- Added sensor drop simulation with manual node kill
- Added alternative_sensor_path column
- Added recovery_strategy column
- Records recovery time for each trial
- Documented fallback strategies per sensor type
- Updated target to 73.2% success rate

## After Running

1. Copy results to v1:
   ```bash
   cp ~/formica_experiments/data/exp5_fault_<timestamp>.csv \
      ~/formica_experiments/data/v1/exp5_fault_tolerance/results/
   ```

2. Calculate per-condition success rates:
   - Obstacle injection success rate
   - Per-sensor kill success rate
   - Overall weighted success rate

3. Record in `analysis.md`
