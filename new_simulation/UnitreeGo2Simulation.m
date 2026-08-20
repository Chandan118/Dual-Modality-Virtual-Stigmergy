%% UnitreeGo2Simulation.m
% Multi-robot simulation with 20 Unitree Go2 quadruped robots
% Generates 1-minute video of robots performing foraging task
%
% Robot specs from: https://www.unitree.com/opensource
% URDF: unitree_go2.urdf
%
% Date: 2026-08-15

classdef UnitreeGo2Simulation
    properties
        % Simulation parameters
        num_robots = 20;
        arena_width = 10.0;   % meters (larger for quadrupeds)
        arena_height = 10.0;  % meters
        sim_time = 60.0;      % seconds (1 minute)
        dt = 0.05;            % time step (50ms)
        
        % Unitree Go2 Specifications (from official specs)
        robot_length = 0.645;   % m
        robot_width = 0.300;    % m
        robot_height = 0.400;   % m (with legs extended)
        robot_mass = 15.0;      % kg
        
        % Go2 Joint Parameters
        hip_range = 1.047;      % rad (±60°)
        knee_range = 2.251;     % rad (-129° to -30°)
        max_joint_velocity = 30; % rad/s
        
        % Locomotion parameters
        max_speed = 1.5;        % m/s (Go2 max speed ~1.5 m/s)
        turn_rate = 3.0;        % rad/s
        
        % Pheromone parameters
        pheromone_decay = 0.02;     % per second
        pheromone_deposit = 200;     % intensity
        max_pheromone = 255;
        
        % Task parameters
        num_targets = 5;
        target_radius = 0.5;    % meters
        
        % Data storage
        time;
        positions;      % [num_robots x 3 x num_steps] = [x, y, theta]
        joint_states;   % [num_robots x 12 x num_steps] = 12 joints
        pheromone_grid;
        targets;
        task_completed;
        
        % Grid parameters
        grid_resolution = 0.05;  % meters per cell
    end
    
    methods
        function obj = UnitreeGo2Simulation()
            % Constructor
            obj.time = 0:obj.dt:obj.sim_time;
            obj.positions = zeros(obj.num_robots, 3, length(obj.time));
            obj.joint_states = zeros(obj.num_robots, 12, length(obj.time));
            obj.task_completed = zeros(obj.num_robots, 1);
        end
        
        function obj = initializeRobots(obj)
            % Initialize robot positions randomly in arena
            
                        fprintf('UNITREE GO2 MULTI-ROBOT SIMULATION\n');
                        fprintf('Robot Model: Unitree Go2\n');
            fprintf('Source: https://www.unitree.com/opensource\n');
            fprintf('URDF: unitree_go2.urdf\n');
                        fprintf('Initializing %d Unitree Go2 robots...\n', obj.num_robots);
            
            % Initialize positions
            for i = 1:obj.num_robots
                margin = 1.0;
                x = margin + (obj.arena_width - 2*margin) * rand();
                y = margin + (obj.arena_height - 2*margin) * rand();
                theta = 2*pi * rand();
                
                obj.positions(i, :, 1) = [x, y, theta];
                
                % Initialize joint states (standing pose)
                % Hip angles: 0.3 rad, Knee angles: -1.0 rad
                obj.joint_states(i, :, 1) = [
                    0.3, 0.3, -0.3, -0.3, ...  % Hip joints (FL, FR, RL, RR)
                    -1.0, -1.0, -1.0, -1.0, ... % Knee joints
                    0, 0, 0, 0 ...              % Placeholder for additional joints
                ];
            end
            
            % Initialize pheromone grid
            grid_size_x = ceil(obj.arena_width / obj.grid_resolution);
            grid_size_y = ceil(obj.arena_height / obj.grid_resolution);
            obj.pheromone_grid = zeros(grid_size_y, grid_size_x);
            
            % Place targets
            obj = obj.placeTargets();
            
            fprintf('Unitree Go2 robots initialized.\n');
            fprintf('Dimensions: %.3f x %.3f x %.3f m\n', obj.robot_length, obj.robot_width, obj.robot_height);
            fprintf('Mass: %.1f kg\n', obj.robot_mass);
            fprintf('Max Speed: %.1f m/s\n', obj.max_speed);
            fprintf('Targets placed at %d locations.\n', obj.num_targets);
        end
        
        function obj = placeTargets(obj)
            margin = 1.5;
            obj.targets = zeros(obj.num_targets, 2);
            
            for t = 1:obj.num_targets
                obj.targets(t, :) = [
                    margin + (obj.arena_width - 2*margin) * rand(), ...
                    margin + (obj.arena_height - 2*margin) * rand()
                ];
            end
        end
        
        function obj = runSimulation(obj)
            % Run the main simulation loop
            
            fprintf('\n');
                        fprintf('SIMULATION STARTED\n');
                        fprintf('Number of robots: %d\n', obj.num_robots);
            fprintf('Arena size: %.1f x %.1f m\n', obj.arena_width, obj.arena_height);
            fprintf('Simulation time: %.0f seconds\n', obj.sim_time);
                        
            num_steps = length(obj.time);
            
            % Create figure for animation
            fig = figure('Name', 'Unitree Go2 Multi-Robot Swarm', ...
                'NumberTitle', 'off', ...
                'Position', [100, 100, 1000, 1000], ...
                'Color', 'white');
            
            % Initialize video writer
            video_filename = 'unitree_go2_simulation.mp4';
            vWriter = VideoWriter(video_filename, 'MPEG-4');
            vWriter.FrameRate = 20;
            open(vWriter);
            fprintf('Video recording started: %s\n', video_filename);
            
            % Gait phase for quadruped walking
            gait_phase = 0;
            
            for step = 1:num_steps
                t = obj.time(step);
                
                % Update gait phase
                gait_freq = 2.0;  % Hz
                gait_phase = mod(gait_phase + 2*pi*gait_freq*obj.dt, 2*pi);
                
                % Update each robot
                for i = 1:obj.num_robots
                    % Get current position
                    x = obj.positions(i, 1, step);
                    y = obj.positions(i, 2, step);
                    theta = obj.positions(i, 3, step);
                    
                    % Sense pheromone and targets
                    [sensor_reading, grad_x, grad_y] = obj.sensePheromone(x, y);
                    nearest_target = obj.findNearestTarget(x, y);
                    
                    % Decide movement (biomimetic algorithm)
                    [theta_new, deposit] = obj.robotAlgorithm(sensor_reading, grad_x, grad_y, nearest_target, theta);
                    
                    % Update position
                    dx = obj.max_speed * obj.dt * cos(theta_new);
                    dy = obj.max_speed * obj.dt * sin(theta_new);
                    
                    x_new = x + dx;
                    y_new = y + dy;
                    theta_new = obj.limitAngle(theta_new);
                    
                    % Boundary checking
                    [x_new, y_new] = obj.boundaryCheck(x_new, y_new);
                    
                    % Store new position
                    if step < num_steps
                        obj.positions(i, :, step+1) = [x_new, y_new, theta_new];
                    end
                    
                    % Update joint states (quadruped gait)
                    obj = obj.updateQuadrupedGait(i, step, theta_new, gait_phase);
                    
                    % Deposit pheromone
                    if deposit > 0
                        obj = obj.depositPheromone(x_new, y_new, deposit);
                    end
                end
                
                % Decay pheromone
                obj.pheromone_grid = obj.pheromone_grid * (1 - obj.pheromone_decay * obj.dt);
                obj.pheromone_grid = max(obj.pheromone_grid, 0);
                
                % Update plot every 5 steps for speed
                if mod(step, 5) == 0 || step == 1
                    obj.plotState(fig, t, step, gait_phase);
                    
                    % Write video frame
                    frame = getframe(fig);
                    frame_resized = imresize(frame.cdata, [720, 1280]);
                    writeVideo(vWriter, im2frame(frame_resized));
                    
                    % Progress
                    progress = 100 * step / num_steps;
                    if mod(step, 100) == 0
                        fprintf('Progress: %d%% (t=%.1f s)\n', floor(progress), t);
                    end
                end
            end
            
            % Close video
            close(vWriter);
            close(fig);
            
            fprintf('\n');
                        fprintf('SIMULATION COMPLETE!\n');
                        fprintf('Video saved to: unitree_go2_simulation.mp4\n');
            fprintf('Robot Model: Unitree Go2\n');
                    end
        
        function obj = updateQuadrupedGait(obj, robot_idx, step, theta, phase)
            % Update joint angles for quadruped walking gait
            % Go2 trot gait pattern
            
            % Gait timing (trot: diagonal pairs)
            % FL + RR together, FR + RL together
            
            hip_amp = 0.3;   % Hip swing amplitude (rad)
            knee_amp = 0.5;  % Knee swing amplitude (rad)
            
            % Phase offsets for trot gait
            fl_phase = phase;
            fr_phase = phase + pi;
            rl_phase = phase + pi;
            rr_phase = phase;
            
            % Hip joint angles
            hip_fl = hip_amp * sin(fl_phase);
            hip_fr = hip_amp * sin(fr_phase);
            hip_rl = hip_amp * sin(rl_phase);
            hip_rr = hip_amp * sin(rr_phase);
            
            % Knee joint angles (always negative for Go2 knee bend)
            knee_fl = -1.0 - knee_amp * abs(sin(fl_phase));
            knee_fr = -1.0 - knee_amp * abs(sin(fr_phase));
            knee_rl = -1.0 - knee_amp * abs(sin(rl_phase));
            knee_rr = -1.0 - knee_amp * abs(sin(rr_phase));
            
            if step < length(obj.time)
                obj.joint_states(robot_idx, :, step+1) = [
                    hip_fl, hip_fr, hip_rl, hip_rr, ...
                    knee_fl, knee_fr, knee_rl, knee_rr, ...
                    0, 0, 0, 0
                ];
            end
        end
        
        function [sensor, grad_x, grad_y] = sensePheromone(obj, x, y)
            grid_x = round(x / obj.grid_resolution) + 1;
            grid_y = round(y / obj.grid_resolution) + 1;
            
            grid_x = max(1, min(size(obj.pheromone_grid, 2), grid_x));
            grid_y = max(1, min(size(obj.pheromone_grid, 1), grid_y));
            
            sensor = obj.pheromone_grid(grid_y, grid_x);
            
            dx = 1;
            dy = 1;
            
            x_left  = max(1, grid_x - dx);
            x_right = min(size(obj.pheromone_grid, 2), grid_x + dx);
            y_up    = max(1, grid_y - dy);
            y_down  = min(size(obj.pheromone_grid, 1), grid_y + dy);
            
            grad_x = (obj.pheromone_grid(grid_y, x_right) - obj.pheromone_grid(grid_y, x_left)) / (2*dx*obj.grid_resolution);
            grad_y = (obj.pheromone_grid(y_down, grid_x) - obj.pheromone_grid(y_up, grid_x)) / (2*dy*obj.grid_resolution);
        end
        
        function [theta_new, deposit] = robotAlgorithm(obj, sensor, grad_x, grad_y, target, theta)
            deposit = 0;
            
            if sensor > 10 && norm([grad_x, grad_y]) > 0.1
                target_angle = atan2(grad_y, grad_x);
                diff = target_angle - theta;
                diff = atan2(sin(diff), cos(diff));
                
                turn = sign(diff) * min(obj.turn_rate * 0.05, abs(diff));
                theta_new = theta + turn;
                deposit = obj.pheromone_deposit * 0.3;
                
            elseif ~isempty(target)
                target_angle = atan2(target(2), target(1));
                diff = target_angle - theta;
                diff = atan2(sin(diff), cos(diff));
                
                turn = sign(diff) * min(obj.turn_rate * 0.1, abs(diff));
                theta_new = theta + turn;
                
                if norm(target) < 0.8
                    deposit = obj.pheromone_deposit;
                end
                
            else
                theta_new = theta + (rand - 0.5) * 0.5;
            end
        end
        
        function target = findNearestTarget(obj, x, y)
            min_dist = inf;
            target = [];
            
            for t = 1:obj.num_targets
                dist = norm([x, y] - obj.targets(t, :));
                if dist < min_dist
                    min_dist = dist;
                    target = obj.targets(t, :) - [x, y];
                end
            end
        end
        
        function obj = depositPheromone(obj, x, y, amount)
            grid_x = round(x / obj.grid_resolution) + 1;
            grid_y = round(y / obj.grid_resolution) + 1;
            
            grid_x = max(1, min(size(obj.pheromone_grid, 2), grid_x));
            grid_y = max(1, min(size(obj.pheromone_grid, 1), grid_y));
            
            spread = 3;
            for dx = -spread:spread
                for dy = -spread:spread
                    gx = grid_x + dx;
                    gy = grid_y + dy;
                    if gx >= 1 && gx <= size(obj.pheromone_grid, 2) && ...
                       gy >= 1 && gy <= size(obj.pheromone_grid, 1)
                        dist = sqrt(dx^2 + dy^2);
                        obj.pheromone_grid(gy, gx) = obj.pheromone_grid(gy, gx) + ...
                            amount * exp(-dist^2 / 4);
                    end
                end
            end
            
            obj.pheromone_grid = min(obj.pheromone_grid, obj.max_pheromone);
        end
        
        function theta_new = limitAngle(obj, theta)
            theta_new = atan2(sin(theta), cos(theta));
        end
        
        function [x_new, y_new] = boundaryCheck(obj, x, y)
            margin = 0.4;  % Half of Go2 width
            
            x_new = max(margin, min(obj.arena_width - margin, x));
            y_new = max(margin, min(obj.arena_height - margin, y));
        end
        
        function plotState(obj, fig, t, step, gait_phase)
            clf(fig);
            
            % Pheromone heatmap (background)
            subplot(1, 1, 1);
            imagesc([0, obj.arena_width], [0, obj.arena_height], obj.pheromone_grid);
            hold on;
            colormap hot;
            colorbar;
            caxis([0, obj.max_pheromone]);
            
            % Plot targets (food)
            plot(obj.targets(:, 1), obj.targets(:, 2), 'g*', 'MarkerSize', 25, 'LineWidth', 2);
            
            % Plot Unitree Go2 robots
            for i = 1:obj.num_robots
                x = obj.positions(i, 1, step);
                y = obj.positions(i, 2, step);
                theta = obj.positions(i, 3, step);
                
                % Get current joint states
                joints = obj.joint_states(i, :, step);
                
                % Draw Go2 robot body (trunk)
                % Body is an oval/rectangle shape
                body_length = 0.645;
                body_width = 0.300;
                
                % Trunk corners
                corners = [
                    x + body_length/2 * cos(theta) - body_width/2 * sin(theta), ...
                    y + body_length/2 * sin(theta) + body_width/2 * cos(theta);
                    x + body_length/2 * cos(theta) + body_width/2 * sin(theta), ...
                    y + body_length/2 * sin(theta) - body_width/2 * cos(theta);
                    x - body_length/2 * cos(theta) + body_width/2 * sin(theta), ...
                    y - body_length/2 * sin(theta) - body_width/2 * cos(theta);
                    x - body_length/2 * cos(theta) - body_width/2 * sin(theta), ...
                    y - body_length/2 * sin(theta) + body_width/2 * cos(theta);
                ];
                
                % Draw body
                fill(corners(:, 1), corners(:, 2), [0.3 0.3 0.3], 'FaceAlpha', 0.8, 'EdgeColor', 'k');
                
                % Draw legs (4 legs)
                leg_positions = [0.3, 0.15; 0.3, -0.15; -0.3, 0.15; -0.3, -0.15];
                leg_names = {'FL', 'FR', 'RL', 'RR'};
                
                for j = 1:4
                    hip_x = x + leg_positions(j,1) * cos(theta) - leg_positions(j,2) * sin(theta);
                    hip_y = y + leg_positions(j,1) * sin(theta) + leg_positions(j,2) * cos(theta);
                    
                    % Knee position (simplified)
                    knee_amp = 0.15;
                    knee_angle = joints(4+j);  % Knee angle
                    
                    knee_x = hip_x + 0.2 * cos(theta + knee_angle);
                    knee_y = hip_y + 0.2 * sin(theta + knee_angle);
                    
                    % Foot position
                    foot_x = knee_x + 0.2 * cos(theta + knee_angle * 0.5);
                    foot_y = knee_y + 0.2 * sin(theta + knee_angle * 0.5);
                    
                    % Draw leg
                    plot([hip_x, knee_x, foot_x], [hip_y, knee_y, foot_y], 'k-', 'LineWidth', 2);
                    plot(foot_x, foot_y, 'ko', 'MarkerSize', 4);
                end
                
                % Draw direction indicator
                quiver(x, y, 0.3*cos(theta), 0.3*sin(theta), 'r', 'LineWidth', 2);
                
                % Robot ID label
                text(x, y + 0.5, num2str(i), 'FontSize', 8, 'Color', 'white', ...
                    'HorizontalAlignment', 'center');
            end
            
            % Formatting
            axis([0, obj.arena_width, 0, obj.arena_height]);
            axis equal;
            xlabel('X (m)');
            ylabel('Y (m)');
            title(sprintf('Unitree Go2 Swarm | t = %.1f s | Robots: %d | https://www.unitree.com/opensource', ...
                t, obj.num_robots), 'FontSize', 14, 'FontWeight', 'bold');
            
            % Info box
            info_str = sprintf('Unitree Go2\nTime: %.1f s\nRobots: %d\nSpeed: %.1f m/s', ...
                t, obj.num_robots, obj.max_speed);
            text(0.02*obj.arena_width, 0.95*obj.arena_height, info_str, ...
                'Units', 'normalized', 'FontSize', 10, 'BackgroundColor', 'white');
            
            drawnow;
        end
        
        function obj = saveResults(obj)
            save('unitree_go2_results.mat', 'obj');
            fprintf('Results saved to: unitree_go2_results.mat\n');
        end
    end
end
