classdef RealisticFloor
    % RealisticFloor - Simulates a real-world floor surface with imperfections
    % Models dust particles, reflectivity variations, and texture noise
    % 
    % This class creates a digital representation of a realistic floor that
    % affects optical sensor readings and pheromone deposition
    
    properties
        % Spatial properties
        arena_width
        arena_height
        resolution
        
        % Floor texture data
        reflectivity_map
        dust_positions
        dust_intensities
        
        % Imperfection parameters
        imperfection_level
        reflectivity_base
        reflectivity_variation
    end
    
    methods
        function obj = RealisticFloor(params)
            % Constructor - Initialize realistic floor model
            
            obj.arena_width = params.arena_width;
            obj.arena_height = params.arena_height;
            obj.resolution = params.floor_resolution;
            obj.imperfection_level = params.floor_imperfection_level;
            obj.reflectivity_base = params.reflectivity_base;
            obj.reflectivity_variation = params.reflectivity_variation;
            
            % Generate floor surface
            obj = obj.generateReflectivityMap(params);
            obj = obj.generateDustParticles(params);
        end
        
        function obj = generateReflectivityMap(obj, params)
            % Generate procedural floor reflectivity map with imperfections
            
            % Grid dimensions
            nx = round(obj.arena_width / obj.resolution);
            ny = round(obj.arena_height / obj.resolution);
            
            % Initialize reflectivity map
            obj.reflectivity_map = zeros(ny, nx);
            
            % Base reflectivity (uniform)
            obj.reflectivity_map(:) = obj.reflectivity_base;
            
            % Add large-scale variations (waviness)
            [X, Y] = meshgrid(1:nx, 1:ny);
            large_scale = 0.5 * sin(X * 0.05) .* cos(Y * 0.03) + ...
                          0.3 * sin(X * 0.02 - Y * 0.04);
            obj.reflectivity_map = obj.reflectivity_map + ...
                large_scale * obj.reflectivity_variation * obj.imperfection_level;
            
            % Add medium-scale noise (surface texture)
            medium_noise = obj.imperfection_level * obj.reflectivity_variation * ...
                (randn(ny, nx) * 0.3 + ...
                 sin(X * 0.5 + Y * 0.3) * 0.2 + ...
                 cos(X * 0.2 - Y * 0.6) * 0.1);
            obj.reflectivity_map = obj.reflectivity_map + medium_noise;
            
            % Add small-scale grain (micro-imperfections)
            small_noise = obj.imperfection_level * 0.05 * randn(ny, nx);
            obj.reflectivity_map = obj.reflectivity_map + small_noise;
            
            % Add occasional scratches and marks
            num_scratches = round(obj.arena_width * obj.arena_height * 0.5);
            for i = 1:num_scratches
                x_start = randi(nx);
                y_start = randi(ny);
                length_scratch = randi(20) + 5;
                angle = rand * 2 * pi;
                
                for j = 1:length_scratch
                    x = round(x_start + j * cos(angle));
                    y = round(y_start + j * sin(angle));
                    
                    if x >= 1 && x <= nx && y >= 1 && y <= ny
                        obj.reflectivity_map(y, x) = obj.reflectivity_map(y, x) - ...
                            0.1 * rand;
                    end
                end
            end
            
            % Clamp reflectivity to valid range [0, 1]
            obj.reflectivity_map = max(0, min(1, obj.reflectivity_map));
        end
        
        function obj = generateDustParticles(obj, params)
            % Generate dust particles on the floor surface
            
            num_particles = round(params.dust_density * obj.arena_width * obj.arena_height);
            
            % Random positions
            obj.dust_positions = rand(num_particles, 2) .* ...
                [obj.arena_width, obj.arena_height];
            
            % Random intensities based on particle size and composition
            % Some particles are more reflective than others
            obj.dust_intensities = (0.3 + 0.7 * rand(num_particles, 1)) .* ...
                obj.imperfection_level;
        end
        
        function reflectivity = getReflectivity(obj, x, y)
            % Get reflectivity at a specific point (x, y)
            % Uses bilinear interpolation for sub-pixel accuracy
            
            % Convert world coordinates to pixel indices
            px = x / obj.resolution + 1;
            py = y / obj.resolution + 1;
            
            % Check bounds
            nx = size(obj.reflectivity_map, 2);
            ny = size(obj.reflectivity_map, 1);
            
            if px < 1 || px > nx || py < 1 || py > ny
                reflectivity = obj.reflectivity_base;
                return;
            end
            
            % Bilinear interpolation
            x1 = floor(px);
            y1 = floor(py);
            x2 = min(x1 + 1, nx);
            y2 = min(y1 + 1, ny);
            
            fx = px - x1;
            fy = py - y1;
            
            r11 = obj.reflectivity_map(y1, x1);
            r12 = obj.reflectivity_map(y2, x1);
            r21 = obj.reflectivity_map(y1, x2);
            r22 = obj.reflectivity_map(y2, x2);
            
            reflectivity = (1-fx)*(1-fy)*r11 + (1-fx)*fy*r12 + ...
                           fx*(1-fy)*r21 + fx*fy*r22;
        end
        
        function dust_reading = getDustReading(obj, x, y, sensor_range)
            % Get combined effect of dust particles within sensor range
            
            % Find dust particles within range
            distances = sqrt((obj.dust_positions(:,1) - x).^2 + ...
                            (obj.dust_positions(:,2) - y).^2);
            
            in_range = distances < sensor_range;
            
            if sum(in_range) == 0
                dust_reading = 0;
                return;
            end
            
            % Calculate weighted contribution from nearby dust
            weights = exp(-distances(in_range) / (sensor_range / 2));
            dust_reading = sum(obj.dust_intensities(in_range) .* weights);
            dust_reading = dust_reading / length(in_range);
        end
        
        function visualize(obj)
            % Visualize the floor surface
            
            figure('Name', 'Realistic Floor Surface', ...
                   'NumberTitle', 'off', ...
                   'Position', [100, 100, 800, 600]);
            
            % Main reflectivity map
            subplot(2, 2, 1);
            imagesc([0, obj.arena_width], [0, obj.arena_height], ...
                    obj.reflectivity_map);
            axis equal;
            colormap gray;
            colorbar;
            title('Floor Reflectivity Map');
            xlabel('X (m)');
            ylabel('Y (m)');
            
            % Dust particle distribution
            subplot(2, 2, 2);
            scatter(obj.dust_positions(:,1), obj.dust_positions(:,2), ...
                    5, obj.dust_intensities, 'filled');
            axis([0, obj.arena_width, 0, obj.arena_height]);
            colorbar;
            title('Dust Particle Distribution');
            xlabel('X (m)');
            ylabel('Y (m)');
            
            % Cross-section at y = arena_height/2
            subplot(2, 2, 3);
            y_slice = round(size(obj.reflectivity_map,1) / 2);
            x_vals = (1:size(obj.reflectivity_map,2)) * obj.resolution;
            plot(x_vals, obj.reflectivity_map(y_slice, :));
            title('Reflectivity Cross-Section (Y = middle)');
            xlabel('X (m)');
            ylabel('Reflectivity');
            grid on;
            
            % Histogram of reflectivity values
            subplot(2, 2, 4);
            histogram(obj.reflectivity_map(:), 50);
            title('Reflectivity Distribution');
            xlabel('Reflectivity');
            ylabel('Count');
            grid on;
            
            sgtitle('Realistic Floor Surface Model', 'FontSize', 14, 'FontWeight', 'bold');
        end
        
        function stats = getStatistics(obj)
            % Get statistical properties of the floor surface
            
            stats.mean_reflectivity = mean(obj.reflectivity_map(:));
            stats.std_reflectivity = std(obj.reflectivity_map(:));
            stats.min_reflectivity = min(obj.reflectivity_map(:));
            stats.max_reflectivity = max(obj.reflectivity_map(:));
            stats.num_dust_particles = size(obj.dust_positions, 1);
            stats.mean_dust_intensity = mean(obj.dust_intensities);
            stats.total_area = obj.arena_width * obj.arena_height;
        end
    end
end
