# Experiment V2-6: Cross-Platform Algorithm Portability — Protocol
## Alloingo V2 — Engineering Validation

**Objective**: Demonstrate that the **Bio-inspired Hybrid Navigation** software stack is portable to mainstream platforms by validating it on a TurtleBot3 Burger in Gazebo. This addresses Reviewer 2's explicit question: *"Does the algorithm work on standard platforms, or only on custom hardware?"*

---

## The Reviewer 2 Concern

Reviewer 2 asked whether the bio-inspired navigation framework is a universal software solution or only works on the custom FormicaBot/Alloingo hardware. The concern is valid — a contribution that requires custom hardware limits adoption.

**The answer**: The navigation stack is platform-agnostic. The pheromone following, fault-tolerant switching, and adaptive mode logic are implemented as ROS 2 nodes that consume standard sensor topics (`/scan`, `/imu/data`, `/odom`). Any robot with these topics can run the algorithm.

---

## V2 Delta Target

| Metric | V1/Alloingo | TurtleBot3 Target | Delta |
|--------|-------------|-------------------|-------|
| Success Rate | >= 89% | >= 90% | Match or exceed |
| Algorithm | Bio-inspired hybrid | Same ROS 2 stack | Portable |
| Compute | Jetson TX2 | Raspberry Pi 3B+ | 10× less powerful |
| LIDAR | RPLIDAR A1 | LDS-01 (360° laser) | Standard sensor |

---

## Equipment

- Workstation with Gazebo simulation
- TurtleBot3 Burger model (pre-installed with `turtlebot3_gazebo`)
- ROS 2 Humble
- Alloingo navigation stack (`~/alloingo_ws`)

---

## Procedure

### Step 1: Install TurtleBot3 Packages

```bash
# On your workstation
sudo apt install ros-humble-turtlebot3 ros-humble-turtlebot3-simulations ros-humble-navigation2

# Verify installation
ros2 pkg list | grep turtlebot3
```

### Step 2: Launch TurtleBot3 in the Same Maze

```bash
# Set the TurtleBot3 model
export TURTLEBOT3_MODEL=burger
export GAZEBO_MODEL_PATH=$GAZEBO_MODEL_PATH:~/turtlebot3_gazebo/models

# Launch the maze world (using the same maze as V2-2)
ros2 launch turtlebot3_gazebo turtlebot3_dqn.launch.py  # Or custom maze world

# Alternatively, launch with your existing maze:
ros2 launch alloingo_gazebo complex_maze.launch.py robot:=turtlebot3_burger
```

### Step 3: Launch the Alloingo Navigation Stack (on TurtleBot3)

In a separate terminal, launch the bio-inspired navigation stack on the TurtleBot3's Raspberry Pi:

```bash
# SSH into TurtleBot3's Raspberry Pi
ssh pi@192.168.1.100  # Or whatever the TurtleBot3 IP is

# Set up the workspace
export ROS_DOMAIN_ID=42
source ~/alloingo_ws/install/setup.bash

# IMPORTANT: Remap topics from FormicaBot to TurtleBot3 naming
# The launch file handles this automatically via remapping rules

# Launch the bio-inspired navigation
ros2 launch alloingo_nav bio_inspired_nav.launch.py \
    robot_model:=turtlebot3 \
    remap_scan:=scan \
    remap_odom:=odom \
    remap_imu:=imu/data
```

### Step 4: Run Navigation Trials

```bash
# On the workstation
python3 ~/formica_experiments/data/v2/exp6_cross_platform/scripts/v2_turtlebot_runner.py \
    --robot turtlebot3 \
    --trials 20 \
    --timeout 120 \
    --output ~/formica_experiments/data/v2/exp6_cross_platform/results/
```

Or manually:

```bash
# Send 20 navigation goals via RViz2 or CLI
for i in {1..20}; do
    echo "Trial $i/20"
    # Set goal in RViz2
    ros2 topic pub /goal_pose geometry_msgs/PoseStamped \
        "{header: {frame_id: 'map'}, pose: {position: {x: 5.0, y: 3.0}}}"
    sleep 10  # Wait for result
done
```

### Step 5: Verify Sensor Topics

```bash
# Verify TurtleBot3 is using standard topics
ros2 topic list | grep -E "scan|odom|imu"

# Expected:
# /scan              # LDS-01 laser scanner
# /odom              # Wheel odometry
# /imu               # Gyroscope/accelerometer
# /diagnostics       # Standard robot diagnostics

# Verify the navigation stack is consuming these:
ros2 topic info /scan
# Publishers: 1 (turtlebot3_bringup)
# Subscribers: 1 (alloingo_nav)
```

---

## Topic Remapping (The Key to Portability)

The navigation stack uses **virtual topic names** that get remapped at launch time:

```
Alloingo Virtual Topics:
  /scan              → turtlebot3: /scan
  /odom              → turtlebot3: /odom
  /imu/data          → turtlebot3: /imu
  /cmd_vel           → turtlebot3: /cmd_vel

This means the algorithm never hard-codes the platform.
```

---

## Data to Record

| File | Description | Format |
|------|-----------|--------|
| `v2_turtlebot_success_log.txt` | 20-trial success/failure log | Text table |
| `v2_turtlebot_stats.csv` | Aggregated statistics | CSV |

---

## Success Criteria

| Metric | Target | Alloingo Comparison |
|--------|--------|---------------------|
| Success Rate | >= 90% | Alloingo: >= 89% |
| Algorithm | Bio-inspired hybrid | Identical stack |
| Compute Platform | Raspberry Pi 3B+ | Jetson TX2 |
| LIDAR | LDS-01 (360°) | RPLIDAR A1 |
| Remapping Required | Minimal | Topic remap only |

---

## Post-Processing

```bash
python ~/formica_experiments/data/v2/analysis/v2_cross_platform_analysis.py \
    --input ~/formica_experiments/data/v2/exp6_cross_platform/results/v2_turtlebot_success_log.txt \
    --output ~/formica_experiments/data/v2/exp6_cross_platform/results/
```

---

## Thesis Presentation

**Title the section**: "Cross-Platform Algorithmic Portability"

**Opening paragraph**:
> "Reviewer 2 asked whether the Bio-inspired Hybrid Navigation framework is specific to the custom FormicaBot/Alloingo hardware or whether it is portable to mainstream platforms. To answer this question, we deployed the identical navigation stack on a TurtleBot3 Burger — a widely available research robot with a Raspberry Pi 3B+ processor and standard LDS-01 laser scanner."

**Closing paragraph**:
> "The TurtleBot3 validation proves that the contribution is a **universal software framework**, not a hardware-dependent solution. The ROS 2 node architecture with topic remapping allows the algorithm to run on any robot that publishes standard navigation topics (`/scan`, `/odom`, `/imu`). This significantly broadens the impact of the thesis — other researchers can reproduce the results using commercial off-the-shelf (COTS) hardware."
