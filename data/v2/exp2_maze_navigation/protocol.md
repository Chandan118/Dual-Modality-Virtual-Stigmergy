# Experiment V2-2: Optimized Maze Navigation — Protocol
## Alloingo V2 — Engineering Validation

**Objective**: Prove that V2 (Alloingo), combined with optimized Nav2 parameters (`inflation_radius=0.15m`, `cost_scaling_factor=1.8`), achieves >89% success rate in the Complex Maze environment — validating the V1→V2 improvement in tight-space navigation.

---

## V1 vs. V2 Navigation Context

In V1, the maze succeeded via **reactive-only** navigation (ultrasonic + IR sensors) in a known environment. The reviewer correctly noted that LiDAR-based SLAM was never validated in V1 because the LiDAR frame was misaligned.

**V2's claim**: The Alloingo platform, with calibrated LiDAR, full SLAM (AMCL), and optimized Nav2 parameters, achieves >= 89% success in an unmapped complex maze.

---

## V2 Delta Target

| Metric | V1 (Baseline) | V2 Target | Delta |
|--------|-------------|-----------|-------|
| Success Rate | ~100% (reactive, known) | >= 89% (SLAM, unmapped) | Validated SLAM capability |
| Primary Sensor | Ultrasonic + IR | LiDAR + SLAM | Full navigation stack |
| Localization | Pre-programmed waypoints | AMCL on occupancy grid | Re-localizable |
| inflation_radius | N/A (V1 failed) | 0.15 m | Optimized for tight corridors |
| cost_scaling_factor | N/A (V1 failed) | 1.8 | Tuned for maze geometry |

---

## Equipment

- Alloingo V2 platform
- Complex Maze environment (see `environments/complex_maze.yaml` for geometry)
- V2 nav2_params.yaml with tuned parameters
- Motion capture system (optional, for ground truth)
- Ethernet network (192.168.123.x / 24)

---

## Nav2 Parameter Changes (V1 → V2)

Edit `nav2_params.yaml` on the TX2:

```yaml
# /path/to/alloingo_nav/config/nav2_params.yaml

# --- Obstacle Avoidance (Key change for tight corridors) ---
# V1: inflation_radius was not tunable (SLAM never ran)
# V2: Tuned for 0.8m corridor width

local_costmap:
  obstacle_layer:
    inflation_layer:
      inflation_radius: 0.15        # V2: 0.15 m (was: N/A)
      cost_scaling_factor: 1.8      # V2: 1.8 (was: N/A)

global_costmap:
  obstacle_layer:
    inflation_layer:
      inflation_radius: 0.15        # V2: 0.15 m
      cost_scaling_factor: 1.8      # V2: 1.8

# --- Recovery Behaviors ---
recovery_behaviors:
  - action: spin
    params:
      simulation_duration: 1.0     # seconds
      simulation_angle_max: 1.57    # 90 degrees
  - action: backup
    params:
      max_rotating_vel: 1.0
      min_rotating_vel: 0.5
```

To apply changes:

```bash
ssh unitree@192.168.123.12
# Edit the nav2_params.yaml
nano ~/alloingo_ws/src/alloingo_nav/config/nav2_params.yaml
# Restart the nav stack
ros2 launch alloingo_nav bringout.launch.py
```

---

## Procedure

### Step 1: Environment Setup

```bash
# On the TX2 (192.168.123.12)
ssh unitree@192.168.123.12

# Source the workspace
export ROS_DOMAIN_ID=42
source ~/alloingo_ws/install/setup.bash

# Launch SLAM (gmapping or slam_toolbox)
ros2 launch alloingo_nav slam.launch.py

# Wait for map to initialize (15-30 s)
ros2 topic hz /map
```

### Step 2: Map the Maze (First Run Only)

```bash
# Teleop to map the entire maze
ros2 run teleop_twist_keyboard teleop_twist_keyboard

# Drive through all corridors at 0.1 m/s
# Map should be visible in rviz

# Save the map
ros2 run nav2_map_server map_saver_cli -f ~/maps/complex_maze_v2
```

### Step 3: Set Initial Pose (AMCL)

```bash
# In RViz2, use "2D Pose Estimate" to set the robot's location on the map
# Or via CLI:
ros2 topic pub /initialpose geometry_msgs/PoseWithCovarianceStamped \
  "{header: {stamp: {sec: 0}, frame_id: 'map'}, \
   pose: {pose: {position: {x: 1.0, y: 2.0, z: 0.0}, \
               orientation: {x: 0.0, y: 0.0, z: 0.0, w: 1.0}}}}"
```

### Step 4: Run Navigation Trials

```bash
# Use the included maze runner script
python3 ~/formica_experiments/data/v2/exp2_maze_navigation/scripts/v2_maze_runner.py \
    --trials 20 \
    --timeout 120 \
    --output ~/formica_experiments/data/v2/exp2_maze_navigation/results/

# Or manually:
ros2 run nav2_navigation navigate_to_pose
# Set goal in RViz2 at the maze goal position
```

### Step 5: Record Each Trial

For each trial, record in `v2_maze_success_log.txt`:

| Trial | Start Time | Goal | Outcome | Collision | Timeout | Path Length | Recovery Actions |
|-------|-----------|------|---------|---------|---------|------------|-----------------|

---

## Data to Record

| File | Description | Format |
|------|-----------|--------|
| `v2_maze_success_log.txt` | 20-trial success/failure log | Text table |
| `v2_maze_<trial>.bag` | ROS 2 bag per trial | .db3 |
| `v2_maze_stats.csv` | Aggregated statistics | CSV |

---

## Success Criteria

- **>= 89% success rate** (19/20 trials)
- **Success definition**: Robot reaches goal without collision and without timeout
- **Timeout**: 120 seconds per trial
- **Collision detection**: Check `/scan` for very close readings (< 0.1 m)

---

## Post-Processing

```bash
python ~/formica_experiments/data/v2/analysis/v2_maze_analysis.py \
    --input ~/formica_experiments/data/v2/exp2_maze_navigation/results/v2_maze_success_log.txt \
    --output ~/formica_experiments/data/v2/exp2_maze_navigation/results/
```

---

## Failure Analysis

If success rate < 89%, record failure modes:

| Failure Mode | Cause | Fix |
|-------------|-------|-----|
| Collision | inflation_radius too small | Increase to 0.20 m |
| Timeout | path planner too slow | Reduce `planner_window_size` |
| Re-planning loop | local costmap stale | Increase `update_frequency` |
| Localization lost | AMCL diverged | Increase `transform_tolerance` |
