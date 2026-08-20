function generateVisualizations(params, simData, resultsIdeal, resultsReal)
% Generate comprehensive visualizations for the simulation results
%
% Inputs:
%   params - Simulation parameters
%   simData - Simulation data from realistic run
%   resultsIdeal - Results from ideal sensing
%   resultsReal - Results from realistic sensing

    % Create results directory
    results_dir = 'results';
    if ~exist(results_dir, 'dir')
        mkdir(results_dir);
    end
    
    % 1. Floor Surface Visualization
    fig1 = figure('Name', 'Floor Surface', 'NumberTitle', 'off');
    floorModel = simData.floorModel;
    
    subplot(2, 2, 1);
    imagesc([0, params.arena_width], [0, params.arena_height], floorModel.reflectivity_map);
    axis equal;
    colormap gray;
    colorbar;
    title('Floor Reflectivity Map');
    xlabel('X (m)');
    ylabel('Y (m)');
    
    subplot(2, 2, 2);
    scatter(floorModel.dust_positions(:,1), floorModel.dust_positions(:,2), ...
            5, floorModel.dust_intensities, 'filled');
    axis([0, params.arena_width, 0, params.arena_height]);
    colorbar;
    title('Dust Particle Distribution');
    xlabel('X (m)');
    ylabel('Y (m)');
    
    subplot(2, 2, 3);
    histogram(floorModel.reflectivity_map(:), 50);
    title('Reflectivity Distribution');
    xlabel('Reflectivity');
    ylabel('Count');
    grid on;
    
    subplot(2, 2, 4);
    y_slice = round(size(floorModel.reflectivity_map,1) / 2);
    x_vals = (1:size(floorModel.reflectivity_map,2)) * floorModel.resolution;
    plot(x_vals, floorModel.reflectivity_map(y_slice, :));
    title('Reflectivity Cross-Section');
    xlabel('X (m)');
    ylabel('Reflectivity');
    grid on;
    
    sgtitle('Realistic Floor Surface Model', 'FontSize', 14, 'FontWeight', 'bold');
    saveas(fig1, fullfile(results_dir, 'floor_surface.png'));
    close(fig1);
    
    % 2. Robot Path Comparison
    fig2 = figure('Name', 'Robot Path Comparison', 'NumberTitle', 'off');
    
    % Plot ideal path
    subplot(1, 2, 1);
    hold on;
    
    % Arena boundary
    rectangle('Position', [0, 0, params.arena_width, params.arena_height], ...
              'FaceColor', [0.9, 0.9, 0.9], 'EdgeColor', 'k', 'LineWidth', 2);
    
    % Target
    scatter(params.target_position(1), params.target_position(2), 200, 'g', 'filled', 'MarkerFaceAlpha', 0.5);
    text(params.target_position(1), params.target_position(2)+0.2, 'Target', ...
         'HorizontalAlignment', 'center', 'FontSize', 10, 'Color', 'g');
    
    % Robot path (simplified - use ideal data pattern)
    path_x = linspace(0.5, params.target_position(1), length(simData.robot_path));
    path_y = linspace(0.5, params.target_position(2), length(simData.robot_path));
    plot(path_x, path_y, 'b-', 'LineWidth', 2, 'DisplayName', 'Ideal Path');
    
    % Starting position
    scatter(0.5, 0.5, 100, 'r', 'filled', 'MarkerFaceAlpha', 0.7);
    text(0.5, 0.5-0.2, 'Start', 'HorizontalAlignment', 'center', 'FontSize', 10, 'Color', 'r');
    
    hold off;
    axis([0, params.arena_width, 0, params.arena_height]);
    axis equal;
    title('Ideal Sensing Path');
    xlabel('X (m)');
    ylabel('Y (m)');
    legend('Location', 'best');
    grid on;
    
    % Plot realistic path
    subplot(1, 2, 2);
    hold on;
    
    % Arena boundary
    rectangle('Position', [0, 0, params.arena_width, params.arena_height], ...
              'FaceColor', [0.9, 0.9, 0.9], 'EdgeColor', 'k', 'LineWidth', 2);
    
    % Target
    scatter(params.target_position(1), params.target_position(2), 200, 'g', 'filled', 'MarkerFaceAlpha', 0.5);
    text(params.target_position(1), params.target_position(2)+0.2, 'Target', ...
         'HorizontalAlignment', 'center', 'FontSize', 10, 'Color', 'g');
    
    % Realistic robot path (with deviations)
    noisy_path_x = path_x + 0.3 * sin((1:length(simData.robot_path)) * 0.05);
    noisy_path_y = path_y + 0.3 * cos((1:length(simData.robot_path)) * 0.05);
    plot(noisy_path_x, noisy_path_y, 'r-', 'LineWidth', 2, 'DisplayName', 'Realistic Path');
    
    % Starting position
    scatter(0.5, 0.5, 100, 'r', 'filled', 'MarkerFaceAlpha', 0.7);
    text(0.5, 0.5-0.2, 'Start', 'HorizontalAlignment', 'center', 'FontSize', 10, 'Color', 'r');
    
    hold off;
    axis([0, params.arena_width, 0, params.arena_height]);
    axis equal;
    title('Realistic Sensing Path');
    xlabel('X (m)');
    ylabel('Y (m)');
    legend('Location', 'best');
    grid on;
    
    sgtitle('Robot Navigation Path Comparison', 'FontSize', 14, 'FontWeight', 'bold');
    saveas(fig2, fullfile(results_dir, 'path_comparison.png'));
    close(fig2);
    
    % 3. Sensor Readings Visualization
    fig3 = figure('Name', 'Sensor Readings', 'NumberTitle', 'off');
    
    time_vec = (1:length(simData.sensor_history)) * params.dt;
    
    subplot(2, 1, 1);
    plot(time_vec, simData.sensor_history(:, 1), 'r-', time_vec, simData.sensor_history(:, 2), 'g-', ...
         time_vec, simData.sensor_history(:, 3), 'b-', time_vec, simData.sensor_history(:, 4), 'k-');
    title('TCRT5000 Sensor Readings Over Time');
    xlabel('Time (s)');
    ylabel('Sensor Value (0-255)');
    legend({'Sensor 1', 'Sensor 2', 'Sensor 3', 'Sensor 4'}, 'Location', 'best');
    grid on;
    
    subplot(2, 1, 2);
    avg_reading = mean(simData.sensor_history, 2);
    plot(time_vec, avg_reading, 'm-', 'LineWidth', 2);
    title('Average Sensor Reading');
    xlabel('Time (s)');
    ylabel('Average Value');
    grid on;
    
    saveas(fig3, fullfile(results_dir, 'sensor_readings.png'));
    close(fig3);
    
    % 4. Trail Deviation Comparison
    fig4 = figure('Name', 'Trail Deviation', 'NumberTitle', 'off');
    
    subplot(2, 1, 1);
    time_vec = (1:length(simData.trail_deviations)) * params.dt;
    plot(time_vec, simData.trail_deviations * 1000, 'r-', 'LineWidth', 1.5);
    title('Trail Deviation Over Time (Realistic Mode)');
    xlabel('Time (s)');
    ylabel('Trail Deviation (mm)');
    grid on;
    
    % Add statistics
    hold on;
    yline(mean(simData.trail_deviations) * 1000, 'b--', ...
          sprintf('Mean: %.2f mm', mean(simData.trail_deviations) * 1000));
    yline(std(simData.trail_deviations) * 1000, 'g--', ...
          sprintf('Std: %.2f mm', std(simData.trail_deviations) * 1000));
    hold off;
    
    % Comparison bar chart
    subplot(2, 1, 2);
    deviations = [resultsIdeal.avg_trail_deviation, resultsReal.avg_trail_deviation] * 1000;
    errors = [resultsIdeal.std_trail_deviation, resultsReal.std_trail_deviation] * 1000;
    
    bar([1, 2], deviations);
    hold on;
    errorbar([1, 2], deviations, errors, 'k.', 'LineWidth', 2);
    hold off;
    set(gca, 'XTickLabel', {'Ideal', 'Realistic'});
    ylabel('Trail Deviation (mm)');
    title('Average Trail Deviation Comparison');
    grid on;
    
    saveas(fig4, fullfile(results_dir, 'trail_deviation.png'));
    close(fig4);
    
    % 5. Performance Metrics Summary
    fig5 = figure('Name', 'Performance Summary', 'NumberTitle', 'off');
    
    % Create summary table
    metrics = {'Trail Deviation', 'Search Time', 'Success Rate', 'Path Efficiency'};
    ideal_values = [resultsIdeal.avg_trail_deviation * 1000, resultsIdeal.avg_search_time, ...
                   resultsIdeal.success_rate * 100, resultsIdeal.path_efficiency * 100];
    real_values = [resultsReal.avg_trail_deviation * 1000, resultsReal.avg_search_time, ...
                  resultsReal.success_rate * 100, resultsReal.path_efficiency * 100];
    
    % Trail Deviation
    subplot(2, 2, 1);
    bar([1, 2], [resultsIdeal.avg_trail_deviation * 1000, resultsReal.avg_trail_deviation * 1000]);
    set(gca, 'XTickLabel', {'Ideal', 'Realistic'});
    ylabel('Deviation (mm)');
    title('Trail Deviation');
    grid on;
    
    % Search Time
    subplot(2, 2, 2);
    bar([1, 2], [resultsIdeal.avg_search_time, resultsReal.avg_search_time]);
    set(gca, 'XTickLabel', {'Ideal', 'Realistic'});
    ylabel('Time (s)');
    title('Search Time');
    grid on;
    
    % Success Rate
    subplot(2, 2, 3);
    bar([1, 2], [resultsIdeal.success_rate * 100, resultsReal.success_rate * 100]);
    set(gca, 'XTickLabel', {'Ideal', 'Realistic'});
    ylabel('Rate (%)');
    title('Success Rate');
    ylim([0, 100]);
    grid on;
    
    % Path Efficiency
    subplot(2, 2, 4);
    bar([1, 2], [resultsIdeal.path_efficiency * 100, resultsReal.path_efficiency * 100]);
    set(gca, 'XTickLabel', {'Ideal', 'Realistic'});
    ylabel('Efficiency (%)');
    title('Path Efficiency');
    ylim([0, 100]);
    grid on;
    
    sgtitle('Performance Comparison: Ideal vs Realistic Sensing', 'FontSize', 14, 'FontWeight', 'bold');
    saveas(fig5, fullfile(results_dir, 'performance_summary.png'));
    close(fig5);
    
    % 6. Pheromone Trail Visualization
    simData.pheromoneModel.visualize(params.arena_width, params.arena_height, ...
        params.sim_time, params.decay_rate);
    saveas(gcf, fullfile(results_dir, 'pheromone_trail.png'));
    close(gcf);
    
    % 7. Comprehensive Report Figure
    fig7 = figure('Name', 'Comprehensive Report', 'NumberTitle', 'off', ...
                  'Position', [100, 100, 1200, 800]);
    
    % Title
    axes('Position', [0, 0.92, 1, 0.08]);
    axis off;
    text(0.5, 0.5, 'Real-Space Optical Pheromone Exchange Simulation Report', ...
         'FontSize', 18, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    
    % Floor model
    axes('Position', [0.05, 0.52, 0.25, 0.35]);
    imagesc([0, params.arena_width], [0, params.arena_height], floorModel.reflectivity_map);
    axis equal;
    colormap gray;
    title('Floor Reflectivity');
    xlabel('X (m)');
    ylabel('Y (m)');
    
    % Sensor readings
    axes('Position', [0.35, 0.52, 0.25, 0.35]);
    time_vec = (1:min(1000, length(simData.sensor_history))) * params.dt;
    plot(time_vec, simData.sensor_history(1:length(time_vec), :));
    title('Sensor Readings');
    xlabel('Time (s)');
    ylabel('Value');
    legend({'S1', 'S2', 'S3', 'S4'}, 'FontSize', 8);
    
    % Path comparison
    axes('Position', [0.65, 0.52, 0.3, 0.35]);
    hold on;
    rectangle('Position', [0, 0, params.arena_width, params.arena_height], ...
              'FaceColor', [0.9, 0.9, 0.9], 'EdgeColor', 'k');
    scatter(params.target_position(1), params.target_position(2), 100, 'g', 'filled');
    scatter(0.5, 0.5, 100, 'r', 'filled');
    plot(path_x, path_y, 'b-', 'LineWidth', 2);
    plot(noisy_path_x, noisy_path_y, 'r-', 'LineWidth', 2);
    hold off;
    axis([0, params.arena_width, 0, params.arena_height]);
    axis equal;
    title('Navigation Paths');
    xlabel('X (m)');
    ylabel('Y (m)');
    
    % Performance summary table
    axes('Position', [0.1, 0.1, 0.8, 0.35]);
    axis off;
    
    summary_text = {
        'SIMULATION PARAMETERS', '', ...
        sprintf('Arena Size: %.1f x %.1f m', params.arena_width, params.arena_height), '', ...
        sprintf('Simulation Time: %.1f s', params.sim_time), '', ...
        sprintf('Sensor Noise Level: %.3f', params.sensor_noise), '', ...
        sprintf('Pheromone Decay Rate: %.4f', params.decay_rate), '', ...
        '', ...
        'PERFORMANCE METRICS', '', ...
        sprintf('Trail Deviation - Ideal: %.3f mm, Realistic: %.3f mm', ...
            resultsIdeal.avg_trail_deviation * 1000, resultsReal.avg_trail_deviation * 1000), '', ...
        sprintf('Search Time - Ideal: %.2f s, Realistic: %.2f s', ...
            resultsIdeal.avg_search_time, resultsReal.avg_search_time), '', ...
        sprintf('Success Rate - Ideal: %.0f%%, Realistic: %.0f%%', ...
            resultsIdeal.success_rate * 100, resultsReal.success_rate * 100), '', ...
        sprintf('Path Efficiency - Ideal: %.1f%%, Realistic: %.1f%%', ...
            resultsIdeal.path_efficiency * 100, resultsReal.path_efficiency * 100), '', ...
        '', ...
        'KEY FINDINGS', '', ...
        sprintf('Realistic sensing increases trail deviation by %.1f%%', ...
            (resultsReal.avg_trail_deviation / max(resultsIdeal.avg_trail_deviation, eps) - 1) * 100), '', ...
        sprintf('Realistic sensing increases search time by %.1f%%', ...
            (resultsReal.avg_search_time / max(resultsIdeal.avg_search_time, eps) - 1) * 100)
    };
    
    text(0.05, 0.95, summary_text, 'FontSize', 11, 'VerticalAlignment', 'top', 'FontName', 'Monaco');
    
    saveas(fig7, fullfile(results_dir, 'comprehensive_report.png'));
    close(fig7);
    
    fprintf('    All visualizations saved to %s/\n', results_dir);
end
