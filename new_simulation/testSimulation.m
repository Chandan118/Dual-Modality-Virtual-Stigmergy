function testSimulation()
% testSimulation - Test individual simulation components
%
% This script tests each component of the simulation to ensure they work
% correctly before running the full simulation.
%

        fprintf('Testing Real-Space Pheromone Simulation Components\n');
    fprintf('=============================================================\n\n');

    %% Test 1: Realistic Floor
    fprintf('TEST 1: Realistic Floor Model\n');
    fprintf('---------------------------\n');
    try
        params.floor_resolution = 0.01;
        params.floor_imperfection_level = 0.3;
        params.dust_density = 500;
        params.reflectivity_base = 0.8;
        params.reflectivity_variation = 0.15;
        params.arena_width = 5;
        params.arena_height = 5;
        
        floor = RealisticFloor(params);
        
        % Test reflectivity query
        refl = floor.getReflectivity(2.5, 2.5);
        fprintf('  Floor created successfully\n');
        fprintf('  - Size: %.1f x %.1f m\n', floor.arena_width, floor.arena_height);
        fprintf('  - Resolution: %.3f m\n', floor.resolution);
        fprintf('  - Reflectivity at center: %.3f\n', refl);
        fprintf('  - Dust particles: %d\n', length(floor.dust_positions));
        
        stats = floor.getStatistics();
        fprintf('  - Mean reflectivity: %.3f\n', stats.mean_reflectivity);
        fprintf('  - Std reflectivity: %.3f\n', stats.std_reflectivity);
        
        fprintf('\n  [PASS] Realistic Floor Model\n\n');
    catch ME
        fprintf('\n  [FAIL] Realistic Floor Model: %s\n', ME.message);
        disp(ME.stack);
    end

    %% Test 2: TCRT5000 Sensor Array
    fprintf('TEST 2: TCRT5000 Sensor Array\n');
    fprintf('-------------------------------\n');
    try
        params.num_sensors = 4;
        params.sensor_spacing = 0.012;
        params.sensor_range = 0.05;
        params.sensor_noise = 0.05;
        params.sensor_crosstalk = 0.1;
        params.enable_crosstalk = true;
        params.dt = 0.01;
        
        sensors = TCRT5000SensorArray(params);
        
        % Create minimal pheromone model for testing
        pm_params = params;
        pm_params.led_intensity = 255;
        pm_params.led_spot_size = 0.02;
        pm_params.max_trail_intensity = 255;
        pm_params.decay_rate = 0.02;
        pm_params.overlap_method = 'max_intensity';
        pm_params.floor_resolution = 0.01;
        
        % Create a minimal pheromone map
        pmap = PheromoneMap(pm_params);
        pmap.cache_timestamp = 0;
        
        % Test sensor reading
        robot_pose = [2.5, 2.5, 0];
        readings = sensors.readSensors(robot_pose, floor, pmap);
        
        fprintf('  Sensor array created successfully\n');
        fprintf('  - Number of sensors: %d\n', sensors.num_sensors);
        fprintf('  - Sensor spacing: %.3f m\n', sensors.spacing);
        fprintf('  - Noise level: %.4f\n', sensors.noise_level);
        fprintf('  - Sample readings: [%.1f, %.1f, %.1f, %.1f]\n', ...
            readings(1), readings(2), readings(3), readings(4));
        
        % Test trail direction estimation
        direction = sensors.estimateTrailDirection(readings);
        fprintf('  - Estimated trail direction: %.3f\n', direction);
        
        fprintf('\n  [PASS] TCRT5000 Sensor Array\n\n');
    catch ME
        fprintf('\n  [FAIL] TCRT5000 Sensor Array: %s\n', ME.message);
        disp(ME.stack);
    end

    %% Test 3: WS2812B Pheromone Model
    fprintf('TEST 3: WS2812B Pheromone Model\n');
    fprintf('----------------------------------\n');
    try
        pm_params.led_intensity = 255;
        pm_params.led_spot_size = 0.02;
        pm_params.max_trail_intensity = 255;
        pm_params.decay_rate = 0.02;
        pm_params.overlap_method = 'max_intensity';
        pm_params.floor_resolution = 0.01;
        
        pheromone = WS2812BPheromone(pm_params);
        
        % Deposit some trails
        pheromone = pheromone.deposit([1.0, 1.0], 200, 0);
        pheromone = pheromone.deposit([1.5, 1.5], 180, 0);
        pheromone = pheromone.deposit([2.0, 2.0], 150, 0);
        
        % Query intensity
        intensity = pheromone.getIntensityAtPosition(1.5, 1.5, 0, pm_params.decay_rate);
        
        fprintf('  Pheromone model created successfully\n');
        fprintf('  - LED intensity: %d\n', pheromone.led_intensity);
        fprintf('  - Spot size: %.3f m\n', pheromone.spot_size);
        fprintf('  - Trail points deposited: %d\n', length(pheromone.trail_points));
        fprintf('  - Intensity at (1.5, 1.5): %.1f\n', intensity);
        
        % Get statistics
        trail_stats = pheromone.getStatistics();
        fprintf('  - Total trail length: %.2f m\n', trail_stats.total_length);
        fprintf('  - Mean intensity: %.1f\n', trail_stats.mean_intensity);
        
        fprintf('\n  [PASS] WS2812B Pheromone Model\n\n');
    catch ME
        fprintf('\n  [FAIL] WS2812B Pheromone Model: %s\n', ME.message);
        disp(ME.stack);
    end

    %% Test 4: Navigation Controller
    fprintf('TEST 4: Navigation Controller\n');
    fprintf('-------------------------------\n');
    try
        params.max_speed = 0.2;
        params.turn_rate = 2.0;
        params.waypoint_threshold = 0.1;
        params.pheromone_threshold = 30;
        params.target_position = [4.5, 4.5];
        params.dt = 0.01;
        
        % Test ideal controller
        controller_ideal = NavigationController(params, 'ideal');
        controller_real = NavigationController(params, 'realistic');
        
        % Test wheel velocity computation
        robot_pose = [2.0, 2.0, 0];
        sensor_readings = [100, 120, 140, 160];
        
        % Create mock pheromone map
        pm_params = params;
        pm_params.led_intensity = 255;
        pm_params.led_spot_size = 0.02;
        pm_params.max_trail_intensity = 255;
        pm_params.decay_rate = 0.02;
        pm_params.overlap_method = 'max_intensity';
        pm_params.floor_resolution = 0.01;
        
        pmap = PheromoneMap(pm_params);
        pmap.cache_timestamp = 0;
        
        [v_l, v_r, trail_dev] = controller_ideal.computeWheelVelocities(robot_pose, sensor_readings, pmap);
        
        fprintf('  Navigation controllers created successfully\n');
        fprintf('  - Mode: ideal/realistic\n');
        fprintf('  - Max speed: %.2f m/s\n', params.max_speed);
        fprintf('  - Turn rate: %.2f rad/s\n', params.turn_rate);
        fprintf('  - Wheel velocities: v_l=%.4f, v_r=%.4f\n', v_l, v_r);
        fprintf('  - Trail deviation: %.4f m\n', trail_dev);
        
        fprintf('\n  [PASS] Navigation Controller\n\n');
    catch ME
        fprintf('\n  [FAIL] Navigation Controller: %s\n', ME.message);
        disp(ME.stack);
    end

    %% Test 5: Performance Comparator
    fprintf('TEST 5: Performance Comparator\n');
    fprintf('-------------------------------\n');
    try
        comparator = PerformanceComparator(params);
        
        % Create mock results
        results_ideal.avg_trail_deviation = 0.05;
        results_ideal.std_trail_deviation = 0.02;
        results_ideal.avg_search_time = 25.0;
        results_ideal.success_rate = 1.0;
        results_ideal.path_efficiency = 0.85;
        results_ideal.path_length = 7.5;
        
        results_real.avg_trail_deviation = 0.08;
        results_real.std_trail_deviation = 0.04;
        results_real.avg_search_time = 32.0;
        results_real.success_rate = 0.9;
        results_real.path_efficiency = 0.72;
        results_real.path_length = 8.8;
        
        comparator = comparator.compare(results_ideal, results_real);
        metrics = comparator.getMetrics();
        
        fprintf('  Performance comparator created successfully\n');
        fprintf('  - Trail deviation ratio: %.2fx\n', metrics.trail_deviation_ratio);
        fprintf('  - Search time ratio: %.2fx\n', metrics.search_time_ratio);
        fprintf('  - Success rate diff: %.1f%%\n', metrics.success_rate_diff * 100);
        
        fprintf('\n  [PASS] Performance Comparator\n\n');
    catch ME
        fprintf('\n  [FAIL] Performance Comparator: %s\n', ME.message);
        disp(ME.stack);
    end

    %% Summary
        fprintf('Component Test Summary\n');
        fprintf('All core components have been tested.\n');
    fprintf('Ready to run full simulation.\n');
    fprintf('\n');
    fprintf('To run the full simulation, execute:\n');
    fprintf('  RealSpace_Pheromone_Simulation\n');
    fprintf('\n');
    
end
