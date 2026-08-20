%% MultiRobotSimulation.m
% Multi-robot swarm simulation with 20 wheeled robots
% Generates 1-minute video of robots performing foraging task
%
% Date: 2026-08-15

classdef MultiRobotSimulation
    properties
        % Simulation parameters
        num_robots = 20;
        arena_width = 8.0;  % meters
        arena_height = 8.0; % meters
        sim_time = 60.0;    % seconds (1 minute)
        dt = 0.05;          % time step (50ms)
        
        % Robot parameters
        robot_radius = 0.08;     % meters
        max_speed = 0.15;        % m/s
        turn_rate = 1.5;         % rad/s
        
        % Pheromone parameters
        pheromone_decay = 0.02;   % per second
        pheromone_deposit = 200;  % intensity
        max_pheromone = 255;
        
        % Task parameters
        num_targets = 5;
        target_radius = 0.3;     % meters
        
        % Data storage
        time;
        positions;      % [num_robots x 3 x num_steps] = [x, y, theta]
        pheromone_grid; % 2D grid
        targets;        % target positions
        task_completed; % tasks found per robot
        
        % Grid parameters
        grid_resolution = 0.05;  % meters per cell
    end
    
    methods
        function obj = MultiRobotSimulation()
            % Constructor
            obj.time = 0:obj.dt:obj.sim_time;
            obj.positions = zeros(obj.num_robots, 3, length(obj.time));
            obj.task_completed = zeros(obj.num_robots, 1);
        end
        
        function obj = initializeRobots(obj)
            % Initialize robot positions randomly in arena
            
            fprintf('Initializing %d robots...\n', obj.num_robots);
            
            % Initialize positions
            for i = 1:obj.num_robots
                % Random position in arena (with margin)
                margin = 0.5;
                x = margin + (obj.arena_width - 2*margin) * rand();
                y = margin + (obj.arena_height - 2*margin) * rand();
                theta = 2*pi * rand();
                
                obj.positions(i, :, 1) = [x, y, theta];
            end
            
            % Initialize pheromone grid
            grid_size_x = ceil(obj.arena_width / obj.grid_resolution);
            grid_size_y = ceil(obj.arena_height / obj.grid_resolution);
            obj.pheromone_grid = zeros(grid_size_y, grid_size_x);
            
            % Place targets
            obj = obj.placeTargets();
            
            fprintf('Robots initialized at random positions.\n');
            fprintf('Targets placed at %d locations.\n', obj.num_targets);
        end
        
        function obj = placeTargets(obj)
            % Place food/target positions randomly
            margin = 1.0;
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
                        fprintf('MULTI-ROBOT SWARM SIMULATION\n');
                        fprintf('Number of robots: %d\n', obj.num_robots);
            fprintf('Arena size: %.1f x %.1f m\n', obj.arena_width, obj.arena_height);
            fprintf('Simulation time: %.0f seconds\n', obj.sim_time);
                        
            num_steps = length(obj.time);
            
            % Create figure for animation
            fig = figure('Name', 'Multi-Robot Swarm Simulation', ...
                'NumberTitle', 'off', ...
                'Position', [100, 100, 900, 900], ...
                'Color', 'white');
            
            % Initialize video writer
            video_filename = 'multi_robot_simulation.mp4';
            vWriter = VideoWriter(video_filename, 'MPEG-4');
            vWriter.FrameRate = 20;
            open(vWriter);
            fprintf('Video recording started: %s\n', video_filename);
            
            for step = 1:num_steps
                t = obj.time(step);
                
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
                    obj.plotState(fig, t, step);
                    
                    % Write video frame (resize to standard size)
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
                        fprintf('Video saved to: multi_robot_simulation.mp4\n');
            fprintf('Total tasks completed: %d\n', sum(obj.task_completed));
                    end
        
        function [sensor, grad_x, grad_y] = sensePheromone(obj, x, y)
            % Sense pheromone at position (x, y) and compute gradient
            grid_x = round(x / obj.grid_resolution) + 1;
            grid_y = round(y / obj.grid_resolution) + 1;
            
            % Clamp to grid bounds
            grid_x = max(1, min(size(obj.pheromone_grid, 2), grid_x));
            grid_y = max(1, min(size(obj.pheromone_grid, 1), grid_y));
            
            % Current reading
            sensor = obj.pheromone_grid(grid_y, grid_x);
            
            % Compute gradient (numerical)
            dx = 1;
            dy = 1;
            
            % Neighbor readings
            x_left  = max(1, grid_x - dx);
            x_right = min(size(obj.pheromone_grid, 2), grid_x + dx);
            y_up    = max(1, grid_y - dy);
            y_down  = min(size(obj.pheromone_grid, 1), grid_y + dy);
            
            grad_x = (obj.pheromone_grid(grid_y, x_right) - obj.pheromone_grid(grid_y, x_left)) / (2*dx*obj.grid_resolution);
            grad_y = (obj.pheromone_grid(y_down, grid_x) - obj.pheromone_grid(y_up, grid_x)) / (2*dy*obj.grid_resolution);
        end
        
        function [theta_new, deposit] = robotAlgorithm(obj, sensor, grad_x, grad_y, target, theta)
            % Biomimetic algorithm for robot navigation
            
            deposit = 0;
            
            % If high pheromone detected, follow gradient
            if sensor > 10 && norm([grad_x, grad_y]) > 0.1
                % Gradient following
                target_angle = atan2(grad_y, grad_x);
                diff = target_angle - theta;
                diff = atan2(sin(diff), cos(diff));
                
                % Steer towards gradient
                turn = sign(diff) * min(obj.turn_rate * 0.05, abs(diff));
                theta_new = theta + turn;
                deposit = obj.pheromone_deposit * 0.3;  % Light deposit while following
                
            elseif ~isempty(target)
                % Move towards nearest target
                target_angle = atan2(target(2), target(1));
                diff = target_angle - theta;
                diff = atan2(sin(diff), cos(diff));
                
                turn = sign(diff) * min(obj.turn_rate * 0.1, abs(diff));
                theta_new = theta + turn;
                
                % If close to target, deposit pheromone
                if norm(target) < 0.5
                    deposit = obj.pheromone_deposit;
                end
                
            else
                % Random walk ( Levy-like )
                theta_new = theta + (rand - 0.5) * 0.5;
            end
        end
        
        function target = findNearestTarget(obj, x, y)
            % Find nearest unvisited target
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
            % Deposit pheromone at position
            grid_x = round(x / obj.grid_resolution) + 1;
            grid_y = round(y / obj.grid_resolution) + 1;
            
            % Clamp to grid bounds
            grid_x = max(1, min(size(obj.pheromone_grid, 2), grid_x));
            grid_y = max(1, min(size(obj.pheromone_grid, 1), grid_y));
            
            % Add pheromone (Gaussian spread)
            spread = 3;  % cells
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
            
            % Cap at maximum
            obj.pheromone_grid = min(obj.pheromone_grid, obj.max_pheromone);
        end
        
        function theta_new = limitAngle(obj, theta)
            % Limit angle to [-pi, pi]
            theta_new = atan2(sin(theta), cos(theta));
        end
        
        function [x_new, y_new] = boundaryCheck(obj, x, y)
            % Check and adjust for arena boundaries
            margin = obj.robot_radius;
            
            x_new = max(margin, min(obj.arena_width - margin, x));
            y_new = max(margin, min(obj.arena_height - margin, y));
        end
        
        function plotState(obj, fig, t, step)
            % Plot current simulation state
            clf(fig);
            
            % Pheromone heatmap (background)
            subplot(1, 1, 1);
            imagesc([0, obj.arena_width], [0, obj.arena_height], obj.pheromone_grid);
            hold on;
            colormap hot;
            colorbar;
            caxis([0, obj.max_pheromone]);
            
            % Plot targets (food)
            plot(obj.targets(:, 1), obj.targets(:, 2), 'g*', 'MarkerSize', 20, 'LineWidth', 2);
            
            % Plot robots
            for i = 1:obj.num_robots
                x = obj.positions(i, 1, step);
                y = obj.positions(i, 2, step);
                theta = obj.positions(i, 3, step);
                
                % Robot body
                theta_plot = linspace(0, 2*pi, 20);
                x_robot = x + obj.robot_radius * cos(theta_plot);
                y_robot = y + obj.robot_radius * sin(theta_plot);
                fill(x_robot, y_robot, 'b', 'FaceAlpha', 0.8);
                
                % Direction arrow
                quiver(x, y, 0.2*cos(theta), 0.2*sin(theta), 'k', 'LineWidth', 2);
            end
            
            % Formatting
            axis([0, obj.arena_width, 0, obj.arena_height]);
            axis equal;
            xlabel('X (m)');
            ylabel('Y (m)');
            title(sprintf('Multi-Robot Swarm | t = %.1f s | Robots: %d', t, obj.num_robots), ...
                'FontSize', 14, 'FontWeight', 'bold');
            
            % Info box
            info_str = sprintf('Time: %.1f s\nRobots: %d\nPheromone: %.1f (avg)', ...
                t, obj.num_robots, mean(obj.pheromone_grid(:)));
            text(0.02*obj.arena_width, 0.95*obj.arena_height, info_str, ...
                'Units', 'normalized', 'FontSize', 10, 'BackgroundColor', 'white');
            
            drawnow;
        end
        
        function obj = saveResults(obj)
            % Save simulation results
            save('multi_robot_results.mat', 'obj');
            fprintf('Results saved to: multi_robot_results.mat\n');
        end
    end
end
