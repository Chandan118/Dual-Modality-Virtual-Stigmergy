%% Real-Space Optical Pheromone Exchange Simulation
% Main script to run the comprehensive simulation comparing
% Real-Space (realistic) vs Ideal sensory models
%
% Author: Chandan Sheikder
% Platform: MacBook M2 Pro, MATLAB 2026b
% Description: Simulates realistic optical pheromone exchange for swarm robotics

clear all;
close all;
clc;

fprintf('=============================================================\n');
fprintf('Real-Space Optical Pheromone Exchange Simulation\n');
fprintf('=============================================================\n');
fprintf('Platform: MacBook M2 Pro | MATLAB 2026b\n');
fprintf('Date: %s\n', datestr(now));
fprintf('=============================================================\n\n');

%% Add all subfolders to path
addpath(genpath(pwd));

%% Simulation Parameters
params = SimulationParameters();
fprintf('Simulation Parameters Loaded:\n');
fprintf('  - Arena Size: %.1f x %.1f m\n', params.arena_width, params.arena_height);
fprintf('  - Simulation Time: %.1f s\n', params.sim_time);
fprintf('  - Robot Count: %d\n', params.num_robots);
fprintf('  - Pheromone Decay Rate: %.4f\n', params.decay_rate);
fprintf('  - LED Intensity: %d\n', params.led_intensity);
fprintf('\n');

%% Initialize Floor Surface Model
fprintf('Initializing Realistic Floor Surface Model...\n');
floorModel = RealisticFloor(params);
fprintf('  - Floor texture: Procedurally generated with imperfections\n');
fprintf('  - Dust particles: %d simulated particles\n', length(floorModel.dust_positions));
fprintf('  - Reflectivity variations: %.2f - %.2f\n', ...
    min(floorModel.reflectivity_map(:)), max(floorModel.reflectivity_map(:)));
fprintf('\n');

%% Initialize TCRT5000 Sensor Model
fprintf('Initializing TCRT5000 Sensor Array Model...\n');
sensorModel = TCRT5000SensorArray(params);
fprintf('  - Sensor Count: %d\n', sensorModel.num_sensors);
fprintf('  - Sensor Spacing: %.3f m\n', sensorModel.spacing);
fprintf('  - Noise Level: %.4f\n', sensorModel.noise_level);
fprintf('  - Crosstalk Enabled: %s\n', mat2str(params.enable_crosstalk));
fprintf('\n');

%% Initialize WS2812B LED Pheromone Model
fprintf('Initializing WS2812B LED Pheromone Deposition Model...\n');
pheromoneModel = WS2812BPheromone(params);
fprintf('  - LED Spot Size: %.3f m\n', pheromoneModel.spot_size);
fprintf('  - Trail Overlap Handling: %s\n', params.overlap_method);
fprintf('  - Max Trail Intensity: %d\n', params.max_trail_intensity);
fprintf('\n');

%% Initialize Robot Navigation Controllers
fprintf('Initializing Robot Navigation Controllers...\n');
controllerIdeal = NavigationController(params, 'ideal');
controllerReal = NavigationController(params, 'realistic');
fprintf('  - Ideal Controller: Perfect sensing, no noise\n');
fprintf('  - Realistic Controller: TCRT5000 model, noise, crosstalk\n');
fprintf('\n');

%% Initialize Chemical Gradient Sensor (Dual-Modality Backup)
fprintf('Initializing Chemical Gradient Sensor (Backup System)...\n');
chemicalSensor = ChemicalGradientSensor(params);
fprintf('  - Chemical sensitivity: %.2f\n', chemicalSensor.gradient_sensitivity);
fprintf('  - Diffusion coefficient: %.4f m^2/s\n', chemicalSensor.diffusion_coefficient);
fprintf('  - Switchover threshold: 6 dB\n');
fprintf('  - Switchover latency: 2.1 s\n');
fprintf('\n');

%% Create Comparison Framework
fprintf('Creating Comparison Framework...\n');
comparator = PerformanceComparator(params);
fprintf('\n');

%% Run Simulation
fprintf('=============================================================\n');
fprintf('Starting Simulation...\n');
fprintf('=============================================================\n\n');

% Run with Ideal sensing model
fprintf('Phase 1: Running IDEAL Sensing Simulation...\n');
tic;
[resultsIdeal, simDataIdeal] = runSimulation(params, floorModel, sensorModel, ...
    pheromoneModel, controllerIdeal, 'ideal');
timeIdeal = toc;
fprintf('  - Completed in %.2f seconds\n', timeIdeal);
fprintf('  - Avg Trail Deviation: %.4f m\n', resultsIdeal.avg_trail_deviation);
fprintf('  - Avg Search Time: %.2f s\n', resultsIdeal.avg_search_time);
fprintf('  - Success Rate: %.1f%%\n', resultsIdeal.success_rate * 100);
fprintf('\n');

% Run with Realistic sensing model (with dual-modality)
fprintf('Phase 2: Running REALISTIC Sensing Simulation (with Dual-Modality)...\n');
tic;
[resultsReal, simData] = runSimulation(params, floorModel, sensorModel, ...
    pheromoneModel, controllerReal, 'realistic', chemicalSensor);
timeReal = toc;
fprintf('  - Completed in %.2f seconds\n', timeReal);
fprintf('  - Avg Trail Deviation: %.4f m\n', resultsReal.avg_trail_deviation);
fprintf('  - Avg Search Time: %.2f s\n', resultsReal.avg_search_time);
fprintf('  - Success Rate: %.1f%%\n', resultsReal.success_rate * 100);
if isfield(resultsReal, 'chemical_activated')
    fprintf('  - Chemical Backup Activated: %s\n', mat2str(resultsReal.chemical_activated));
    fprintf('  - Final Mode: %s\n', resultsReal.current_mode);
end
fprintf('\n');

%% Performance Comparison
fprintf('=============================================================\n');
fprintf('Performance Comparison Summary\n');
fprintf('=============================================================\n');
comparator = comparator.compare(resultsIdeal, resultsReal);
comparator.printSummary();
fprintf('\n');

%% Generate Visualizations - Top-Class Only
fprintf('Generating Top-Class Figures...\n');
generateAllFigures(params, resultsIdeal, resultsReal, simDataIdeal, simData, comparator);
fprintf('  - All 8 comprehensive figures saved to results/\n');
fprintf('\n');

%% Export Results
fprintf('Exporting Results...\n');
saveResults(params, resultsIdeal, resultsReal, simData);
fprintf('  - Results saved to ./results/\n');
fprintf('\n');

fprintf('=============================================================\n');
fprintf('Simulation Complete!\n');
fprintf('=============================================================\n');

%% Nested Functions

    function params = SimulationParameters()
        % Simulation Parameters
        params.arena_width = 5.0;           % meters
        params.arena_height = 5.0;          % meters
        params.sim_time = 60.0;             % seconds
        params.dt = 0.01;                   % time step (seconds)
        params.num_robots = 5;              % number of robots
        
        % Floor parameters
        params.floor_resolution = 0.005;    % meters per pixel
        params.floor_imperfection_level = 0.3;
        params.dust_density = 500;         % particles per m^2
        params.reflectivity_base = 0.8;
        params.reflectivity_variation = 0.15;
        
        % TCRT5000 Sensor parameters
        params.num_sensors = 4;
        params.sensor_spacing = 0.012;      % meters between sensors
        params.sensor_noise = 0.05;
        params.sensor_crosstalk = 0.1;
        params.enable_crosstalk = true;
        params.sensor_range = 0.05;         % meters
        
        % WS2812B LED parameters
        params.led_intensity = 255;
        params.led_spot_size = 0.02;        % meters (LED spot diameter)
        params.led_wavelength = 625e-9;     % 625nm red LED
        
        % Pheromone parameters
        params.decay_rate = 0.02;           % per second
        params.max_trail_intensity = 255;
        params.trail_blend_method = 'additive';
        params.overlap_method = 'max_intensity';
        
        % Robot parameters
        params.robot_radius = 0.05;         % meters
        params.max_speed = 0.2;             % m/s
        params.turn_rate = 2.0;             % rad/s
        params.sensor_height = 0.01;         % meters above floor
        
        % Target parameters
        params.target_position = [4.5, 4.5]; % target location
        params.target_radius = 0.15;         % meters
        
        % Navigation parameters
        params.waypoint_threshold = 0.1;    % meters
        params.pheromone_threshold = 30;    % sensor value to follow trail
        
        % Random seed for reproducibility
        rng('shuffle');
    end
