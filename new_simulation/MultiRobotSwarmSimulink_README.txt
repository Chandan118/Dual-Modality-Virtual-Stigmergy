============================================================
MULTI-ROBOT SWARM SIMULINK MODEL
============================================================

Model Name: MultiRobotSwarmSimulink
Number of Robots: 5 (expandable to 20)
Arena Size: 8m x 8m
Simulation Time: 60 seconds

MODEL STRUCTURE:
----------------

1. ARENA SETUP
   - Arena_Width: 8.0 m
   - Arena_Height: 8.0 m

2. ROBOT SUBSYSTEMS
   - Robot_1: Wheeled robot with TCRT5000 sensors
   - Robot_2: Wheeled robot with TCRT5000 sensors
   - Robot_3: Wheeled robot with TCRT5000 sensors
   - Robot_4: Wheeled robot with TCRT5000 sensors
   - Robot_5: Wheeled robot with TCRT5000 sensors
   ... (expandable to Robot_20)

3. PHEROMONE GRID
   - Grid resolution: 0.05 m
   - Decay rate: 0.02 per second
   - Max intensity: 255

4. SWARM CONTROLLER
   - Multi-robot coordination
   - Task allocation
   - Collision avoidance

TO EXPAND MODEL:
----------------
1. Open MultiRobotSwarmSimulink.slx in Simulink
2. Right-click on Robot_1
3. Select Duplicate
4. Rename to Robot_2, Robot_3, etc.
5. Adjust initial positions
6. Connect to Swarm_Controller
7. Update Scope inputs
