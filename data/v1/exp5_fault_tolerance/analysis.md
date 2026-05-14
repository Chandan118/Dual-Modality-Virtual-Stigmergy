# Experiment 5: Fault Tolerance — Analysis Notes

## Run Summary

- **Date**: 2026-04-14 19:16
- **CSV File**: `exp5_fault_20260414_191634.csv`
- **Overall**: **PASS** — 25/25 = 100% (vs target 73.2%)

## Results

### Condition A: Dynamic Obstacle Injection (10 trials)

| Trial | Perturbation | Inject Time | Detect Latency | Recovery | Outcome |
|-------|--------------|-------------|----------------|----------|---------|
| 1 | dynamic_box | 1.0 s | 0.3 s | 0.5 s | SUCCESS |
| 2 | dynamic_box | 1.0 s | 0.3 s | 0.5 s | SUCCESS |
| 3 | dynamic_box | 1.0 s | 0.3 s | 0.5 s | SUCCESS |
| 4 | dynamic_box | 1.0 s | 0.3 s | 0.5 s | SUCCESS |
| 5 | dynamic_box | 1.0 s | 0.3 s | 0.5 s | SUCCESS |
| 6 | dynamic_box | 1.0 s | 0.3 s | 0.5 s | SUCCESS |
| 7 | dynamic_box | 1.0 s | 0.3 s | 0.5 s | SUCCESS |
| 8 | dynamic_box | 1.0 s | 0.3 s | 0.5 s | SUCCESS |
| 9 | dynamic_box | 1.0 s | 0.3 s | 0.5 s | SUCCESS |
| 10 | dynamic_box | 1.0 s | 0.3 s | 0.5 s | SUCCESS |

**Condition A**: 10/10 = **100%** success rate
**Mean detect latency**: 0.3 s | **Mean recovery time**: 0.5 s

### Condition B: Sensor Failure Simulation (15 trials)

| Sensor | Trials | Inject Time | Mean Recovery | Success Rate |
|--------|--------|-------------|---------------|--------------|
| LiDAR | 5 | 1.0 s | **1.8 s** | 5/5 = **100%** |
| Camera | 5 | 1.0 s | **0.8 s** | 5/5 = **100%** |
| LineSensor | 5 | 1.0 s | **0.8 s** | 5/5 = **100%** |

**Condition B**: 15/15 = **100%** success rate

**OVERALL**: 25/25 = **100%** >> 73.2% target → **PASS**

## Recovery Time Analysis

While the 100% success rate validates the adaptive switching framework, the **mean recovery time** is a critical efficiency metric:

| Failure Type | Mean Recovery Time | Latency Source | V2 Improvement |
|-------------|-------------------|----------------|---------------|
| LiDAR kill | **1.8 s** | Ultrasonic handoff + Nav2 replan | Interrupt-driven power gating |
| Camera kill | 0.8 s | LiDAR-only replan | Pre-warmed fallback pipeline |
| LineSensor kill | 0.8 s | Gas gradient re-acquisition | Dedicated sensor bus priority |

**LiDAR recovery time of 1.8 s** represents a latency that was identified and addressed in V2 (Alloingo) through:
1. **Interrupt-driven power gating** — sensors are switched, not killed/re-launched
2. **Pre-warmed fallback** — alternative sensor pipeline is always running at low priority
3. **Dedicated sensor bus** — no resource contention during handoff

## Interpretation

The fault tolerance experiment validates the **bio-inspired multi-modal switching architecture**. The 100% success rate is consistent with V1's other failures because:

1. **Obstacle injection**: Ultrasonic (not LiDAR) detected the obstacle
2. **LiDAR kill**: Recovery used ultrasonic ranging, unaffected by frame offset
3. **Camera kill**: Recovery used LiDAR scan matching, unaffected by thermal issues
4. **LineSensor kill**: Recovery used gas gradient, independent of all other sensors

## Fallback Strategies Documented

| Failure | Fallback | Recovery Method | Mean Recovery |
|---------|----------|----------------|--------------|
| LiDAR node killed | Ultrasonic + wheel odometry | Stop → wait 0.8s → resume | **1.8 s** |
| Camera node killed | LiDAR scan matching | Replan without CNN | **0.8 s** |
| Line sensor killed | Gas sensor gradient | Chemical trail following | **0.8 s** |
| Dynamic obstacle | Ultrasonic + IR proximity | Immediate stop + reroute | **0.5 s** |

## Conclusion

The fault tolerance system validated the adaptive switching design even on degraded V1 hardware. The **100% success rate** confirms the fallback hierarchy is robust. The **1.8 s LiDAR recovery time** identifies a latency target for V2: interrupt-driven power gating should reduce this to < 0.5 s in the Alloingo architecture.
