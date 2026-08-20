classdef PerformanceComparator
    % PerformanceComparator - Compare ideal vs realistic sensing performance
    % 
    % This class provides comprehensive comparison metrics and visualizations
    % to analyze the performance difference between ideal and realistic sensing.
    
    properties
        params
        comparison_metrics
    end
    
    methods
        function obj = PerformanceComparator(params)
            % Constructor
            
            obj.params = params;
            obj.comparison_metrics = struct();
        end
        
        function obj = compare(obj, results_ideal, results_realistic)
            % Compare ideal vs realistic results
            
            % Trail deviation comparison (report absolute values, not ratios)
            obj.comparison_metrics.ideal_trail_deviation = results_ideal.avg_trail_deviation;
            obj.comparison_metrics.realistic_trail_deviation = results_realistic.avg_trail_deviation;
            obj.comparison_metrics.trail_deviation_diff = ...
                results_realistic.avg_trail_deviation - results_ideal.avg_trail_deviation;
            
            % Search time comparison
            obj.comparison_metrics.search_time_diff = ...
                results_realistic.avg_search_time - results_ideal.avg_search_time;
            if results_ideal.avg_search_time > 0
                obj.comparison_metrics.search_time_ratio = ...
                    results_realistic.avg_search_time / results_ideal.avg_search_time;
            else
                obj.comparison_metrics.search_time_ratio = NaN;
            end
            
            % Success rate comparison
            obj.comparison_metrics.success_rate_diff = ...
                results_realistic.success_rate - results_ideal.success_rate;
            obj.comparison_metrics.ideal_success_rate = results_ideal.success_rate;
            obj.comparison_metrics.realistic_success_rate = results_realistic.success_rate;
            
            % Sensor error impact (as percentage of arena width)
            obj.comparison_metrics.sensor_error_rate = ...
                results_realistic.avg_trail_deviation / obj.params.arena_width * 100;
            
            % Calculate additional metrics
            if isfield(results_ideal, 'std_trail_deviation') && isfield(results_realistic, 'std_trail_deviation')
                obj.comparison_metrics.ideal_std_deviation = results_ideal.std_trail_deviation;
                obj.comparison_metrics.realistic_std_deviation = results_realistic.std_trail_deviation;
            end
            
            if isfield(results_ideal, 'path_efficiency') && isfield(results_realistic, 'path_efficiency')
                obj.comparison_metrics.efficiency_degradation = ...
                    (results_realistic.path_efficiency - results_ideal.path_efficiency);
                obj.comparison_metrics.ideal_path_efficiency = results_ideal.path_efficiency;
                obj.comparison_metrics.realistic_path_efficiency = results_realistic.path_efficiency;
            end
        end
        
        function printSummary(obj)
            % Print comparison summary
            
            fprintf('\n--- Performance Comparison Summary ---\n\n');
            
            fprintf('Trail Deviation (absolute values):\n');
            fprintf('  - Ideal:      %.4f m\n', obj.comparison_metrics.ideal_trail_deviation);
            fprintf('  - Realistic: %.4f m\n', obj.comparison_metrics.realistic_trail_deviation);
            fprintf('  - Increase:   %.4f m\n', obj.comparison_metrics.trail_deviation_diff);
            fprintf('  - Impact:     %.2f%% of arena width\n', obj.comparison_metrics.sensor_error_rate);
            fprintf('\n');
            
            fprintf('Search Time:\n');
            fprintf('  - Ideal:      %.2f s\n', obj.comparison_metrics.search_time_diff + ...
                obj.comparison_metrics.search_time_ratio * obj.comparison_metrics.search_time_diff / ...
                (obj.comparison_metrics.search_time_ratio - 1 + eps));
            fprintf('  - Realistic:  %.2f s\n', ...
                obj.comparison_metrics.search_time_ratio * obj.comparison_metrics.search_time_diff / ...
                (obj.comparison_metrics.search_time_ratio - 1 + eps));
            fprintf('  - Difference:  %.2f s\n', obj.comparison_metrics.search_time_diff);
            fprintf('\n');
            
            fprintf('Success Rate:\n');
            fprintf('  - Ideal:      %.0f%%\n', obj.comparison_metrics.ideal_success_rate * 100);
            fprintf('  - Realistic:  %.0f%%\n', obj.comparison_metrics.realistic_success_rate * 100);
            fprintf('\n');
            
            if isfield(obj.comparison_metrics, 'ideal_path_efficiency')
                fprintf('Path Efficiency:\n');
                fprintf('  - Ideal:      %.1f%%\n', obj.comparison_metrics.ideal_path_efficiency * 100);
                fprintf('  - Realistic:  %.1f%%\n', obj.comparison_metrics.realistic_path_efficiency * 100);
                fprintf('  - Change:     %.1f%%\n', obj.comparison_metrics.efficiency_degradation * 100);
                fprintf('\n');
            end
            
            if isfield(obj.comparison_metrics, 'ideal_std_deviation')
                fprintf('Deviation Consistency:\n');
                fprintf('  - Ideal Std:      %.4f m\n', obj.comparison_metrics.ideal_std_deviation);
                fprintf('  - Realistic Std:  %.4f m\n', obj.comparison_metrics.realistic_std_deviation);
                fprintf('\n');
            end
        end
        
        function fig = plotComparison(obj, results_ideal, results_realistic)
            % Create comparison visualization - Professional Q1 Journal Style
            % Clean, modern design with clear data presentation
            
            % Define professional color scheme
            colors.ideal = [0.2, 0.4, 0.7];      % Professional blue
            colors.realistic = [0.8, 0.2, 0.2];  % Professional red
            colors.background = [0.95, 0.95, 0.95]; % Light gray background
            colors.text = [0.2, 0.2, 0.2];         % Dark gray text
            colors.grid = [0.8, 0.8, 0.8];       % Light grid
            
            fig = figure('Name', 'Performance Comparison', ...
                        'NumberTitle', 'off', ...
                        'Position', [100, 100, 1200, 800], ...
                        'Color', 'white');
            
            % Main title
            sgtitle('Real-Space Optical Pheromone Navigation: Simulation Results', ...
                    'FontSize', 18, 'FontWeight', 'bold', 'Color', colors.text);
            
            % ============================================
            % 1. Path Efficiency - Large prominent display
            % ============================================
            ax1 = subplot(2, 2, 1);
            
            % Create elegant bar chart
            efficiencies = [results_ideal.path_efficiency * 100, results_realistic.path_efficiency * 100];
            b1 = bar(ax1, [1, 2], efficiencies, 0.6, 'FaceColor', 'flat');
            b1.CData = [colors.ideal; colors.realistic];
            b1.EdgeColor = [0.3, 0.3, 0.3];
            b1.LineWidth = 1.5;
            
            hold(ax1, 'on');
            
            % Add value labels on bars
            for i = 1:length(efficiencies)
                text(ax1, i, efficiencies(i) + 2, sprintf('%.1f%%', efficiencies(i)), ...
                    'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold', ...
                    'Color', colors.text);
            end
            
            hold(ax1, 'off');
            
            % Styling
            ax1.XTick = [1, 2];
            ax1.XTickLabel = {'Ideal', 'Realistic'};
            ax1.XTickLabelRotation = 0;
            ax1.YLabel.String = 'Path Efficiency (%)';
            ax1.YLabel.FontSize = 12;
            ax1.YLabel.FontWeight = 'bold';
            ax1.Title.String = 'Path Efficiency';
            ax1.Title.FontSize = 14;
            ax1.Title.FontWeight = 'bold';
            ax1.YLim = [0, 115];
            ax1.GridLineStyle = '--';
            ax1.GridColor = colors.grid;
            ax1.GridAlpha = 0.5;
            ax1.Box = 'on';
            ax1.FontSize = 11;
            
            % ============================================
            % 2. Trail Deviation - Clean bar chart
            % ============================================
            ax2 = subplot(2, 2, 2);
            
            deviations = [results_ideal.avg_trail_deviation * 1000, results_realistic.avg_trail_deviation * 1000];
            std_devs = [results_ideal.std_trail_deviation * 1000, results_realistic.std_trail_deviation * 1000];
            
            b2 = bar(ax2, [1, 2], deviations, 0.6, 'FaceColor', 'flat');
            b2.CData = [colors.ideal; colors.realistic];
            b2.EdgeColor = [0.3, 0.3, 0.3];
            b2.LineWidth = 1.5;
            
            hold(ax2, 'on');
            
            % Add error bars
            errorbar(ax2, [1, 2], deviations, std_devs, 'k.', 'LineWidth', 2, 'CapSize', 8);
            
            % Add value labels
            for i = 1:length(deviations)
                text(ax2, i, deviations(i) + std_devs(i) + 0.5, sprintf('%.2f mm', deviations(i)), ...
                    'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold', ...
                    'Color', colors.text);
            end
            
            hold(ax2, 'off');
            
            % Styling
            ax2.XTick = [1, 2];
            ax2.XTickLabel = {'Ideal', 'Realistic'};
            ax2.YLabel.String = 'Trail Deviation (mm)';
            ax2.YLabel.FontSize = 12;
            ax2.YLabel.FontWeight = 'bold';
            ax2.Title.String = 'Trail Deviation';
            ax2.Title.FontSize = 14;
            ax2.Title.FontWeight = 'bold';
            ax2.YLim = [0, max(deviations) * 1.5 + 2];
            ax2.GridLineStyle = '--';
            ax2.GridColor = colors.grid;
            ax2.GridAlpha = 0.5;
            ax2.Box = 'on';
            ax2.FontSize = 11;
            
            % ============================================
            % 3. Success Rate - Prominent display
            % ============================================
            ax3 = subplot(2, 2, 3);
            
            success_rates = [results_ideal.success_rate, results_realistic.success_rate] * 100;
            
            b3 = bar(ax3, [1, 2], success_rates, 0.6, 'FaceColor', 'flat');
            b3.CData = [colors.ideal; colors.realistic];
            b3.EdgeColor = [0.3, 0.3, 0.3];
            b3.LineWidth = 1.5;
            
            hold(ax3, 'on');
            
            % Add value labels with checkmark
            for i = 1:length(success_rates)
                text(ax3, i, success_rates(i) + 2, sprintf('%.0f%%', success_rates(i)), ...
                    'HorizontalAlignment', 'center', 'FontSize', 16, 'FontWeight', 'bold', ...
                    'Color', [0.1, 0.5, 0.1]); % Green for success
            end
            
            hold(ax3, 'off');
            
            % Styling
            ax3.XTick = [1, 2];
            ax3.XTickLabel = {'Ideal', 'Realistic'};
            ax3.YLabel.String = 'Success Rate (%)';
            ax3.YLabel.FontSize = 12;
            ax3.YLabel.FontWeight = 'bold';
            ax3.Title.String = 'Mission Success Rate';
            ax3.Title.FontSize = 14;
            ax3.Title.FontWeight = 'bold';
            ax3.YLim = [0, 115];
            ax3.GridLineStyle = '--';
            ax3.GridColor = colors.grid;
            ax3.GridAlpha = 0.5;
            ax3.Box = 'on';
            ax3.FontSize = 11;
            
            % ============================================
            % 4. Key Findings Summary Panel
            % ============================================
            ax4 = subplot(2, 2, 4);
            axis(ax4, 'off');
            
            % Create summary box with light background
            rectangle('Position', [0.02, 0.05, 0.96, 0.90], ...
                     'FaceColor', [0.97, 0.97, 0.97], ...
                     'EdgeColor', colors.grid, 'LineWidth', 1);
            
            % Title
            text(0.5, 0.92, 'Key Performance Metrics', ...
                'HorizontalAlignment', 'center', 'FontSize', 14, ...
                'FontWeight', 'bold', 'Color', colors.text);
            
            % Build metrics text
            metrics_text = {
                sprintf('Path Length (Ideal):    %.2f m', results_ideal.path_length),
                sprintf('Path Length (Real):    %.2f m', results_realistic.path_length),
                sprintf('Path Deviation:         +%.2f mm', ...
                    (results_realistic.avg_trail_deviation - results_ideal.avg_trail_deviation) * 1000),
                sprintf('Search Time (Ideal):    %.1f s', results_ideal.avg_search_time),
                sprintf('Search Time (Real):     %.1f s', results_realistic.avg_search_time),
                sprintf('Time Difference:        %.1f s', ...
                    results_realistic.avg_search_time - results_ideal.avg_search_time),
                '--------------------------------',
                'Dual-Modality Status:',
                '  Optical Channel:     Active',
                '  Chemical Backup:     Available',
                '  Switchover Threshold: 6 dB'
            };
            
            % Display metrics
            text(0.08, 0.78, metrics_text, ...
                'FontName', 'Monaco', 'FontSize', 10, ...
                'VerticalAlignment', 'top', 'Color', colors.text);
            
            % Add legend indicators
            line([0.08, 0.12], [0.18, 0.18], 'Color', colors.ideal, 'LineWidth', 4, 'Parent', ax4);
            text(0.14, 0.18, 'Ideal Conditions', 'FontSize', 10, 'Color', colors.text, 'VerticalAlignment', 'middle');
            
            line([0.08, 0.12], [0.12, 0.12], 'Color', colors.realistic, 'LineWidth', 4, 'Parent', ax4);
            text(0.14, 0.12, 'Realistic Conditions', 'FontSize', 10, 'Color', colors.text, 'VerticalAlignment', 'middle');
            
            % Add subtle timestamp
            text(0.98, 0.02, datestr(now, 'mmm dd, yyyy HH:MM'), ...
                'HorizontalAlignment', 'right', 'FontSize', 8, ...
                'Color', [0.5, 0.5, 0.5], 'FontName', 'Monaco');
            
            % Adjust subplot spacing
            set(gcf, 'renderer', 'painters');
        end
        
        function metrics = getMetrics(obj)
            % Return comparison metrics
            
            metrics = obj.comparison_metrics;
        end
    end
end

% Helper function for bar plots with error bars
function barweb(means, errors, width, group_names, ymin, ylabel_text, title_text, ymax, bar_names)
    % Simple bar plot with error bars
    
    if nargin < 9
        ymax = [0, max(means + errors) * 1.2];
    end
    if nargin < 8
        ylabel_text = '';
    end
    if nargin < 7
        title_text = '';
    end
    if nargin < 6
        ymin = 0;
    end
    
    bar(means);
    hold on;
    
    for i = 1:length(means)
        errorbar(i, means(i), errors(i), 'k.', 'LineWidth', 2);
    end
    
    hold off;
    
    if ~isempty(group_names)
        set(gca, 'XTickLabel', group_names);
    end
    
    xlabel('Mode');
    ylabel(ylabel_text);
    title(title_text);
    ylim([0, max(means + errors) * 1.2]);
    grid on;
end
