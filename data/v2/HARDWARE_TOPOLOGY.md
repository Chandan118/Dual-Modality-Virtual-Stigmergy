# Alloingo V2 — Hardware Topology

**Platform**: Alloingo (FormicaBot V2)
**Date**: 2026-04-15
**Status**: Hardware Optimization Complete; V2 Experiments in Progress

---

## System Architecture Overview

The Alloingo V2 platform is a tri-mode robot composed of three interconnected computing boards connected via a gigabit Ethernet switch (192.168.123.254). Power management is centralized through a custom power distribution board (PDB) that implements per-subsystem hardware gating.

```
                         ┌─────────────────────────────────────┐
                         │      GIGABIT ETHERNET SWITCH        │
                         │       (192.168.123.254 / 24)         │
                         └──────────┬───────────┬──────────────┘
                                    │           │
                         ┌──────────┴───┐  ┌───┴──────────┐
                         │              │  │              │
                  ┌──────▼──────┐ ┌─────▼──┐ ┌──▼─────────┐
                  │  Sensing     │ │ Motion  │ │ MCU (Main) │
                  │  Motherboard │ │ Control │ │ Control    │
                  │             │ │Motherboard│ │ Board      │
                  │ Jetson TX2   │ │Mini PC   │ │            │
                  │(192.168.123)│ │(192.168) │ │(192.168)   │
                  │              │ │.123.220  │ │.123.10     │
                  └──────┬──────┘ └─────┬───┘ └──────┬──────┘
                         │              │             │
                         └──────────────┼─────────────┘
                                        │
                         ┌──────────────▼──────────────┐
                         │    POWER DISTRIBUTION BOARD   │
                         │  (Hardware-level gating per  │
                         │   subsystem)                │
                         └──────────────┬──────────────┘
                                        │
                              ┌─────────┴──────────┐
                              │  Li-Po Battery      │
                              │  11.1V / 5000mAh    │
                              └─────────────────────┘
```

---

## Board Specifications

### 1. MCU Main Control Board
- **IP Address**: 192.168.123.10
- **Login**: Not accessible via SSH (firmware-locked)
- **Role**: Top-level state machine, mission coordination, emergency stop logic
- **Communication**: Publishes `/system/mode` (TRANSIT / DECISION / STANDBY) on ROS topic
- **Protocol**: REST API on port 8080 for mode switching

### 2. Motion Control Motherboard
- **IP Address**: 192.168.123.220
- **Username**: `unitree`
- **Password**: `123`
- **Hostname**: `alloingo-motion`
- **Role**: Motor driver control, wheel encoder feedback, low-level odometry
- **ROS Node**: `/motion_controller` — subscribes to `/cmd_vel`, publishes `/odom`
- **Connection**: Wired gigabit to central switch

### 3. Sensing Motherboard (Primary Compute)
- **IP Address**: 192.168.123.12
- **Username**: `unitree`
- **Password**: `123`
- **Hostname**: `alloingo-sensing`
- **Role**: All high-level compute — SLAM, CNN, navigation, pheromone tracking
- **OS**: Ubuntu 20.04 / JetPack 5.x
- **ROS 2**: Humble (Foxy on V1)
- **Connection**: Wired gigabit to central switch; primary experiment node

---

## Power Architecture (V2 vs. V1)

### V1 (FormicaBot) — Always-ON Bus
```
Battery → INA219 (measurement only) → Always-ON bus
  ├── Jetson (~3.5W) ← always on
  ├── RPLIDAR (~2.5W) ← always on
  ├── Kinect (~0.5W) ← always on (even STANDBY)
  └── Arduino (~0.5W)
→ 6.0 W constant → 450 mV sag on 5V rail
```

### V2 (Alloingo) — Hardware-Gated Per-Subsystem
```
Battery → Power Distribution Board (PDB)
  ├── Gated Rail 1: Jetson TX2 (mode-controlled)
  │      └── ON: TRANSIT + DECISION | OFF: STANDBY
  ├── Gated Rail 2: RPLIDAR A1
  │      └── ON: TRANSIT only | OFF: DECISION + STANDBY
  ├── Gated Rail 3: Azure Kinect DK
  │      └── ON: DECISION only | OFF: TRANSIT + STANDBY
  ├── Gated Rail 4: Motor driver
  │      └── ON: Always when moving | OFF: Stationary
  └── Always-ON: IMU (MPU6050) + Arduino + MCU (~0.3W)
→ <= 1.2 W average; < 50 mV sag on 5V rail
```

### Mode-Based Power States

| Mode | Components Active | Expected Power |
|------|-----------------|---------------|
| TRANSIT | Jetson TX2 + RPLIDAR + IMU + Motors | ~4.0 W |
| DECISION | Jetson TX2 + Kinect + IMU + Motors | ~3.5 W |
| STANDBY | IMU + MCU only | ~0.8 W |
| **Average** | | **<= 1.2 W** |

---

## Sensor Suite (V2)

| Sensor | Model | Topic | Rate | Role |
|--------|-------|-------|------|------|
| LiDAR | RPLIDAR A1 | `/scan` | 8 Hz | Primary obstacle detection |
| IMU | MPU6050 | `/imu/data` | 100 Hz | Orientation + dead-reckoning |
| Camera | Azure Kinect DK | `/rgb/image_raw` | 30 FPS | CNN object detection |
| Depth | Azure Kinect DK | `/depth/image_raw` | 30 FPS | 3D obstacle mapping |
| Line | 4× TCRT5000 | `/line_sensors` | 20 Hz | Pheromone trail following |
| Gas | MQ-135 | `/gas_sensor` | 1 Hz | Chemical backup sensing |
| Ultrasonic | HC-SR04 | `/sensor/distance` | 40 kHz | Short-range fallback |
| Odometry | 720 CPR encoders | `/odom` | 100 Hz | Wheel odometry |

---

## Network Topology for Experiments

```
┌─────────────────────────────────────────────────────────────────┐
│                  EXPERIMENT WORKSTATION                          │
│           (you — e.g., 192.168.123.100)                        │
└────────────────────────┬────────────────────────────────────────┘
                         │ SSH / ROS 2
                         │
             ┌───────────┴───────────┐
             │   GIGABIT SWITCH     │
             │ 192.168.123.254/24   │
             └───────────┬───────────┘
                         │
     ┌───────────────────┼───────────────────────┐
     │                   │                       │
┌────▼────┐       ┌──────▼──────┐       ┌───────▼─────┐
│ Jetson  │       │  Mini PC    │       │  MCU Board  │
│ TX2     │◄─────►│ (Motion)   │◄─────►│ (Control)   │
│ Sensing │ ROS 2 │ 192.168.    │ Serial│ 192.168.    │
│192.168.│ pub/   │ 123.220     │ RS485 │ 123.10      │
│ 123.12 │ sub    │ unitree/123 │       │ (firmware)  │
└─────────┘       └─────────────┘       └─────────────┘
```

---

## SSH Access Commands

```bash
# Sensing motherboard (primary — run experiments here)
ssh unitree@192.168.123.12
# Password: 123

# Motion control motherboard
ssh unitree@192.168.123.220
# Password: 123

# From Mini PC to Sensing board (for motion experiments)
ssh unitree@192.168.123.12

# Check network connectivity
ping 192.168.123.12   # TX2
ping 192.168.123.220  # Mini PC
ping 192.168.123.10   # MCU (may not respond to ping)
```

---

## Key ROS 2 Topics for V2 Experiments

```bash
# On the TX2 (192.168.123.12)
export ROS_DOMAIN_ID=42

# Core navigation
/scan                    # LiDAR scan (RPLIDAR A1, 8 Hz)
/imu/data                # IMU orientation (MPU6050, 100 Hz)
/odom                    # Wheel odometry (720 CPR, 100 Hz)
/cmd_vel                 # Velocity commands

# Bio-inspired
/line_sensors            # 4× TCRT5000 pheromone sensors (20 Hz)
/gas_sensor              # MQ-135 chemical sensor (1 Hz)
/sensor/distance         # HC-SR04 ultrasonic (40 kHz)
/pheromone/following     # Pheromone trail following state

# CNN & Detection
/rgb/image_raw           # Azure Kinect RGB (30 FPS)
/depth/image_raw         # Azure Kinect Depth
/detections              # CNN detection bounding boxes

# System state
/system/mode              # TRANSIT / DECISION / STANDBY
/system/power            # Power draw in W (from PDB)
/system/thermal          # CPU/GPU temperature (°C)

# Fault tolerance
/fault/status            # Sensor health flags
/fault/recovery_time     # Time since last switch
/mode_switch/duration    # Time to switch modes
```

---

## Power Management PDB Commands

The Power Distribution Board exposes ROS parameters for hardware-level gating:

```bash
# Check current power state
ros2 param get /power_manager rail_Jetson
ros2 param get /power_manager rail_RPLIDAR
ros2 param get /power_manager rail_Kinect

# Manually switch mode
ros2 service call /system/set_mode alloingo_msgs/srv/SetMode "{mode: 'STANDBY'}"

# Read real-time power (requires INA3221 on PDB)
ros2 topic echo /system/power --once
```

---

## Experiment Start-Up Sequence

```bash
# STEP 1: Connect to the TX2 (Sensing Motherboard)
ssh unitree@192.168.123.12

# STEP 2: Set Jetson to 10W power limit (NVPMODE)
sudo nvpmodel -m 1   # 10W mode (recommended for V2)
# Or for minimum power: sudo nvpmodel -m 2  # 5W mode

# STEP 3: Start the ROS 2 daemon
export ROS_DOMAIN_ID=42
source /opt/ros/humble/setup.bash
source ~/alloingo_ws/install/setup.bash

# STEP 4: Launch the bio_inspired_nav stack
ros2 launch alloingo_bringup bio_inspired_nav.launch.py

# STEP 5: Verify all topics are publishing
ros2 topic hz /scan /imu/data /odom /line_sensors /system/power

# STEP 6: Run experiments (see each experiment protocol)
```
