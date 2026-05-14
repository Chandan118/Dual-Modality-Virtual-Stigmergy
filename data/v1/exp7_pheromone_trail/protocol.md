# Experiment 7: Pheromone Trail — Protocol

## Objective

Validate physical TCRT5000 + MQ-135 sensor trail following against virtual baseline. Target: Sim-to-real gap < 15%.

## Required Hardware

- 4× TCRT5000 IR reflective sensors
- MQ-135 gas sensor (ethanol detection)
- 620 nm LED strip (pheromone simulation)
- Differential drive base with Arduino

## Prerequisites

```bash
# 1. Bringup the robot
ros2 launch formica_experiments bringup_launch.py

# 2. Run the pheromone experiment (physical sensors)
ros2 run formica_experiments exp7_pheromone

# Mock mode (for simulation testing only)
ros2 run formica_experiments exp7_pheromone --ros-args \
    -p mock_sensors:=true -p auto_run:=true
```

## Sub-Experiments

### Sub-A: Straight Trail Following

- 10 trials
- 3.0 m straight LED strip
- PID lateral deviation target: ≤ 1.5 cm

### Sub-B: Curved Trail Following

- 10 trials
- 4.0 m curved LED strip
- PID lateral deviation target: ≤ 2.0 cm

### Sub-C: SNR Switchover

- 10 trials
- Measure chemical switchover latency when SNR < 6 dB
- Gas sensor activates as backup

### Sub-D: LED PWM Decay

- Step LED intensity 100% → 10%
- Measure minimum detectable PWM
- Validates trail evaporation model

## PID Parameters

| Parameter | Value |
|-----------|-------|
| Kp | 0.6 |
| Ki | 0.02 |
| Kd | 0.10 |
| Linear speed | 0.10 m/s |
| Max angular | 1.0 rad/s |

## Thresholds

| Parameter | Value |
|-----------|-------|
| SNR threshold | 6.0 dB |
| Trail threshold ADC | 1500 |
| Chemical threshold ADC | 180 |
| Chemical baseline ADC | 120 |
| Gas saturated ADC | 950 |

## Data Output

```
exp7_pheromone_<timestamp>.csv      # Full sensor log
figure7_A_straight_*.png           # Sub-A lateral deviation
figure7_B_curved_*.png             # Sub-B lateral deviation
table7_C_snr_switchover_*.csv      # Sub-C switchover table
figure7_D_led_adc_*.png            # Sub-D LED decay curve
```

## CSV Columns

| Column | Description |
|--------|-------------|
| sub_exp | A_straight / B_curved / C_snr / D_decay |
| trial | Trial number |
| trail_type | straight / curved / switchover / decay |
| dist_m | Distance along trail (m) |
| lateral_dev_m | Lateral deviation (m) |
| modality | optical / chemical |
| snr_db | Signal-to-noise ratio (dB) |
| trail_lost_all_four | All sensors below threshold |
| elapsed_s | Elapsed time (s) |
| led_pwm | LED intensity (0-1) |
| s0, s1, s2, s3 | TCRT sensor ADC values |
| gas_adc | MQ-135 raw ADC |
| ambient_pct | Ambient light (0-100%) |
| switchover_latency_s | Time to activate chemical backup |
| continued_following_or_trail_any | Trail still detected |

## Sim-to-Real Gap Analysis

Compare hardware lateral deviation vs. simulated baseline:

```
gap = |hardware_mean - simulation_mean| / simulation_mean × 100%
```

Target: gap < 15%

## Remediation Notes (Applied)

- Disabled mock mode by default (now mock_sensors=False)
- Added raw ADC logging from physical TCRT5000 sensors
- Added Sim-to-Real Gap Analysis comparing hardware to virtual pheromone
- Expected gap < 15%

## Post-Processing

```bash
python ~/formica_experiments/formica_experiments/exp7_postprocess.py \
    ~/formica_experiments/data/exp7_pheromone_<timestamp>.csv
```

## After Running

1. Post-process for figures:
   ```bash
   python ~/formica_experiments/formica_experiments/exp7_postprocess.py \
       ~/formica_experiments/data/exp7_pheromone_<timestamp>.csv \
       --out-dir ~/formica_experiments/data/v1/exp7_pheromone_trail/results/
   ```

2. Calculate sim-to-real gap

3. Record mean lateral deviation and gap percentage in `analysis.md`
