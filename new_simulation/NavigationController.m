classdef NavigationController
    % NavigationController - Robot navigation with pheromone following
    % 
    % This class implements the navigation control algorithm that allows
    % robots to follow pheromone trails using TCRT5000 sensor readings.
    % Supports both ideal (perfect) and realistic sensing modes.
    
    properties
        % Controller type
        mode            % 'ideal' or 'realistic'
        
        % Navigation parameters
        max_speed
        turn_rate
        waypoint_threshold
        pheromone_threshold
        
        % PID controller gains for turning
        kp_turn
        ki_turn
        kd_turn
        
        % Internal state
        integral_turn
        prev_error
        
        % Simulation parameters
        params
    end
    
    methods
        function obj = NavigationController(params, mode)
            % Constructor
            %
            % Inputs:
            %   params - Simulation parameters
            %   mode - 'ideal' for perfect sensing, 'realistic' for TCRT5000 model
            
            obj.params = params;
            obj.mode = mode;
            obj.max_speed = params.max_speed;
            obj.turn_rate = params.turn_rate;
            obj.waypoint_threshold = params.waypoint_threshold;
            obj.pheromone_threshold = params.pheromone_threshold;
            
            % PID gains tuned for noisy sensor data with moving average filter
            % Lower Kp/Kd than ideal to prevent overreaction to filtered noise
            % Kp reduced from 3.0 to 1.5 (less aggressive turning)
            % Kd reduced from 0.5 to 0.2 (less sensitive to sudden changes)
            % Ki slightly increased for steady-state accuracy
            if strcmp(mode, 'realistic')
                obj.kp_turn = 1.5;    % Conservative for noisy data
                obj.ki_turn = 0.15;   % Slightly higher for steady-state
                obj.kd_turn = 0.2;    % Lower derivative gain
            else
                obj.kp_turn = 2.5;    % Ideal: can be more aggressive
                obj.ki_turn = 0.1;
                obj.kd_turn = 0.4;
            end
            
            obj.integral_turn = 0;
            obj.prev_error = 0;
        end
        
        function [v_l, v_r, trail_deviation] = computeWheelVelocities(obj, ...
                robot_pose, sensor_readings, pheromone_map)
            % Compute left and right wheel velocities based on sensor readings
            %
            % Inputs:
            %   robot_pose - [x, y, theta] robot position and heading
            %   sensor_readings - [1x4] TCRT5000 sensor values
            %   pheromone_map - PheromoneMap object
            %
            % Outputs:
            %   v_l, v_r - Left and right wheel velocities (m/s)
            %   trail_deviation - Deviation from optimal trail (m)
            
            if strcmp(obj.mode, 'ideal')
                % IDEAL MODE: Perfect pheromone sensing
                [v_l, v_r, trail_deviation] = obj.idealControl(robot_pose, pheromone_map);
            else
                % REALISTIC MODE: Use TCRT5000 sensor readings
                [v_l, v_r, trail_deviation] = obj.realisticControl(robot_pose, sensor_readings);
            end
        end
        
        function [v_l, v_r, trail_deviation] = idealControl(obj, robot_pose, pheromone_map)
            % Ideal control using perfect pheromone sensing
            % The robot knows exactly where the trail is
            
            target = obj.params.target_position;
            
            % Calculate direction to target
            dx = target(1) - robot_pose(1);
            dy = target(2) - robot_pose(2);
            desired_heading = atan2(dy, dx);
            
            % Calculate heading error
            heading_error = obj.normalizeAngle(desired_heading - robot_pose(3));
            
            % Calculate distance to target
            distance = sqrt(dx^2 + dy^2);
            
            % Trail deviation (ideal = 0)
            trail_deviation = 0;
            
            % Two-phase control for perfect straight-line navigation:
            % Phase 1: If heading error > threshold, rotate in place
            % Phase 2: If aligned, drive straight
            
            heading_threshold = 0.05; % radians (~3 degrees)
            distance_threshold = obj.waypoint_threshold;
            
            wheel_base = 0.1; % meters
            
            if abs(heading_error) > heading_threshold && distance > distance_threshold
                % Phase 1: Rotate to face target
                % Turn rate proportional to heading error
                turn_rate = obj.kp_turn * heading_error;
                turn_rate = max(-obj.turn_rate, min(obj.turn_rate, turn_rate));
                
                % Rotate in place (equal and opposite wheel speeds)
                speed = 0;
                v_l = speed - turn_rate * wheel_base / 2;
                v_r = speed + turn_rate * wheel_base / 2;
                
            else
                % Phase 2: Drive straight toward target
                % First correct any remaining heading error smoothly
                if abs(heading_error) > heading_threshold
                    turn_rate = obj.kp_turn * heading_error * 0.3; % Gentle correction
                else
                    turn_rate = 0; % Already aligned
                end
                turn_rate = max(-obj.turn_rate * 0.5, min(obj.turn_rate * 0.5, turn_rate));
                
                % Speed control - slow down near target
                speed = obj.max_speed;
                if distance < 0.5
                    speed = speed * (distance / 0.5); % Gradual slowdown
                end
                
                % Nearly straight differential drive
                v_l = speed - turn_rate * wheel_base / 2;
                v_r = speed + turn_rate * wheel_base / 2;
            end
            
            % Ensure non-negative speeds (no backward motion)
            v_l = max(0, v_l);
            v_r = max(0, v_r);
        end
        
        function [v_l, v_r, trail_deviation] = realisticControl(obj, robot_pose, sensor_readings)
            % Realistic control using TCRT5000 sensor readings
            % The robot must interpret sensor data to follow the trail
            
            % Estimate trail direction from sensor readings
            if length(sensor_readings) >= 4
                trail_direction = obj.estimateTrailDirection(sensor_readings);
            else
                % Fallback: use the center sensor
                trail_direction = 0;
            end
            
            % Calculate desired heading based on sensor reading
            desired_heading = robot_pose(3) + trail_direction * pi / 4; % Max 45 degree correction
            
            % Calculate heading error
            heading_error = obj.normalizeAngle(desired_heading - robot_pose(3));
            
            % Calculate trail deviation based on asymmetry in sensor readings
            if length(sensor_readings) >= 4
                left_avg = mean(sensor_readings(1:2));
                right_avg = mean(sensor_readings(3:4));
                trail_deviation = abs(left_avg - right_avg) * 0.001; % Convert to meters
            else
                trail_deviation = abs(heading_error) * 0.1;
            end
            
            % PID control for smooth turning
            obj.integral_turn = obj.integral_turn + heading_error * obj.params.dt;
            obj.integral_turn = max(-1, min(1, obj.integral_turn)); % Anti-windup
            
            derivative_turn = (heading_error - obj.prev_error) / obj.params.dt;
            
            turn_rate = obj.kp_turn * heading_error + ...
                       obj.ki_turn * obj.integral_turn + ...
                       obj.kd_turn * derivative_turn;
            
            % Clamp turn rate to prevent slinky effect
            % The robot should not be able to turn faster than this
            max_angular_velocity = obj.turn_rate * 0.6; % 60% of max to prevent spinning
            turn_rate = max(-max_angular_velocity, min(max_angular_velocity, turn_rate));
            obj.prev_error = heading_error;
            
            % Speed control: reduce speed proportionally to heading error
            % This prevents the robot from spinning in circles (slinky effect)
            avg_reading = mean(sensor_readings);
            base_speed = obj.max_speed;
            
            % When heading error is large, reduce speed significantly
            % This gives the robot time to correct without spinning
            heading_error_magnitude = abs(heading_error);
            speed_factor = 1.0 - 0.6 * min(heading_error_magnitude / pi, 1); % 40-100% of max
            speed_factor = max(0.4, speed_factor); % Never go below 40% speed
            
            % Slow down when following trail
            if avg_reading > obj.pheromone_threshold
                speed = base_speed * speed_factor * 0.8;
            else
                speed = base_speed * speed_factor;
            end
            
            % Ensure minimum forward motion to prevent pure spinning
            min_forward_speed = obj.max_speed * 0.2; % Always at least 20% forward
            speed = max(min_forward_speed, speed);
            
            % Differential drive velocities with smoother turning
            wheel_base = 0.1; % meters
            turn_factor = 0.8; % Reduce turning effect to prevent slinky
            
            v_l = speed - turn_rate * wheel_base / 2 * turn_factor;
            v_r = speed + turn_rate * wheel_base / 2 * turn_factor;
            
            % Ensure both wheels always move forward (no pure spinning)
            v_l = max(0.05 * obj.max_speed, v_l); % Minimum 5% of max
            v_r = max(0.05 * obj.max_speed, v_r);
        end
        
        function trail_direction = estimateTrailDirection(obj, sensor_readings)
            % Estimate the direction to the strongest pheromone trail
            % Positive = trail to the right, Negative = trail to the left
            
            if length(sensor_readings) < 4
                trail_direction = 0;
                return;
            end
            
            % Left pair (sensors 1-2) vs Right pair (sensors 3-4)
            left_avg = (sensor_readings(1) + sensor_readings(2)) / 2;
            right_avg = (sensor_readings(3) + sensor_readings(4)) / 2;
            
            % Direction estimate with noise threshold (deadband)
            % Prevents oscillation from small sensor differences
            diff = right_avg - left_avg;
            deadband = 15; % Ignore differences below this threshold
            
            if abs(diff) < deadband
                trail_direction = 0; % Within deadband, go straight
            else
                % Normalize to [-1, 1] with deadband removed
                max_diff = 100; % Expected max difference
                trail_direction = diff / max_diff;
                % Clamp to [-1, 1]
                trail_direction = max(-1, min(1, trail_direction));
            end
        end
        
        function angle = normalizeAngle(obj, angle)
            % Normalize angle to [-pi, pi]
            
            while angle > pi
                angle = angle - 2 * pi;
            end
            while angle < -pi
                angle = angle + 2 * pi;
            end
        end
        
        function obj = reset(obj)
            % Reset controller state
            
            obj.integral_turn = 0;
            obj.prev_error = 0;
        end
    end
end
