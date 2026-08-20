% Generate Professional Figure - Dual-Modality Navigation System Analysis
% White background for publication - Improved version
clear; clc; close all;

%% Load simulation data
load('simulation_results.mat');

pathData = simOut.robotPath_log.Data;
pathTime = simOut.robotPath_log.Time;
sensorData = simOut.sensorLog.Data;
trailData = simOut.trailLog.Data;
trailTime = simOut.trailLog.Time;

% Ensure correct shapes
pathData = reshape(pathData, [], 2);
if size(sensorData, 2) ~= 3
    sensorData = reshape(sensorData.', [], 3);
end

pathX = pathData(:,1);
pathY = pathData(:,2);
leftSensor = sensorData(:,1);
centerSensor = sensorData(:,2);
rightSensor = sensorData(:,3);
sensorTime = (0:length(leftSensor)-1)' * 0.1;

% Compute metrics
dX = diff(pathX); dY = diff(pathY);
totalPath = sum(sqrt(dX.^2 + dY.^2));
STRAIGHT_LINE = sqrt(4^2 + 4^2);
pathEfficiency = STRAIGHT_LINE / totalPath * 100;
speed = sqrt((dX/0.1).^2 + (dY/0.1).^2);
maxSpeed = max(speed);
avgSpeed = totalPath / 60;
distToTarget = sqrt((pathX(end)-4.5)^2 + (pathY(end)-4.5)^2);
corr_LC = corr(leftSensor, centerSensor);
corr_CR = corr(centerSensor, rightSensor);
corr_LR = corr(leftSensor, rightSensor);

%% Create Professional Figure with White Background
fig = figure('Position', [100, 100, 1400, 1000], 'Color', [1 1 1], 'Name', 'Dual-Modality Navigation');
set(fig, 'defaultAxesColor', [1 1 1]);
set(fig, 'defaultTextColor', [0 0 0]);
set(fig, 'defaultAxesXColor', [0.1 0.1 0.1]);
set(fig, 'defaultAxesYColor', [0.1 0.1 0.1]);

% Title
sgtitle('Dual-Modality Navigation System Analysis', 'FontSize', 16, 'FontWeight', 'bold', ...
        'Color', [0 0 0], 'Interpreter', 'none');

%% Panel 1: Robot Path (Top Left)
ax1 = subplot(2, 3, 1);
hold(ax1, 'on');
grid(ax1, 'on');
set(ax1, 'GridColor', [0.85 0.85 0.85], 'GridAlpha', 0.7, 'FontSize', 9);
set(ax1, 'XColor', [0.2 0.2 0.2], 'YColor', [0.2 0.2 0.2], 'Box', 'on', 'BoxStyle', 'full');

% Plot robot path
plot(ax1, pathX, pathY, 'b-', 'LineWidth', 2, 'DisplayName', 'Robot Path');

% Start and end points
plot(ax1, pathX(1), pathY(1), 'go', 'MarkerSize', 12, 'MarkerFaceColor', 'g', 'LineWidth', 1.5);
plot(ax1, pathX(end), pathY(end), 'ro', 'MarkerSize', 12, 'MarkerFaceColor', 'r', 'LineWidth', 1.5);

% Target marker
plot(ax1, 4.5, 4.5, 'm*', 'MarkerSize', 15, 'LineWidth', 2);

% Floor boundary
rectangle(ax1, 'Position', [0 0 5 5], 'EdgeColor', [0.3 0.3 0.3], 'LineWidth', 1.5);

title(ax1, 'Robot Navigation Path', 'FontWeight', 'bold', 'FontSize', 11);
xlabel(ax1, 'X Position (m)');
ylabel(ax1, 'Y Position (m)');
xlim(ax1, [0 5]);
ylim(ax1, [0 5]);
legend(ax1, 'Location', 'best', 'FontSize', 8);

% Add annotations
text(ax1, 0.7, 0.7, 'Start', 'Color', [0 0.5 0], 'FontSize', 9, 'FontWeight', 'bold');
text(ax1, 4.3, 4.7, 'Target', 'Color', [0.5 0 0.5], 'FontSize', 9, 'FontWeight', 'bold');

%% Panel 2: Velocity Profile (Top Middle)
ax2 = subplot(2, 3, 2);
hold(ax2, 'on');
grid(ax2, 'on');
set(ax2, 'GridColor', [0.85 0.85 0.85], 'GridAlpha', 0.7, 'FontSize', 9);
set(ax2, 'XColor', [0.2 0.2 0.2], 'YColor', [0.2 0.2 0.2], 'Box', 'on', 'BoxStyle', 'full');

% Fill under speed curve
fill(ax2, [pathTime(1:end-1) fliplr(pathTime(1:end-1))], ...
     [speed' fliplr(zeros(1,length(speed)))], ...
     [0.3 0.6 0.9], 'FaceAlpha', 0.3);
plot(ax2, pathTime(1:end-1), speed, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Speed');

% Max speed limit
yline(ax2, 0.2, 'r--', 'Max Speed 0.2 m/s', 'LineWidth', 1.5);

title(ax2, 'Velocity Profile', 'FontWeight', 'bold', 'FontSize', 11);
xlabel(ax2, 'Time (s)');
ylabel(ax2, 'Speed (m/s)');
xlim(ax2, [0 60]);
ylim(ax2, [0 0.35]);
legend(ax2, 'Location', 'best', 'FontSize', 8);

%% Panel 3: Position vs Time (Top Right)
ax3 = subplot(2, 3, 3);
hold(ax3, 'on');
grid(ax3, 'on');
set(ax3, 'GridColor', [0.85 0.85 0.85], 'GridAlpha', 0.7, 'FontSize', 9);
set(ax3, 'XColor', [0.2 0.2 0.2], 'YColor', [0.2 0.2 0.2], 'Box', 'on', 'BoxStyle', 'full');

plot(ax3, pathTime, pathX, 'b-', 'LineWidth', 1.5, 'DisplayName', 'X(t)');
plot(ax3, pathTime, pathY, 'r-', 'LineWidth', 1.5, 'DisplayName', 'Y(t)');

% Target lines
yline(ax3, 4.5, 'm--', 'Target', 'LineWidth', 1);

title(ax3, 'Position vs Time', 'FontWeight', 'bold', 'FontSize', 11);
xlabel(ax3, 'Time (s)');
ylabel(ax3, 'Position (m)');
xlim(ax3, [0 60]);
ylim(ax3, [0 5]);
legend(ax3, 'Location', 'best', 'FontSize', 8);

%% Panel 4: Sensor Data (Bottom Left)
ax4 = subplot(2, 3, 4);
hold(ax4, 'on');
grid(ax4, 'on');
set(ax4, 'GridColor', [0.85 0.85 0.85], 'GridAlpha', 0.7, 'FontSize', 9);
set(ax4, 'XColor', [0.2 0.2 0.2], 'YColor', [0.2 0.2 0.2], 'Box', 'on', 'BoxStyle', 'full');

plot(ax4, sensorTime, leftSensor, 'r-', 'LineWidth', 1, 'DisplayName', 'Left');
plot(ax4, sensorTime, centerSensor, 'g-', 'LineWidth', 1, 'DisplayName', 'Center');
plot(ax4, sensorTime, rightSensor, 'b-', 'LineWidth', 1, 'DisplayName', 'Right');

title(ax4, 'TCRT5000 Infrared Sensors', 'FontWeight', 'bold', 'FontSize', 11);
xlabel(ax4, 'Time (s)');
ylabel(ax4, 'Sensor Value (ADC)');
xlim(ax4, [0 60]);
ylim(ax4, [0 50]);
legend(ax4, 'Location', 'best', 'FontSize', 8);

%% Panel 5: Pheromone Trail (Bottom Middle)
ax5 = subplot(2, 3, 5);
hold(ax5, 'on');
grid(ax5, 'on');
set(ax5, 'GridColor', [0.85 0.85 0.85], 'GridAlpha', 0.7, 'FontSize', 9);
set(ax5, 'XColor', [0.2 0.2 0.2], 'YColor', [0.2 0.2 0.2], 'Box', 'on', 'BoxStyle', 'full');

% Create scatter plot with color-coded intensity
scatter(ax5, trailData(:,1), trailData(:,2), 80, trailData(:,3), 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 0.5);
colormap(ax5, 'hot');
colorbar(ax5, 'Location', 'eastoutside');
caxis(ax5, [0 255]);

% Plot robot path overlay
plot(ax5, pathX, pathY, 'b-', 'LineWidth', 1.5, 'Alpha', 0.7);

title(ax5, 'Pheromone Trail Visualization', 'FontWeight', 'bold', 'FontSize', 11);
xlabel(ax5, 'X Position (m)');
ylabel(ax5, 'Y Position (m)');
xlim(ax5, [0 5]);
ylim(ax5, [0 5]);

%% Panel 6: Performance Summary (Bottom Right)
ax6 = subplot(2, 3, 6);
axis(ax6, 'off');
set(ax6, 'Box', 'on', 'BoxStyle', 'full');

% Create summary text box
summaryTxt = {
    '\fontsize{12}\bfseries Performance Metrics'
    ''
    sprintf('Total Path Length: %.3f m', totalPath)
    sprintf('Path Efficiency: %.1f%%', pathEfficiency)
    sprintf('Straight-line Distance: %.4f m', STRAIGHT_LINE)
    ''
    sprintf('Maximum Speed: %.3f m/s', maxSpeed)
    sprintf('Average Speed: %.3f m/s', avgSpeed)
    sprintf('Simulation Duration: 60 s')
    ''
    sprintf('Target Distance: %.4f m', distToTarget)
    sprintf('Target Status: %s', ternary(distToTarget < 0.1, 'REACHED', 'NOT REACHED'))
    ''
    '\fontsize{10}\bfseries Sensor Correlations'
    sprintf('L-C: %.3f  C-R: %.3f  L-R: %.3f', corr_LC, corr_CR, corr_LR)
    ''
    '\fontsize{10}\bfseries Pheromone System'
    sprintf('Decay Rate: \phi = 0.02 s^{-1}')
    sprintf('Initial Intensity: 255')
    sprintf('Final Intensity: %.1f', trailData(end,3))
};

text(ax6, 0.05, 0.95, summaryTxt, 'VerticalAlignment', 'top', ...
     'FontSize', 10, 'Color', [0 0 0], 'FontName', 'Helvetica');

title(ax6, 'Summary Statistics', 'FontWeight', 'bold', 'FontSize', 11);

% Add border
rectangle(ax6, 'Position', [0 0 1 1], 'EdgeColor', [0.5 0.5 0.5], 'LineWidth', 1.5);

%% Add Figure Caption
annotation(fig, 'textbox', [0.35, 0.02, 0.3, 0.03], ...
           'String', 'Figure: Dual-Modality Navigation System Analysis - 60s Simulation', ...
           'FontSize', 10, 'FontStyle', 'italic', 'HorizontalAlignment', 'center', ...
           'EdgeColor', 'none', 'Color', [0.3 0.3 0.3]);

%% Save figure
saveas(fig, 'results/fig_dual_modality_analysis.png');
fprintf('Figure saved: results/fig_dual_modality_analysis.png\n');

%% Helper function
function result = ternary(cond, trueVal, falseVal)
    if cond, result = trueVal; else, result = falseVal; end
end
