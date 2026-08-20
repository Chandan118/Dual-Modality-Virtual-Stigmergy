classdef PheromoneMap < handle
    % PheromoneMap - Combined pheromone trail management
    % 
    % This class provides a unified interface for pheromone trail operations
    % including deposition, sensing, and grid-based queries.
    
    properties
        % Reference to WS2812B pheromone model
        pheromone_model
        
        % Simulation parameters
        params
        
        % Grid-based cache for fast queries
        use_cache
        cache_valid
        cache_timestamp
        cache_grid
        cache_resolution
    end
    
    methods
        function obj = PheromoneMap(params)
            % Constructor
            
            obj.params = params;
            obj.pheromone_model = WS2812BPheromone(params);
            obj.use_cache = true;
            obj.cache_valid = false;
            obj.cache_timestamp = -1;
            obj.cache_resolution = params.floor_resolution * 2; % Half resolution for speed
        end
        
        function obj = deposit(obj, position, intensity, timestamp)
            % Deposit pheromone at a position
            
            obj.pheromone_model = obj.pheromone_model.deposit(position, intensity, timestamp);
            obj.cache_valid = false; % Invalidate cache
        end
        
        function intensity = getIntensity(obj, x, y)
            % Get pheromone intensity at a position (uses cache if available)
            %
            % This is the main interface for sensor readings
            
            persistent last_timestamp;
            persistent last_decay_rate;
            
            if isempty(last_timestamp)
                last_timestamp = -1;
                last_decay_rate = 0;
            end
            
            % Get current time from global simulation time
            % For simplicity, we'll query directly from the model
            intensity = obj.pheromone_model.getIntensityAtPosition(...
                x, y, obj.cache_timestamp, obj.params.decay_rate);
        end
        
        function obj = updateTime(obj, timestamp)
            % Update the simulation time reference for caching
            
            if abs(timestamp - obj.cache_timestamp) > 0.1
                obj.cache_timestamp = timestamp;
                obj.cache_valid = false;
            end
        end
        
        function obj = decay(obj, current_time)
            % Apply decay to all trails
            
            obj.pheromone_model = obj.pheromone_model.decayTrails(current_time, obj.params.decay_rate);
        end
        
        function obj = clear(obj)
            % Clear all trails
            
            obj.pheromone_model = obj.pheromone_model.clearTrails();
            obj.cache_valid = false;
        end
        
        function visualize(obj, timestamp)
            % Visualize the pheromone map
            
            obj.pheromone_model.visualize(...
                obj.params.arena_width, obj.params.arena_height, ...
                timestamp, obj.params.decay_rate);
        end
        
        function stats = getStatistics(obj)
            % Get trail statistics
            
            stats = obj.pheromone_model.getStatistics();
        end
    end
end
