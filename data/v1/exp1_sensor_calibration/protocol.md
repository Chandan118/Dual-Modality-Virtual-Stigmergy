# Experiment 1: Sensor Calibration — Protocol

## Objective

Validate all FormicaBot sensors meet thesis-specified targets before conducting field experiments.

## Required Hardware

| Sensor | Topic | Interface | Ground Truth |
|--------|-------|-----------|--------------|
| RPLIDAR A1M8 | `/scan` | /dev/ttyUSB* | Tape measure |
| MPU6050 IMU | `/imu/data` | I2C | Stationary hold |
| Wheel encoders | `/odom` | Arduino | Tape mark |
| Arduino line sensors | `/line_sensors` | USB | — |
| Arduino gas sensor | `/gas_sensor` | USB | — |
| Azure Kinect RGB-D | `/rgb/image_raw` | USB | Checkerboard |

## Prerequisites

```bash
# 1. Bringup the robot
ros2 launch formica_experiments bringup_launch.py

# 2. Verify all topics are publishing
ros2 topic list | grep -E 'scan|imu|odom|line|gas|image'

# 3. Run hardware check
./scripts/chapter6_experiment_runner.sh check

# 4. Start the calibration node
ros2 run formica_experiments exp1_calibration
```

## Thresholds (Remediation Summary Applied)

| Metric | Target | Pass Criterion |
|--------|--------|---------------|
| LiDAR RMSE | ≤ 0.02 m | RMSE across all distances |
| IMU drift | ≤ 0.5 deg/min | 1000-sample bias at rest |
| Odom mean error | ≤ 2.0% | 10-trial mean |
| Odom SD | Report only | — |
| RGB-D reprojection | ≤ 0.5 px | camera_calibrator output |
| TCRT5000 SNR | ≥ 6.0 dB | LED strip signal-to-noise |

## Task Sequence

### Task 1: Bringup Verification
- Node verifies all required topics are present
- Topic frequency check: /scan ≥ 8 Hz, /imu/data ≥ 50 Hz
- Logs warn if topics are missing

### Task 2: LiDAR Calibration
- Place robot at exact distances: 0.50 m, 1.00 m, 1.50 m, 2.00 m from wall
- Collect 15 readings at each distance
- Compute RMSE across all trials
- **Use tape measure for ground truth**

### Task 3: IMU Drift Calibration
- Keep robot stationary on flat surface
- Collect 1000 samples
- Compute angular velocity bias and drift in deg/min

### Task 4: Odometry Calibration
- 10 trials: drive robot exactly 2.00 m forward
- Measure with tape measure, compare to /odom
- Compute mean error % and SD

### Task 5: RGB-D Reprojection
- Run `ros2 run camera_calibration cameracalibrator`
- Capture ≥ 30 checkerboard poses
- Enter reprojection error from calibrator output

### Task 6: TCRT5000 SNR Calibration
- Turn OFF ambient LED strip → capture noise
- Turn ON LED strip → measure signal at 5, 10, 15 cm
- Compute SNR in dB

## Data Output

```
exp1_calibration_<timestamp>.csv     # Raw measurements
exp1_table6_1_<timestamp>.csv       # Table 6.1 consolidated results
```

## Table 6.1 Format

| metric | value | unit | target | pass |
|--------|-------|------|--------|------|
| LiDAR RMSE | ... | m | <= 0.02 | True/False |
| IMU drift | ... | deg/min | <= 0.5 | True/False |
| Odom mean error | ... | % | <= 2.0 | True/False |
| Odom SD | ... | % | report only | True |
| RGB-D reprojection | ... | px | <= 0.5 | True/False |
| TCRT5000 SNR | ... | dB | >= 6.0 | True/False |

## Remediation Notes

- tf2 latency monitoring added between odom→base_link
- Physical tape measure required for ground truth comparison
- Proper RMSE calculation across all trials
- Table 6.1 now includes tf2_latency, odom_rmse_m, odom_mean_abs_error_m

## After Running

1. Copy results to v1:
   ```bash
   cp ~/formica_experiments/data/exp1_calibration_<timestamp>.csv \
      ~/formica_experiments/data/v1/exp1_sensor_calibration/results/
   cp ~/formica_experiments/data/exp1_table6_1_<timestamp>.csv \
      ~/formica_experiments/data/v1/exp1_sensor_calibration/results/table6_1_<timestamp>.csv
   ```

2. Record observations in `analysis.md`
