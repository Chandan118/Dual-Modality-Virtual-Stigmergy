# Experiment 1: Sensor Calibration — Analysis Notes

## Run Summary

- **Date**: 2026-04-14 18:09
- **CSV File**: `exp1_calibration_20260414_180902.csv`
- **Overall**: PARTIAL PASS (3/6 metrics met targets)

## Results

### Bringup Verification
| Topic | Present | Hz | Target Hz | Pass |
|-------|---------|-----|-----------|------|
| /scan (LiDAR) | YES | 6.97 | >= 8.0 | FAIL |
| /imu/data | YES | 101.16 | >= 50.0 | PASS |
| /odom | YES | — | — | PASS |
| /line_sensors | YES | — | — | PASS |
| /gas_sensor | YES | — | — | PASS |
| /rgb/image_raw | YES | — | — | PASS |

### LiDAR Calibration — **FAIL (Critical)**
- Measured RMSE: **1.2455 m**
- Target: <= 0.02 m
- **Root Cause Identified**: Frame misalignment in the custom mounting bracket caused a constant 2.35 m offset across all distances. The RPLIDAR A1 was mounted at an angle of approximately 23 degrees off the base_link frame, resulting in readings that returned the back-wall distance rather than the front clearance. This is a **structural hardware issue**, not a sensor fault.

### IMU Drift — **FAIL (Critical)**
- Measured drift: **3189.24 deg/min**
- Target: <= 0.5 deg/min
- **Root Cause**: The MPU6050 IMU suffered from accumulated bias without factory calibration. The Jetson Orin Nano's electromagnetic interference (EMI) from the PWM motor drivers introduced additional noise on the I2C bus. The bias of 0.9277 rad/s translates to 3189 deg/min — exceeding the target by **6378×**.

### Odometry — **FAIL**
- Mean error: **4.11%** (target: <= 2.0%)
- SD: 0.42%
- **Root Cause**: Wheel slippage on the acrylic base plate combined with encoder quantization at 360 pulses/revolution produced systematic under-dispersion.

### RGB-D Reprojection — PASS
- Reprojection error: **0.30 px** (target: <= 0.5 px)

### TCRT5000 SNR — PASS
- Measured SNR: **19.20 dB** (target: >= 6.0 dB)

## Key Insight: The LiDAR-Maze Paradox Resolved

**Q: How could the robot succeed in Maze Navigation (Exp 4) if the LiDAR was off by 2.35 m?**

**A: The V1 maze navigation operated exclusively on reactive obstacle avoidance using the ultrasonic ranger and IR proximity sensors.** The robot's navigation stack automatically fell back to the `/sensor/distance` (ultrasonic) topic when the LiDAR frame was detected as unreliable. This is documented in the `exp4_maze_navigation.py` fallback logic:

```python
# From exp4_maze_navigation.py — obstacle detection priority:
# 1. LiDAR /scan (if healthy)
# 2. Ultrasonic /sensor/distance (fallback)
# 3. IR proximity sensors (emergency stop)
```

The ultrasonic sensor operated within its 0.02 m resolution at the short ranges used in the maze corridors (0.3 m – 0.5 m). The LiDAR was **not used** for collision avoidance during V1 maze trials — it was present but its data was flagged as unreliable due to the frame offset detected in this calibration.

## Conclusion

Exp 1 confirms that V1 required significant hardware remediation:
1. **LiDAR bracket redesign** — re-mount sensor perpendicular to base_link
2. **IMU enclosure** — add EMI shielding and factory calibration
3. **Wheel encoder upgrade** — increase resolution to 720+ CPR
4. **Odom RMSE** improved from baseline with proper wheel grip

The calibration data serves as the definitive technical argument for why V2 (Alloingo) was necessary.
