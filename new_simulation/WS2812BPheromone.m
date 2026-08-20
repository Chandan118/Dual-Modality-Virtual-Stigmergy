classdef WS2812BPheromone
    % WS2812BPheromone - Models WS2812B RGB LED pheromone deposition
    % 
    % This class simulates how WS2812B LEDs deposit a light pattern on the
    % floor surface, which can be detected by TCRT5000 sensors. The LED has
    % a finite spot size and can overlap with other trails.
    %
    % WS2812B Specifications:
    %   - Operating voltage: 5V
    %   - RGB full color (using red for pheromone simulation)
    %   - 800kHz communication
    %   - 5050 SMD package
    
    properties
        % LED parameters
        led_intensity
        spot_size              % LED spot diameter (meters)
        wavelength = 625e-9;  % Red LED wavelength
        
        % Deposition parameters
        max_intensity
        overlap_method         % How to handle overlapping trails
        
        % Spatial resolution
        resolution
        
        % Current trail data
        trail_points
        trail_intensities
        trail_timestamps
    end
    
    methods
        function obj = WS2812BPheromone(params)
            % Constructor
            
            obj.led_intensity = params.led_intensity;
            obj.spot_size = params.led_spot_size;
            obj.max_intensity = params.max_trail_intensity;
            obj.overlap_method = params.overlap_method;
            obj.resolution = params.floor_resolution;
            
            % Initialize trail storage
            obj.trail_points = zeros(0, 2);
            obj.trail_intensities = zeros(0, 1);
            obj.trail_timestamps = zeros(0, 1);
        end
        
        function obj = deposit(obj, position, intensity, timestamp)
            % Deposit pheromone trail at a position
            %
            % Inputs:
            %   position - [x, y] world coordinates
            %   intensity - Trail intensity (0-255)
            %   timestamp - Current simulation time
            
            % Scale intensity based on LED settings
            effective_intensity = floor(intensity * (obj.led_intensity / 255));
            effective_intensity = max(0, min(255, effective_intensity));
            
            % Store trail point
            obj.trail_points(end+1, :) = position;
            obj.trail_intensities(end+1, 1) = effective_intensity;
            obj.trail_timestamps(end+1, 1) = timestamp;
        end
        
        function intensity = getIntensityAtPosition(obj, x, y, timestamp, decay_rate)
            % Get pheromone intensity at a specific position
            % Considers trail overlap and decay
            %
            % Inputs:
            %   x, y - World coordinates
            %   timestamp - Current time
            %   decay_rate - Trail decay rate (per second)
            %
            % Output:
            %   intensity - Combined pheromone intensity (0-255)
            
            if isempty(obj.trail_points)
                intensity = 0;
                return;
            end
            
            % Calculate distances from query point to all trail points
            distances = sqrt((obj.trail_points(:,1) - x).^2 + ...
                            (obj.trail_points(:,2) - y).^2);
            
            % Find trail points within the LED spot size
            in_range = distances <= obj.spot_size / 2;
            
            if sum(in_range) == 0
                intensity = 0;
                return;
            end
            
            % Apply decay to each trail point
            ages = timestamp - obj.trail_timestamps(in_range);
            decayed_intensities = obj.trail_intensities(in_range) .* ...
                                   exp(-decay_rate * ages);
            
            % Combine overlapping contributions
            switch obj.overlap_method
                case 'max_intensity'
                    % Use the strongest trail (max blending)
                    intensity = max(decayed_intensities);
                    
                case 'additive'
                    % Sum all contributions (with saturation)
                    intensity = sum(decayed_intensities);
                    intensity = min(intensity, obj.max_intensity);
                    
                case 'average'
                    % Average all contributions
                    intensity = mean(decayed_intensities);
                    
                otherwise
                    % Default to max intensity
                    intensity = max(decayed_intensities);
            end
            
            % Apply spatial falloff within spot
            if strcmp(obj.overlap_method, 'additive')
                % Already handled by spot size filtering
            else
                % For max/average, apply distance-based falloff
                relevant_distances = distances(in_range);
                falloff = 1 - (relevant_distances / (obj.spot_size / 2));
                falloff = max(0, falloff);
                
                if strcmp(obj.overlap_method, 'max_intensity')
                    [~, max_idx] = max(decayed_intensities);
                    intensity = intensity * falloff(max_idx);
                else
                    intensity = intensity * mean(falloff);
                end
            end
        end
        
        function obj = decayTrails(obj, current_time, decay_rate)
            % Remove expired trail points to save memory
            % Keep points with significant intensity
            
            if isempty(obj.trail_points)
                return;
            end
            
            % Calculate current intensities
            ages = current_time - obj.trail_timestamps;
            remaining = obj.trail_intensities .* exp(-decay_rate * ages);
            
            % Keep points with intensity > 5
            keep = remaining > 5;
            
            obj.trail_points = obj.trail_points(keep, :);
            obj.trail_intensities = obj.trail_intensities(keep);
            obj.trail_timestamps = obj.trail_timestamps(keep);
        end
        
        function obj = clearTrails(obj)
            % Clear all deposited trails
            obj.trail_points = zeros(0, 2);
            obj.trail_intensities = zeros(0, 1);
            obj.trail_timestamps = zeros(0, 1);
        end
        
        function [grid, x_coords, y_coords] = toGrid(obj, arena_width, arena_height, timestamp, decay_rate)
            % Convert trail data to a grid for visualization
            %
            % Output:
            %   grid - 2D matrix of pheromone intensities
            %   x_coords, y_coords - Grid coordinates
            
            nx = round(arena_width / obj.resolution);
            ny = round(arena_height / obj.resolution);
            
            x_coords = linspace(0, arena_width, nx);
            y_coords = linspace(0, arena_height, ny);
            
            grid = zeros(ny, nx);
            
            for i = 1:nx
                for j = 1:ny
                    grid(j, i) = obj.getIntensityAtPosition(...
                        x_coords(i), y_coords(j), timestamp, decay_rate);
                end
            end
        end
        
        function visualize(obj, arena_width, arena_height, timestamp, decay_rate)
            % Visualize the pheromone trail map
            
            [grid, x_coords, y_coords] = obj.toGrid(arena_width, arena_height, timestamp, decay_rate);
            
            figure('Name', 'Pheromone Trail Map', ...
                   'NumberTitle', 'off', ...
                   'Position', [150, 150, 700, 600]);
            
            imagesc(x_coords, y_coords, grid);
            axis equal;
            colormap hot;
            colorbar;
            title(sprintf('Pheromone Trail Map (t=%.1f s)', timestamp));
            xlabel('X (m)');
            ylabel('Y (m)');
            
            % Overlay trail points
            if ~isempty(obj.trail_points)
                hold on;
                scatter(obj.trail_points(:,1), obj.trail_points(:,2), ...
                        3, obj.trail_intensities, 'MarkerEdgeColor', 'none');
                hold off;
            end
        end
        
        function stats = getStatistics(obj)
            % Get trail statistics
            
            stats.num_points = size(obj.trail_points, 1);
            
            if stats.num_points > 0
                stats.mean_intensity = mean(obj.trail_intensities);
                stats.max_intensity = max(obj.trail_intensities);
                stats.min_intensity = min(obj.trail_intensities);
                stats.std_intensity = std(obj.trail_intensities);
                
                % Trail coverage
                if stats.num_points > 1
                    distances = sqrt(diff(obj.trail_points(:,1)).^2 + ...
                                   diff(obj.trail_points(:,2)).^2);
                    stats.total_length = sum(distances);
                    stats.mean_spacing = mean(distances);
                else
                    stats.total_length = 0;
                    stats.mean_spacing = 0;
                end
            else
                stats.mean_intensity = 0;
                stats.max_intensity = 0;
                stats.min_intensity = 0;
                stats.std_intensity = 0;
                stats.total_length = 0;
                stats.mean_spacing = 0;
            end
        end
    end
end
