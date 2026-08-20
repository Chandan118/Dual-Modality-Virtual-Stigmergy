classdef ChemicalGradientSensor
    % ChemicalGradientSensor - Models chemical gradient sensing backup system
    % 
    % This class simulates the chemical sensing backup system that activates
    % when optical pheromone sensing fails due to low SNR.
    %
    % Based on your paper's dual-modality architecture:
    %   - Primary: Optical (TCRT5000 + WS2812B LED)
    %   - Backup: Chemical gradient sensing
    %   - Switchover threshold: 6 dB SNR
    %   - Switchover latency: 2.1 seconds
    
    properties
        % Sensor parameters
        gradient_sensitivity = 0.1;    % Sensitivity to chemical gradient
        noise_level = 0.02;          % Much lower noise than optical
        sampling_rate = 10;           % Hz
        
        % Chemical parameters
        diffusion_coefficient = 0.001; % m^2/s
        source_concentration = 100;   % Arbitrary units
        background_concentration = 5; % Background noise
        
        % State
        current_gradient_direction
        current_concentration
        sensor_history
        history_length = 10;
    end
    
    methods
        function obj = ChemicalGradientSensor(params)
            % Constructor
            
            if nargin > 0 && isfield(params, 'chemical_sensitivity')
                obj.gradient_sensitivity = params.chemical_sensitivity;
            end
            if nargin > 0 && isfield(params, 'chemical_noise')
                obj.noise_level = params.chemical_noise;
            end
            
            obj.sensor_history = zeros(1, obj.history_length);
        end
        
        function [direction, concentration, snr] = senseChemicalGradient(obj, ...
                robot_pose, chemical_source_pos, current_time)
            % Sense chemical gradient and return direction to source
            %
            % Inputs:
            %   robot_pose - [x, y, theta] robot position
            %   chemical_source_pos - [x, y] position of chemical source
            %   current_time - simulation time
            %
            % Outputs:
            %   direction - angle to chemical source (relative to robot heading)
            %   concentration - local chemical concentration
            %   snr - signal-to-noise ratio in dB
            
            % Calculate vector to source
            dx = chemical_source_pos(1) - robot_pose(1);
            dy = chemical_source_pos(2) - robot_pose(2);
            distance = sqrt(dx^2 + dy^2);
            
            % Calculate angle to source (world frame)
            angle_to_source = atan2(dy, dx);
            
            % Robot heading
            heading = robot_pose(3);
            
            % Direction relative to robot (what the robot should turn)
            direction = obj.normalizeAngle(angle_to_source - heading);
            
            % Calculate concentration based on distance (inverse square law with diffusion)
            % C = C0 / (4*pi*D*r) for point source diffusion
            if distance > 0.01 % Avoid division by zero
                concentration = obj.source_concentration / (4 * pi * obj.diffusion_coefficient * distance);
            else
                concentration = obj.source_concentration;
            end
            
            % Add background
            concentration = concentration + obj.background_concentration;
            
            % Add very low noise (chemical sensing is more stable)
            concentration = concentration * (1 + obj.noise_level * randn);
            
            % Update history
            obj.sensor_history = [obj.sensor_history(2:end), concentration];
            
            % Calculate SNR
            signal = concentration - obj.background_concentration;
            noise = obj.noise_level * obj.background_concentration;
            if noise > 0
                snr = 20 * log10(signal / noise);
            else
                snr = 60; % Very high SNR if no noise
            end
        end
        
        function [direction, confidence] = followGradient(obj, sensor_readings)
            % Follow chemical gradient to navigate
            %
            % Outputs:
            %   direction - turn direction (positive = right, negative = left)
            %   confidence - confidence in gradient direction (0-1)
            
            if length(sensor_readings) < 3
                direction = 0;
                confidence = 0;
                return;
            end
            
            % Use left, center, right "sensors" for gradient detection
            left = sensor_readings(1);
            center = sensor_readings(2);
            right = sensor_readings(3);
            
            % Gradient direction
            gradient = (right - left) / max(center, 1);
            
            % Normalize to [-1, 1]
            direction = tanh(gradient * obj.gradient_sensitivity);
            
            % Confidence based on gradient strength
            gradient_strength = abs(right - left) / max(center, 1);
            confidence = min(gradient_strength * 5, 1); % 0-1 scale
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
        
        function avg_concentration = getAverageConcentration(obj)
            % Get average concentration from history
            avg_concentration = mean(obj.sensor_history);
        end
        
        function trend = getConcentrationTrend(obj)
            % Get trend (increasing/decreasing) from history
            if length(obj.sensor_history) < 5
                trend = 0;
                return;
            end
            
            % Linear fit slope
            x = 1:length(obj.sensor_history);
            y = obj.sensor_history;
            trend = (length(x) * sum(x.*y) - sum(x)*sum(y)) / ...
                    (length(x)*sum(x.^2) - sum(x)^2);
        end
    end
end
