function [results, simData] = runSimulation(params, floorModel, sensorModel, ...
    pheromoneModel, controller, mode, varargin)
% runSimulation - Enhanced simulation with dual-modality switchover
%
% Inputs:
%   params - Simulation parameters
%   floorModel - RealisticFloor object
%   sensorModel - TCRT5000SensorArray object
%   pheromoneModel - WS2812BPheromone object
%   controller - NavigationController object
%   mode - 'ideal' or 'realistic'
%   varargin{1} - ChemicalGradientSensor (optional, for dual-modality)
%
% Outputs:
%   results - Performance metrics
%   simData - Full simulation data for visualization

    fprintf('  Initializing %s simulation...\n', mode);
    
    % Parse optional arguments
    enable_dual_modality = false;
    chemical_sensor = [];
    if nargin > 6 && ~isempty(varargin{1})
        enable_dual_modality = true;
        chemical_sensor = varargin{1};
        fprintf('  - Dual-modality enabled (chemical backup available)\n');
    end
    
    % Initialize simulation
    num_steps = round(params.sim_time / params.dt);
    robot_start = [0.5, 0.5, pi/4]; % [x, y, theta]
    robot_pose = robot_start;
    robot_path = zeros(num_steps, 3);
    robot_path(1, :) = robot_pose;
    
    % Sensor data storage
    sensor_history = zeros(num_steps, params.num_sensors);
    
    % Tracking variables
    reached_target = false;
    search_time = 0;
    trail_deviations = zeros(num_steps, 1);
    
    % Dual-modality state
    current_mode = 'optical';
    switchover_time = 0;
    optical_failed = false;
    optical_snr_history = zeros(num_steps, 1);
    chemical_activated = false;
    
    % SNR threshold for switchover (6 dB as per paper)
    snr_threshold = 6.0; % dB
    switchover_latency = 2.1; % seconds (as per paper)
    
    % Simulation loop
    fprintf('  Running %d simulation steps...\n', num_steps);
    
    for step = 1:num_steps
        current_time = step * params.dt;
        
        % Check if target reached
        distance_to_target = sqrt((robot_pose(1) - params.target_position(1))^2 + ...
                                (robot_pose(2) - params.target_position(2))^2);
        
        if distance_to_target < params.target_radius && ~reached_target
            reached_target = true;
            search_time = current_time;
            fprintf('    Target reached at t=%.2f s (mode: %s)\n', current_time, current_mode);
        end
        
        % === OPTICAL MODE ===
        if strcmp(mode, 'realistic')
            % Read optical sensors
            sensor_readings = sensorModel.readSensors(robot_pose, floorModel, pheromoneModel);
            
            % Calculate optical SNR (approximation based on signal variance)
            signal = mean(sensor_readings);
            noise = std(sensor_readings);
            if noise > 0
                optical_snr = 20 * log10(signal / noise);
            else
                optical_snr = 60; % Very high if no noise
            end
            optical_snr_history(step) = optical_snr;
            
            % === DUAL-MODALITY SWITCHOVER LOGIC ===
            if enable_dual_modality && ~optical_failed
                % Check if SNR drops below threshold
                if optical_snr < snr_threshold
                    if ~optical_failed
                        optical_failed = true;
                        switchover_time = current_time;
                        fprintf('    SNR dropped to %.1f dB at t=%.2f s\n', optical_snr, current_time);
                        fprintf('    Initiating %.1fs switchover to chemical backup...\n', switchover_latency);
                    end
                    
                    % Wait for switchover latency
                    if (current_time - switchover_time) >= switchover_latency
                        current_mode = 'chemical';
                        chemical_activated = true;
                        fprintf('    Switched to chemical mode at t=%.2f s\n', current_time);
                    end
                else
                    % SNR recovered, reset failure state
                    optical_failed = false;
                end
            end
            
            % Compute wheel velocities based on current mode
            if strcmp(current_mode, 'chemical') && enable_dual_modality
                % Use chemical gradient sensing
                [chem_direction, ~, chem_snr] = chemical_sensor.senseChemicalGradient(...
                    robot_pose, params.target_position, current_time);
                
                % Map chemical direction to wheel velocities
                turn_rate = chem_direction * params.turn_rate * 0.5;
                speed = params.max_speed * 0.8;
                
                wheel_base = 0.1;
                v_l = speed - turn_rate * wheel_base / 2;
                v_r = speed + turn_rate * wheel_base / 2;
                
                trail_dev = abs(chem_direction) * 0.1;
            else
                % Use optical navigation
                [v_l, v_r, trail_dev] = controller.computeWheelVelocities(robot_pose, sensor_readings, pheromoneModel);
            end
            
        else
            % IDEAL MODE
            sensor_readings = ones(params.num_sensors, 1) * 128;
            [v_l, v_r, trail_dev] = controller.computeWheelVelocities(robot_pose, sensor_readings, pheromoneModel);
            optical_snr = 60; % Ideal = high SNR
        end
        
        sensor_history(step, :) = sensor_readings;
        trail_deviations(step) = trail_dev;
        
        % Deposit pheromone trail
        if mod(step, 10) == 0
            pheromoneModel = pheromoneModel.deposit(robot_pose(1:2), ...
                params.led_intensity, current_time);
        end
        
        % Update robot pose
        wheel_base = 0.1;
        linear_vel = (v_l + v_r) / 2;
        angular_vel = (v_r - v_l) / wheel_base;
        
        robot_pose(1) = robot_pose(1) + linear_vel * cos(robot_pose(3)) * params.dt;
        robot_pose(2) = robot_pose(2) + linear_vel * sin(robot_pose(3)) * params.dt;
        robot_pose(3) = robot_pose(3) + angular_vel * params.dt;
        
        % Normalize angle
        robot_pose(3) = mod(robot_pose(3), 2*pi);
        if robot_pose(3) > pi
            robot_pose(3) = robot_pose(3) - 2*pi;
        end
        
        % Boundary collision
        margin = params.robot_radius;
        robot_pose(1) = max(margin, min(params.arena_width - margin, robot_pose(1)));
        robot_pose(2) = max(margin, min(params.arena_height - margin, robot_pose(2)));
        
        if step <= num_steps
            robot_path(step, :) = robot_pose;
        end
        
        % Progress reporting
        if mod(step, num_steps/10) == 0
            progress = step / num_steps * 100;
            fprintf('    Progress: %d%% (mode: %s)\n', round(progress), current_mode);
        end
    end
    
    % Trim data
    robot_path = robot_path(1:step, :);
    sensor_history = sensor_history(1:step, :);
    trail_deviations = trail_deviations(1:step);
    optical_snr_history = optical_snr_history(1:step);
    
    % Calculate metrics
    fprintf('  Calculating performance metrics...\n');
    
    results = struct();
    results.avg_trail_deviation = mean(trail_deviations);
    results.std_trail_deviation = std(trail_deviations);
    results.max_trail_deviation = max(trail_deviations);
    
    if reached_target
        results.avg_search_time = search_time;
    else
        results.avg_search_time = params.sim_time;
    end
    
    results.success_rate = double(reached_target);
    
    % Calculate path length correctly
    straight_line_dist = sqrt((params.target_position(1) - robot_start(1))^2 + ...
                            (params.target_position(2) - robot_start(2))^2);
    results.shortest_distance = straight_line_dist;
    
    % Actual path length: sum of Euclidean distances between consecutive points
    if size(robot_path, 1) > 1
        diff_x = diff(robot_path(:, 1));
        diff_y = diff(robot_path(:, 2));
        actual_path_length = sum(sqrt(diff_x.^2 + diff_y.^2));
    else
        actual_path_length = straight_line_dist;
    end
    results.path_length = actual_path_length;
    
    % Path efficiency = shortest_distance / actual_distance (as a fraction)
    results.path_efficiency = straight_line_dist / max(actual_path_length, eps);
    
    % Dual-modality metrics
    if enable_dual_modality
        results.optical_failed = optical_failed;
        results.chemical_activated = chemical_activated;
        results.switchover_time = switchover_time;
        results.avg_optical_snr = mean(optical_snr_history);
        results.current_mode = current_mode;
    end
    
    if strcmp(mode, 'realistic')
        results.avg_sensor_reading = mean(sensor_history(:));
        results.std_sensor_reading = std(sensor_history(:));
    end
    
    % Store simulation data
    simData = struct();
    simData.robot_path = robot_path;
    simData.sensor_history = sensor_history;
    simData.trail_deviations = trail_deviations;
    simData.optical_snr_history = optical_snr_history;
    simData.params = params;
    simData.floorModel = floorModel;
    simData.pheromoneModel = pheromoneModel;
    simData.mode = mode;
    simData.reached_target = reached_target;
    simData.search_time = search_time;
    simData.current_mode = current_mode;
    
    fprintf('  %s simulation complete.\n', mode);
end
