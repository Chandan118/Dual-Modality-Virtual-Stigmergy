%% Run Multi-Robot Simulation
% Run this script to execute the 20-robot swarm simulation

clc;
close all;
addpath(genpath(pwd));

fprintf('\n');
fprintf('************************************************************\n');
fprintf('* MULTI-ROBOT SWARM SIMULATION                             *\n');
fprintf('* 20 Wheeled Robots Performing Foraging Task               *\n');
fprintf('* Duration: 60 seconds                                    *\n');
fprintf('************************************************************\n');
fprintf('\n');

% Create and run simulation
sim = MultiRobotSimulation();
sim = sim.initializeRobots();
sim = sim.runSimulation();
sim = sim.saveResults();

fprintf('\n');
fprintf('Simulation complete! Video saved as: multi_robot_simulation.mp4\n');
fprintf('\n');
