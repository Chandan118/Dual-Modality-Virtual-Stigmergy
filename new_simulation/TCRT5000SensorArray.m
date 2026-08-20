classdef TCRT5000SensorArray
    % TCRT5000SensorArray - Models 4x TCRT5000 reflective infrared sensors
    % 
    % This class simulates how the TCRT5000 sensors respond to the floor
    % surface and optical pheromone trails, including realistic noise and
    % potential crosstalk between sensors.
    %
    % TCRT5000 Specifications:
    %   - Operating range: 0.5mm to 5mm (reflectance mode)
    %   - Peak wavelength: 850nm (infrared)
    %   - Response time: ~20us
    
    properties
        % Sensor configuration
        num_sensors
        spacing                 % meters between sensors
        sensor_range
        noise_level
        crosstalk_factor
        enable_crosstalk
        
        % Sensor positions relative to robot center
        sensor_positions
        
        % Physical parameters
        wavelength = 850e-9;    % IR wavelength
        emitter_current = 50e-3; % LED current (A)
        detector_gain = 100;    % Amplifier gain
        
        % Moving average filter (5-sample as per hardware spec)
        filter_length = 5;
        sensor_history        % Stores last N readings for filtering
        history_index         % Circular buffer index
    end
    
    methods
        function obj = TCRT5000SensorArray(params)
            % Constructor
            
            obj.num_sensors = params.num_sensors;
            obj.spacing = params.sensor_spacing;
            obj.sensor_range = params.sensor_range;
            obj.noise_level = params.sensor_noise;
            obj.crosstalk_factor = params.sensor_crosstalk;
            obj.enable_crosstalk = params.enable_crosstalk;
            
            % Calculate sensor positions (linear array)
            % Sensors positioned in a line perpendicular to robot heading
            obj.sensor_positions = zeros(obj.num_sensors, 2);
            for i = 1:obj.num_sensors
                offset = (i - (obj.num_sensors + 1) / 2) * obj.spacing;
                obj.sensor_positions(i, :) = [offset, 0];
            end
            
            % Initialize 5-sample moving average filter history
            % This matches the hardware implementation described in your paper
            obj.sensor_history = zeros(obj.num_sensors, obj.filter_length);
            obj.history_index = 1;
        end
        
        function readings = readSensors(obj, robot_pose, floor, pheromone_map)
            % Read all sensors and return calibrated values
            %
            % Inputs:
            %   robot_pose - [x, y, theta] robot position and heading
            %   floor - RealisticFloor object
            %   pheromone_map - PheromoneMap object
            %
            % Output:
            %   readings - vector of sensor values [1x4]
            
            readings = zeros(obj.num_sensors, 1);
            
            % Rotation matrix for robot heading
            R = [cos(robot_pose(3)), -sin(robot_pose(3));
                 sin(robot_pose(3)),  cos(robot_pose(3))];
            
            for i = 1:obj.num_sensors
                % Transform sensor position to world coordinates
                sensor_pos_world = robot_pose(1:2)' + R * obj.sensor_positions(i, :)';
                
                % Get base reflectance from floor
                base_reflectance = floor.getReflectivity(sensor_pos_world(1), sensor_pos_world(2));
                
                % Get dust effect
                dust_effect = floor.getDustReading(sensor_pos_world(1), sensor_pos_world(2), obj.sensor_range);
                
                % Get pheromone intensity at this position
                if ismethod(pheromone_map, 'getIntensity')
                    pheromone_intensity = pheromone_map.getIntensity(sensor_pos_world(1), sensor_pos_world(2));
                elseif ismethod(pheromone_map, 'getIntensityAtPosition')
                    pheromone_intensity = pheromone_map.getIntensityAtPosition(sensor_pos_world(1), sensor_pos_world(2), 0, 0.02);
                else
                    pheromone_intensity = 0; % Default if no method available
                end
                
                % Calculate sensor reading
                readings(i) = obj.calculateReading(base_reflectance, dust_effect, pheromone_intensity, i);
            end
            
            % Apply crosstalk between adjacent sensors
            if obj.enable_crosstalk
                readings = obj.applyCrosstalk(readings);
            end
            
            % Add temporal noise (thermal and shot noise)
            readings = obj.addNoise(readings);
            
            % Apply 5-sample moving average filter (matches hardware implementation)
            readings = obj.applyMovingAverageFilter(readings);
        end
        
        function filtered = applyMovingAverageFilter(obj, new_readings)
            % Apply 5-sample moving average filter
            % This matches the hardware filter described in your paper (Page 13)
            % Reduces high-frequency noise while preserving signal trend
            
            % Update circular buffer
            obj.sensor_history(:, obj.history_index) = new_readings;
            obj.history_index = mod(obj.history_index, obj.filter_length) + 1;
            
            % Compute moving average across all stored samples
            % For initial samples (before buffer is full), use available samples
            samples_used = sum(obj.sensor_history ~= 0 | obj.sensor_history == 0, 2);
            samples_used = min(samples_used, obj.filter_length);
            
            % Sum all samples and divide by count
            total = sum(obj.sensor_history, 2);
            filtered = total ./ max(samples_used, 1); % Avoid division by zero
            filtered = filtered'; % Return as row vector
        end
        
        function reading = calculateReading(obj, base_reflectance, dust_effect, pheromone_intensity, sensor_idx)
            % Calculate raw sensor reading based on physical model
            
            % TCRT5000 sensor response model:
            % The sensor outputs a voltage proportional to reflected IR
            % Higher reflectance = higher output = lower ADC value (for typical circuit)
            % Pheromone trail (red LED) adds extra reflectance at IR wavelength
            
            % Effective reflectance = base + pheromone contribution
            % Pheromone contribution depends on trail intensity (0-255) and wavelength matching
            
            % IR reflectance from pheromone trail (red LED at 625nm has some IR component)
            % The TCRT5000 is most sensitive at 850nm, but red LEDs emit some IR
            pheromone_ir_contribution = pheromone_intensity / 255 * 0.15 * base_reflectance;
            
            % Effective total reflectance
            effective_reflectance = base_reflectance * (1 + pheromone_ir_contribution);
            
            % Dust reduces effective reflectance (scattering and absorption)
            effective_reflectance = effective_reflectance * (1 - dust_effect * 0.5);
            
            % Convert to sensor output (ADC-like value)
            % Lower reflectance = lower voltage = higher ADC value (inverted)
            % Typical TCRT5000 output: 0-3.3V mapped to 0-4095 (12-bit ADC)
            
            % Map reflectance [0, 1] to sensor value [0, 255] (inverted)
            base_reading = uint8((1 - effective_reflectance) * 255);
            
            % Add pheromone detection boost
            % The sensor can distinguish the red LED component from ambient IR
            pheromone_detection = pheromone_intensity / 255 * 50;
            
            % Combine
            reading = double(base_reading) + pheromone_detection;
            
            % Clamp to valid range
            reading = max(0, min(255, reading));
        end
        
        function readings = applyCrosstalk(obj, readings)
            % Apply crosstalk effect between adjacent sensors
            % Infrared sensors can pick up light from neighboring sensors
            
            % Simple linear crosstalk model
            % Each sensor picks up (crosstalk_factor)% from each neighbor
            num_sensors = length(readings);
            readings_with_crosstalk = readings;
            
            for i = 1:num_sensors
                % Get contributions from neighbors
                left_neighbor = max(1, i-1);
                right_neighbor = min(num_sensors, i+1);
                
                crosstalk = obj.crosstalk_factor * (readings(left_neighbor) + readings(right_neighbor)) / 2;
                readings_with_crosstalk(i) = readings(i) + crosstalk;
            end
            
            readings = readings_with_crosstalk;
        end
        
        function readings = addNoise(obj, readings)
            % Add realistic sensor noise
            % Combines thermal noise, shot noise, and quantization
            
            num_readings = length(readings);
            
            % Thermal noise (Gaussian)
            thermal_noise = obj.noise_level * 10 * randn(num_readings, 1);
            
            % Shot noise (Poisson-like, more prominent at higher values)
            shot_noise = sqrt(readings) .* randn(num_readings, 1) * obj.noise_level * 5;
            
            % 1/f noise (flicker noise) - slow drift
            flicker_noise = obj.noise_level * 2 * (rand(num_readings, 1) - 0.5);
            
            % Quantization noise (12-bit ADC -> 0.25 LSB RMS)
            quantization_noise = 0.25 * randn(num_readings, 1);
            
            % Combined noise
            total_noise = thermal_noise + shot_noise + flicker_noise + quantization_noise;
            
            readings = readings + total_noise;
            readings = max(0, min(255, readings));
        end
        
        function trail_direction = estimateTrailDirection(obj, readings)
            % Estimate direction to strongest trail from sensor readings
            %
            % Positive = trail to the right
            % Negative = trail to the left
            % Zero = trail straight ahead or no trail
            
            if obj.num_sensors ~= 4
                error('Trail direction estimation requires exactly 4 sensors');
            end
            
            % Left pair vs right pair comparison
            left_avg = (readings(1) + readings(2)) / 2;
            right_avg = (readings(3) + readings(4)) / 2;
            
            % Direction estimate (normalized)
            max_reading = max(max(left_avg, right_avg), 1); % avoid division by zero
            trail_direction = (right_avg - left_avg) / max_reading;
            
            % Threshold to avoid noise-induced oscillation
            if abs(trail_direction) < 0.1
                trail_direction = 0;
            end
        end
        
        function visualize(obj, robot_pose, readings)
            % Visualize sensor positions and readings
            
            figure('Name', 'TCRT5000 Sensor Readings', ...
                   'NumberTitle', 'off', ...
                   'Position', [200, 200, 600, 400]);
            
            % Robot body (circle)
            theta = linspace(0, 2*pi, 50);
            robot_x = robot_pose(1) + 0.05 * cos(theta);
            robot_y = robot_pose(2) + 0.05 * sin(theta);
            
            % Rotation matrix
            R = [cos(robot_pose(3)), -sin(robot_pose(3));
                 sin(robot_pose(3)),  cos(robot_pose(3))];
            
            % Sensor positions in world frame
            sensor_x = zeros(obj.num_sensors, 1);
            sensor_y = zeros(obj.num_sensors, 1);
            for i = 1:obj.num_sensors
                pos = [robot_pose(1:2)' + R * obj.sensor_positions(i, :)']';
                sensor_x(i) = pos(1);
                sensor_y(i) = pos(2);
            end
            
            % Plot arena
            axis([robot_pose(1)-0.3, robot_pose(1)+0.3, robot_pose(2)-0.3, robot_pose(2)+0.3]);
            hold on;
            
            % Draw robot
            plot(robot_x, robot_y, 'b-', 'LineWidth', 2);
            
            % Draw heading indicator
            heading_x = robot_pose(1) + [0, 0.1*cos(robot_pose(3))];
            heading_y = robot_pose(2) + [0, 0.1*sin(robot_pose(3))];
            plot(heading_x, heading_y, 'b-', 'LineWidth', 3);
            
            % Draw sensors with color-coded readings
            for i = 1:obj.num_sensors
                color = [1-readings(i)/255, readings(i)/255, 0]; % Red-Yellow gradient
                scatter(sensor_x(i), sensor_y(i), 100, color, 'filled', 'MarkerEdgeColor', 'k');
                
                % Label
                text(sensor_x(i), sensor_y(i)+0.02, sprintf('S%d: %.1f', i, readings(i)), ...
                    'HorizontalAlignment', 'center', 'FontSize', 10);
            end
            
            hold off;
            grid on;
            axis equal;
            title('TCRT5000 Sensor Array Readings');
            xlabel('X (m)');
            ylabel('Y (m)');
            colorbar;
        end
        
        function [min_val, max_val] = getRange(obj)
            % Return typical sensor value range
            min_val = 0;
            max_val = 255;
        end
    end
end
