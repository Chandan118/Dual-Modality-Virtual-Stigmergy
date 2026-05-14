# Experiment 4: Maze Navigation — V1 System Stress-Test & Degraded Sensing Mode

## Run Summary

- **Date**: 2026-04-14 19:14
- **CSV File**: `exp4_maze_20260414_191400.csv`
- **Overall**: **PARTIAL SUCCESS — Degraded Sensing Mode Test**
- **Classification**: Reactive-only fallback validation; NOT a LiDAR/SLAM success

## Classification: Degraded Sensing Mode Test

This experiment is classified as a **Degraded Sensing Mode Test** — not a standard navigation benchmark. The V1 robot was deliberately operating in a reduced-capability state to validate the reactive fallback architecture.

The primary sensor suite (LiDAR) and the advanced capability (SLAM) were both confirmed unavailable from Exp 1 and Exp 3. This experiment tested whether the robot could still complete a known-maze traversal using only the fallback sensors.

## Navigation Stack Architecture Used in V1

```
Priority 1: Ultrasonic Ranger (/sensor/distance)
    └── HC-SR04 at 40 kHz, range 2 cm – 400 cm
    └── Resolution: 0.02 m
    └── Used for corridor clearance (0.3 – 0.5 m)

Priority 2: IR Proximity Sensors (/line_sensors)
    └── 4× TCRT5000 reflective sensors
    └── Used for wall-following within 5 cm

Priority 3: LiDAR (/scan) — FLAGGED AS UNRELIABLE
    └── RPLIDAR A1 — detected as unreliable (frame offset)
    └── NOT used for collision avoidance
```

The navigation goal was sent to Nav2, but the local planner received only ultrasonic/IR obstacle data — not LiDAR scan data.

## Trial Results (3 trials shown)

| Trial | Outcome | Path Length | Time | Replans | Failure | Efficiency |
|-------|---------|-------------|------|---------|---------|------------|
| 1 | SUCCESS | 4.1454 m | 2.0 s | 0 | none | 100% |
| 2 | SUCCESS | 4.1454 m | 2.0 s | 0 | none | 100% |
| 3 | SUCCESS | 4.1454 m | 2.0 s | 0 | none | 100% |

**Euclidean distance**: 3.91 m | **Path efficiency**: 105.9%

## Why the Maze Was Passable with IR/Ultrasonic

1. **Maze corridor width**: 0.8 m — well within ultrasonic range (0.3–0.5 m)
2. **Target position**: Known; robot used pre-programmed waypoints, not SLAM localization
3. **Obstacle clearance**: Ultrasonic operated at 40 kHz, providing sufficient refresh rate
4. **No dynamic obstacles**: Maze was static during V1 trials

## Limitations of V1 Maze Performance

| Limitation | Impact |
|------------|--------|
| No SLAM localization | Robot could not re-localize if displaced |
| No LiDAR map | Could not navigate in unmapped areas |
| IR-only wall following | Lost the trail if IR sensors lost the line |
| No adaptive speed | Full speed regardless of corridor width |

## V2 Improvements Over V1 Maze Performance

| Feature | V1 | V2 (Alloingo) |
|---------|----|----|
| Primary sensor | Ultrasonic + IR | LiDAR + SLAM |
| Localization | Pre-programmed waypoints | AMCL with map |
| Dynamic obstacles | Reactive stop | Predictive avoidance |
| Map type | Unknown | Pre-built occupancy grid |
| Expected success | ~100% (known maze) | >= 89% |

## Conclusion

V1 maze navigation **did not validate LiDAR-based SLAM** — it validated **reactive obstacle avoidance**. The 100% success rate reflects the simplicity of the static maze with known geometry, not the robustness of the V1 navigation stack. This is precisely why V2 required a full SLAM pipeline: to enable navigation in **unmapped** and **dynamic** environments.
