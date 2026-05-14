# Experiment V2-1: Optimized Power Profiling — Protocol
## Alloingo V2 — Engineering Validation

**Objective**: Prove the V2 (Alloingo) power-management circuit achieves the <= 1.2 W average target, demonstrating an ~80% reduction from V1's 6.0 W baseline.

---

## Hypothesis

The hardware-level power gating implemented in V2's Power Distribution Board (PDB) reduces average power consumption to <= 1.2 W by selectively enabling only the subsystems required for each mission mode (TRANSIT / DECISION / STANDBY).

---

## V2 Delta Target

| Metric | V1 Baseline | V2 Target | Delta Required |
|--------|-------------|-----------|----------------|
| Mean Power | 6.0 W | <= 1.2 W | ~80% reduction |
| Voltage Sag | 450 mV | < 50 mV | 90% reduction |
| Mode Modulation | None | Yes (3 modes) | Validated |

---

## Equipment

- Alloingo V2 platform (Jetson TX2 on Sensing Motherboard)
- Mini PC on Motion Motherboard (192.168.123.220)
- INA3221 power monitor on PDB (via `/system/power` topic)
- Central gigabit switch (192.168.123.254)
- Workstation for data logging (192.168.123.100)
- `tegrastats` utility on TX2

---

## Procedure

### Step 1: System Preparation (TX2 — 192.168.123.12)

```bash
# Connect to the TX2
ssh unitree@192.168.123.12

# Set to 10W power limit (NVPMODE)
sudo nvpmodel -m 1

# Verify power mode
nvpmodel -q
# Expected: MAX 10W

# Set up ROS 2 environment
export ROS_DOMAIN_ID=42
source /opt/ros/humble/setup.bash
source ~/alloingo_ws/install/setup.bash

# Verify network connectivity to all boards
ping -c 2 192.168.123.220  # Mini PC
ping -c 2 192.168.123.10   # MCU (may not respond)
```

### Step 2: Launch the bio_inspired_nav Stack

```bash
# On TX2 (192.168.123.12)
ros2 launch alloingo_bringup bio_inspired_nav.launch.py
```

Verify all topics are active:

```bash
ros2 topic hz /system/power /system/mode /scan /imu/data /odom
```

Expected rates:
- `/system/power`: 1 Hz (INA3221 polling)
- `/system/mode`: Event-driven (mode changes only)
- `/scan`: 8 Hz
- `/imu/data`: 100 Hz
- `/odom`: 100 Hz

### Step 3: Start tegrastats Logging

In a separate terminal on the TX2:

```bash
# Log tegrastats every 1 second for 10 minutes
# Output format: RAM 4123/3200MB | CPU [100%][100%][99%][98%] | ILml |
# GR3d 0% | AO 41C | CPU 42C | GPU 41C | PMIC 100C | GPU 0/0
while true; do
    tegrastats --interval 1000 >> ~/v2_power_tegrastats.log &
    sleep 0.95
done

# Or use the included script (see scripts/ directory)
```

### Step 4: Run Foraging Mission (10 minutes)

```bash
# Trigger the foraging mission on the TX2
ros2 service call /mission/start alloingo_msgs/srv/StartMission '{mission: "foraging"}'

# Monitor mode transitions in real-time
ros2 topic echo /system/mode --once
ros2 topic echo /system/power --once
```

The foraging mission cycles through modes:
1. **TRANSIT** (15 s): Searching, full sensor suite active
2. **DECISION** (5 s): Target detected, CNN inference active
3. **STANDBY** (10 s): Idle, minimal power

### Step 5: Alternative — Manual Mode Cycling

If the full mission is not ready, cycle modes manually:

```bash
# Force TRANSIT mode
ros2 service call /system/set_mode alloingo_msgs/srv/SetMode '{mode: "TRANSIT"}'
# Log for 3 minutes

# Force DECISION mode
ros2 service call /system/set_mode alloingo_msgs/srv/SetMode '{mode: "DECISION"}'
# Log for 2 minutes

# Force STANDBY mode
ros2 service call /system/set_mode alloingo_msgs/srv/SetMode '{mode: "STANDBY"}'
# Log for 3 minutes

# Repeat cycling 2 more times
```

### Step 6: Stop Logging

```bash
# Stop tegrastats
pkill -f tegrastats

# Copy the log file
scp unitree@192.168.123.12:~/v2_power_tegrastats.log ~/formica_experiments/data/v2/exp1_power_profiling/results/

# Also copy the ROS bag if available
scp -r unitree@192.168.123.12:~/v2_power_bag ~/formica_experiments/data/v2/exp1_power_profiling/results/
```

---

## Data to Record

| File | Description | Format |
|------|-----------|--------|
| `v2_power_<timestamp>.csv` | Power readings from PDB (INA3221) | CSV: timestamp, mode, voltage, current, power_W |
| `v2_power_tegrastats.log` | tegrastats output | Text log |
| `v2_power_bag/` | ROS 2 bag of all topics | .db3 |

---

## Analysis Parameters

- **Target**: Mean power <= 1.2 W
- **Collection period**: 10 minutes (~600 samples at 1 Hz)
- **Confidence level**: 95% CI on mean
- **Success criterion**: Lower bound of 95% CI < 1.2 W

---

## Post-Processing

```bash
python ~/formica_experiments/data/v2/analysis/v2_power_analysis.py \
    --input ~/formica_experiments/data/v2/exp1_power_profiling/results/v2_power_tegrastats.log \
    --output ~/formica_experiments/data/v2/exp1_power_profiling/results/
```

See `analysis/v2_power_analysis.py` for the full analysis pipeline.

---

## Safety Notes

- The Jetson TX2 must be in 10W mode (`nvpmodel -m 1`) for stable operation
- Monitor temperature via `tegrastats` — GPU should remain < 60°C with active cooling
- The PDB implements hardware overcurrent protection — if any rail exceeds 3A, it will auto-shutoff
