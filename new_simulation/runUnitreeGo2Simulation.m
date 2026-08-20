%% Run Unitree Go2 Multi-Robot Simulation
% Run this script to execute the 20-robot simulation with Unitree Go2

clc;
close all;
addpath(genpath(pwd));

fprintf('\n');
fprintf('************************************************************\n');
fprintf('* UNITREE GO2 MULTI-ROBOT SWARM SIMULATION                 *\n');
fprintf('* 20 Quadruped Robots Performing Foraging Task            *\n');
fprintf('* Robot Model: Unitree Go2                                *\n');
fprintf('* Source: https://www.unitree.com/opensource               *\n');
fprintf('* Duration: 60 seconds                                   *\n');
fprintf('************************************************************\n');
fprintf('\n');

% Create and run simulation
sim = UnitreeGo2Simulation();
sim = sim.initializeRobots();
sim = sim.runSimulation();
sim = sim.saveResults();

fprintf('\n');
fprintf('Simulation complete!\n');
fprintf('Video saved as: unitree_go2_simulation.mp4\n');
fprintf('URDF saved as: unitree_go2.urdf\n');
fprintf('\n');
