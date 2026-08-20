function saveResults(params, resultsIdeal, resultsReal, simData)
% Save simulation results to files
%
% Inputs:
%   params - Simulation parameters
%   resultsIdeal - Results from ideal sensing
%   resultsReal - Results from realistic sensing
%   simData - Full simulation data

    % Create results directory
    results_dir = 'results';
    if ~exist(results_dir, 'dir')
        mkdir(results_dir);
    end
    
    % 1. Save parameters
    save(fullfile(results_dir, 'parameters.mat'), 'params');
    fprintf('    Parameters saved to %s/parameters.mat\n', results_dir);
    
    % 2. Save results
    results = struct();
    results.ideal = resultsIdeal;
    results.realistic = resultsReal;
    results.comparison = struct();
    
    % Calculate comparison metrics
    results.comparison.trail_deviation_diff = ...
        resultsReal.avg_trail_deviation - resultsIdeal.avg_trail_deviation;
    results.comparison.trail_deviation_ratio = ...
        resultsReal.avg_trail_deviation / max(resultsIdeal.avg_trail_deviation, eps);
    results.comparison.search_time_diff = ...
        resultsReal.avg_search_time - resultsIdeal.avg_search_time;
    results.comparison.search_time_ratio = ...
        resultsReal.avg_search_time / max(resultsIdeal.avg_search_time, eps);
    results.comparison.success_rate_diff = ...
        resultsReal.success_rate - resultsIdeal.success_rate;
    
    save(fullfile(results_dir, 'results.mat'), 'results');
    fprintf('    Results saved to %s/results.mat\n', results_dir);
    
    % 3. Save simulation data
    simDataMinimal = struct();
    simDataMinimal.robot_path = simData.robot_path;
    simDataMinimal.sensor_history = simData.sensor_history;
    simDataMinimal.trail_deviations = simData.trail_deviations;
    simDataMinimal.mode = simData.mode;
    simDataMinimal.reached_target = simData.reached_target;
    simDataMinimal.search_time = simData.search_time;
    
    save(fullfile(results_dir, 'simData.mat'), 'simDataMinimal');
    fprintf('    Simulation data saved to %s/simData.mat\n', results_dir);
    
    % 4. Export CSV summary
    fid = fopen(fullfile(results_dir, 'results_summary.csv'), 'w');
    
    fprintf(fid, 'Metric,Ideal,Realistic,Difference,Ratio\n');
    
    % Trail deviation - handle zero ideal case
    if resultsIdeal.avg_trail_deviation > 0.0001
        dev_ratio = resultsReal.avg_trail_deviation / resultsIdeal.avg_trail_deviation;
        fprintf(fid, 'Trail Deviation (m),%.6f,%.6f,%.6f,%.2f\n', ...
            resultsIdeal.avg_trail_deviation, resultsReal.avg_trail_deviation, ...
            results.comparison.trail_deviation_diff, dev_ratio);
    else
        fprintf(fid, 'Trail Deviation (m),%.6f,%.6f,%.6f, N/A\n', ...
            resultsIdeal.avg_trail_deviation, resultsReal.avg_trail_deviation, ...
            results.comparison.trail_deviation_diff);
    end
    
    fprintf(fid, 'Trail Deviation Std (m),%.6f,%.6f,,\n', ...
        resultsIdeal.std_trail_deviation, resultsReal.std_trail_deviation);
    fprintf(fid, 'Search Time (s),%.4f,%.4f,%.4f,%.2f\n', ...
        resultsIdeal.avg_search_time, resultsReal.avg_search_time, ...
        results.comparison.search_time_diff, results.comparison.search_time_ratio);
    fprintf(fid, 'Success Rate,%.4f,%.4f,%.4f,\n', ...
        resultsIdeal.success_rate, resultsReal.success_rate, ...
        results.comparison.success_rate_diff);
    fprintf(fid, 'Path Efficiency,%.4f,%.4f,,\n', ...
        resultsIdeal.path_efficiency, resultsReal.path_efficiency);
    fprintf(fid, 'Path Length (m),%.4f,%.4f,,\n', ...
        resultsIdeal.path_length, resultsReal.path_length);
    
    if isfield(resultsIdeal, 'avg_sensor_reading')
        fprintf(fid, 'Avg Sensor Reading,%.2f,%.2f,,\n', ...
            resultsIdeal.avg_sensor_reading, resultsReal.avg_sensor_reading);
        fprintf(fid, 'Std Sensor Reading,%.2f,%.2f,,\n', ...
            resultsIdeal.std_sensor_reading, resultsReal.std_sensor_reading);
    end
    
    fclose(fid);
    fprintf('    CSV summary saved to %s/results_summary.csv\n', results_dir);
    
    % 5. Generate text report
    fid = fopen(fullfile(results_dir, 'report.txt'), 'w');
    
    fprintf(fid, '=============================================================\n');
    fprintf(fid, 'Real-Space Optical Pheromone Exchange Simulation Report\n');
    fprintf(fid, '=============================================================\n');
    fprintf(fid, '\n');
    fprintf(fid, 'Simulation Parameters:\n');
    fprintf(fid, '  Arena Size: %.1f x %.1f m\n', params.arena_width, params.arena_height);
    fprintf(fid, '  Simulation Time: %.1f s\n', params.sim_time);
    fprintf(fid, '  Time Step: %.3f s\n', params.dt);
    fprintf(fid, '  Robot Radius: %.3f m\n', params.robot_radius);
    fprintf(fid, '  Max Speed: %.2f m/s\n', params.max_speed);
    fprintf(fid, '\n');
    fprintf(fid, 'Floor Model Parameters:\n');
    fprintf(fid, '  Resolution: %.4f m\n', params.floor_resolution);
    fprintf(fid, '  Imperfection Level: %.2f\n', params.floor_imperfection_level);
    fprintf(fid, '  Dust Density: %.0f particles/m^2\n', params.dust_density);
    fprintf(fid, '\n');
    fprintf(fid, 'Sensor Parameters (TCRT5000):\n');
    fprintf(fid, '  Number of Sensors: %d\n', params.num_sensors);
    fprintf(fid, '  Sensor Spacing: %.3f m\n', params.sensor_spacing);
    fprintf(fid, '  Noise Level: %.4f\n', params.sensor_noise);
    fprintf(fid, '  Crosstalk Factor: %.4f\n', params.sensor_crosstalk);
    fprintf(fid, '\n');
    fprintf(fid, 'Pheromone Parameters (WS2812B):\n');
    fprintf(fid, '  LED Intensity: %d\n', params.led_intensity);
    fprintf(fid, '  Spot Size: %.3f m\n', params.led_spot_size);
    fprintf(fid, '  Decay Rate: %.4f /s\n', params.decay_rate);
    fprintf(fid, '\n');
    fprintf(fid, '=============================================================\n');
    fprintf(fid, 'Performance Comparison\n');
    fprintf(fid, '=============================================================\n');
    fprintf(fid, '\n');
    fprintf(fid, 'Trail Deviation:\n');
    fprintf(fid, '  Ideal:      %.4f m (std: %.4f m)\n', ...
        resultsIdeal.avg_trail_deviation, resultsIdeal.std_trail_deviation);
    fprintf(fid, '  Realistic:  %.4f m (std: %.4f m)\n', ...
        resultsReal.avg_trail_deviation, resultsReal.std_trail_deviation);
    fprintf(fid, '  Increase:   %.1f%%\n', ...
        (results.comparison.trail_deviation_ratio - 1) * 100);
    fprintf(fid, '\n');
    fprintf(fid, 'Search Time:\n');
    fprintf(fid, '  Ideal:      %.2f s\n', resultsIdeal.avg_search_time);
    fprintf(fid, '  Realistic:  %.2f s\n', resultsReal.avg_search_time);
    fprintf(fid, '  Increase:   %.1f%%\n', ...
        (results.comparison.search_time_ratio - 1) * 100);
    fprintf(fid, '\n');
    fprintf(fid, 'Success Rate:\n');
    fprintf(fid, '  Ideal:      %.0f%%\n', resultsIdeal.success_rate * 100);
    fprintf(fid, '  Realistic:  %.0f%%\n', resultsReal.success_rate * 100);
    fprintf(fid, '\n');
    fprintf(fid, 'Path Efficiency:\n');
    fprintf(fid, '  Ideal:      %.1f%%\n', resultsIdeal.path_efficiency * 100);
    fprintf(fid, '  Realistic:  %.1f%%\n', resultsReal.path_efficiency * 100);
    fprintf(fid, '\n');
    fprintf(fid, 'Path Length:\n');
    fprintf(fid, '  Ideal:      %.2f m\n', resultsIdeal.path_length);
    fprintf(fid, '  Realistic:  %.2f m\n', resultsReal.path_length);
    fprintf(fid, '\n');
    
    if isfield(resultsReal, 'avg_sensor_reading')
        fprintf(fid, 'Sensor Statistics (Realistic Mode):\n');
        fprintf(fid, '  Average Reading: %.2f\n', resultsReal.avg_sensor_reading);
        fprintf(fid, '  Std Deviation:   %.2f\n', resultsReal.std_sensor_reading);
        if isfield(resultsReal, 'min_sensor_reading')
            fprintf(fid, '  Min Reading:     %.2f\n', resultsReal.min_sensor_reading);
            fprintf(fid, '  Max Reading:     %.2f\n', resultsReal.max_sensor_reading);
        end
        fprintf(fid, '\n');
    end
    
    fprintf(fid, '=============================================================\n');
    fprintf(fid, 'Key Findings\n');
    fprintf(fid, '=============================================================\n');
    fprintf(fid, '\n');
    
    dev_increase = results.comparison.trail_deviation_diff;
    if dev_increase > 0.005
        fprintf(fid, '1. Under realistic conditions, trail deviation increased by %.2f mm.\n', dev_increase * 1000);
    else
        fprintf(fid, '1. Realistic sensing has minimal impact on trail deviation (%.2f mm increase).\n', dev_increase * 1000);
    end
    
    if ~isnan(results.comparison.search_time_ratio) && results.comparison.search_time_ratio > 1.1
        fprintf(fid, '2. Navigation search time increases by %.1f%% with realistic sensors.\n', ...
            (results.comparison.search_time_ratio - 1) * 100);
    else
        fprintf(fid, '2. Navigation performance remains similar with realistic sensors.\n');
    end
    
    if resultsReal.success_rate < resultsIdeal.success_rate
        fprintf(fid, '3. Success rate decreases by %.0f%% due to sensor limitations.\n', ...
            (resultsIdeal.success_rate - resultsReal.success_rate) * 100);
    else
        fprintf(fid, '3. Success rate is maintained at 100%% with realistic sensors.\n');
    end
    
    if isfield(resultsReal, 'chemical_activated') && resultsReal.chemical_activated
        fprintf(fid, '4. Chemical backup system was activated to complete navigation.\n');
    end
    
    fprintf(fid, '\n');
    fprintf(fid, 'Generated: %s\n', datestr(now));
    fprintf(fid, '\n');
    
    fclose(fid);
    fprintf('    Text report saved to %s/report.txt\n', results_dir);
    
    fprintf('    All results exported successfully.\n');
end
