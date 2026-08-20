# Physical Experiment Protocols for FormicaBot V2 Hardware Validation
## Data Request Checklist - Physical Experiments

This document provides detailed step-by-step protocols for conducting the physical experiments required to replace the fabricated data in the manuscript.

---

## EXPERIMENT 1: True Power Consumption Measurement

### Hardware Required
- INA219 Current/Voltage Sensor (or oscilloscope with current probe)
- Bench power supply (12V, 5A minimum)
- Data logger or oscilloscope

### Setup
1. Connect INA219 sensor between battery and robot power bus
2. Ensure all components are connected: Jetson Orin Nano, Azure Kinect, RPLIDAR A1, motors
3. Connect data logger to record voltage and current at 10 Hz

### Procedure
1. Power on the robot system
2. Start all components (Jetson, Kinect, RPLIDAR, motors running)
3. Record for 60 seconds minimum
4. Save raw voltage/current data

### MATLAB Processing
```matlab
% Load recorded data
voltage = load('voltage_data.csv');
current = load('current_data.csv');
time = load('time_data.csv');

% Calculate power
power = voltage .* current;

% Calculate statistics
mean_power = mean(power)
std_power = std(power)
max_power = max(power)
min_power = min(power)

% Plot power vs time
plot(time, power)
xlabel('Time (s)')
ylabel('Power (W)')
title('Power Consumption vs Time')
grid on

% Save figure
saveas(gcf, 'results/power_consumption.png')
```

### Expected Results
- Mean Power: **20-40 W** (NOT 0.669 W)
- A value of 0.669 W is physically impossible for this hardware stack

### Replace in Manuscript
Replace the fabricated 0.669 W claim with the true measured mean power.

---

## EXPERIMENT 2: Real Trajectory & Cross-Track Error

### Hardware Required
- External camera or motion capture system (e.g., OptiTrack, Vicon)
- OR tape measure for manual measurement
- Floor markings for ground truth path

### Setup
1. Set up motion capture cameras around the test arena
2. Place reflective markers on the robot
3. Calibrate the motion capture system
4. Define the ideal straight-line path on the floor

### Procedure
1. Have robot autonomously follow the defined path
2. Record actual X,Y positions at 30 Hz
3. Repeat for minimum 20 trials
4. Export position data to CSV

### MATLAB Processing
```matlab
% Load trajectory data
ideal_x = load('ideal_path_x.csv');
ideal_y = load('ideal_path_y.csv');
actual_x = load('actual_path_x.csv');
actual_y = load('actual_path_y.csv');

% Calculate cross-track error
for i = 1:length(actual_x)
    dx = actual_x(i) - ideal_x;
    dy = actual_y(i) - ideal_y;
    distances = sqrt(dx.^2 + dy.^2);
    cross_track_error(i) = min(distances);
end

% Calculate 95th percentile
percentile_95 = prctile(cross_track_error * 100, 95)

% Plot trajectory comparison
figure;
plot(ideal_x, ideal_y, 'b--', 'LineWidth', 2);
hold on;
plot(actual_x, actual_y, 'r-', 'LineWidth', 1);
xlabel('X (m)');
ylabel('Y (m)');
title('Robot Trajectory Comparison');
legend('Ideal Path', 'Actual Path');
grid on;

% Plot error distribution
figure;
histogram(cross_track_error * 100, 30);
xlabel('Cross-Track Error (cm)');
ylabel('Frequency');
title('Error Distribution');
grid on;

% Save results
save('results/cross_track_error.mat', 'cross_track_error');
saveas(gcf, 'results/trajectory_analysis.png');
```

### Expected Results
- 95th Percentile Error: **1.5-5.0 cm** (NOT 0.08 cm)
- A value of 0.08 cm is physically impossible for a wheeled robot

### Replace in Manuscript
Replace the fabricated 0.080 cm claim with the true 95th percentile cross-track error.

---

## EXPERIMENT 3: MQ-135 Chemical Sensor Warm-Up Curve

### Hardware Required
- MQ-135 gas sensor module
- Arduino or data logger
- ADC (10-bit minimum)
- Clean air environment (no contaminants)

### Setup
1. Connect MQ-135 sensor to Arduino/ADC
2. Ensure sensor is in clean air environment
3. Set sampling rate to 1 Hz
4. Clear any previous warm-up data

### Procedure
1. Power on the cold MQ-135 sensor
2. Begin recording ADC values immediately
3. Continue recording until reading completely flattens (minimum 10 minutes)
4. Save raw ADC/time data

### MATLAB Processing
```matlab
% Load warm-up data
time = load('mq135_time.csv');  % seconds
adc_values = load('mq135_adc.csv');

% Convert to voltage
voltage = double(adc_values) / 1023 * 5.0;

% Calculate rolling standard deviation
window_size = 300;  % 5 minute window
for i = 1:(length(voltage) - window_size)
    rolling_std(i) = std(voltage(i:i+window_size-1));
end

% Find stabilization time (where std < threshold)
threshold = (max(voltage) - min(voltage)) * 0.05;  % 5%
stable_idx = find(rolling_std < threshold, 1, 'first');
stabilization_time = time(stable_idx);

% Plot warm-up curve
figure;
plot(time/60, voltage, 'b-', 'LineWidth', 1);
hold on;
yline(voltage(end), 'g--', 'LineWidth', 2, 'Final Value');
xline(stabilization_time/60, 'r--', 'LineWidth', 2, ...
    sprintf('Stabilization: %.1f min', stabilization_time/60));
xlabel('Time (minutes)');
ylabel('Voltage (V)');
title('MQ-135 Sensor Warm-Up Curve');
grid on;

% Plot derivative
figure;
dt = diff(time);
dv = diff(voltage);
derivative = dv ./ dt;
plot(time(1:end-1)/60, abs(derivative), 'b-', 'LineWidth', 1);
hold on;
yline(0.001, 'r--', 'LineWidth', 2, 'Stability Threshold');
xlabel('Time (minutes)');
ylabel('|dV/dt| (V/s)');
title('Rate of Change (Zero = Stable)');
grid on;

% Save results
save('results/mq135_warmup.mat', 'stabilization_time');
saveas(gcf, 'results/mq135_warmup.png');
```

### Expected Results
- Stabilization Time: **120-300 seconds** (NOT 30 seconds)
- The 30-second value in Algorithm 1 is INSUFFICIENT

### Replace in Manuscript
Replace the fabricated 30-second claim with the true measured stabilization time in Algorithm 1.

---

## EXPERIMENT 4: Virtual Pheromone Decay Model (Documentation)

### IMPORTANT CORRECTION
**Physical LED light does NOT evaporate.** The pheromone system uses VIRTUAL pheromones simulated in a software grid mapped over the physical arena.

### Mathematical Model

The decay equation implemented in MATLAB:

```
I(t) = I0 × exp(-φ × t) + I_residual
```

Where:
- `I(t)` = Pheromone intensity at time t
- `I0` = Initial deposition intensity (0-255)
- `φ (phi)` = Decay constant = **0.02 per second**
- `t` = Time in seconds
- `I_residual` = I0 × 0.01 (1% residual fraction)

### Derived Parameters
- Time Constant (τ) = 1/φ = **50 seconds**
- Half-Life = ln(2)/φ = **34.66 seconds**

### MATLAB Code (already implemented in WS2812BPheromone.m)
```matlab
% From WS2812BPheromone.m, lines 96-99:
decayed_intensities = obj.trail_intensities(in_range) .* ...
                       exp(-decay_rate * ages);
```

### Replace in Manuscript
Update the physical implementation section to clarify that pheromones are virtual and simulated in software, not physical LED light that evaporates.

---

## EXPERIMENT 5: Genuine SLAM RMSE

### Hardware Required
- RPLIDAR A1 sensor
- Jetson Orin Nano running slam_toolbox
- Tape measure for ground truth measurement
- Stopwatch

### Setup
1. Run robot through a known path (measure with tape measure)
2. Record SLAM estimated poses
3. Mark ground truth points physically
4. Ensure good lighting and feature-rich environment

### Procedure
1. Define a rectangular test path (e.g., 4m × 4m)
2. Run robot through the path autonomously
3. Record SLAM trajectory output
4. Measure actual positions with tape measure
5. Repeat for minimum 20 trials
6. Calculate RMSE

### MATLAB Processing
```matlab
% Load SLAM and ground truth data
gt_x = load('ground_truth_x.csv');
gt_y = load('ground_truth_y.csv');
slam_x = load('slam_x.csv');
slam_y = load('slam_y.csv');

% Calculate position errors
errors = sqrt((slam_x - gt_x).^2 + (slam_y - gt_y).^2);

% Calculate RMSE
rmse = sqrt(mean(errors.^2))

% Calculate additional statistics
mean_error = mean(errors)
max_error = max(errors)
std_error = std(errors)
percentile_95 = prctile(errors, 95)

% Plot trajectory comparison
figure;
plot(gt_x, gt_y, 'b-', 'LineWidth', 2, 'DisplayName', 'Ground Truth');
hold on;
plot(slam_x, slam_y, 'r-', 'LineWidth', 1, 'DisplayName', 'SLAM Estimate');
xlabel('X (m)');
ylabel('Y (m)');
title('SLAM Trajectory vs Ground Truth');
legend;
grid on;
axis equal;

% Plot error over distance
figure;
dist = cumsum([0; sqrt(diff(gt_x).^2 + diff(gt_y).^2)]);
plot(dist(1:length(errors)), errors * 100, 'b-', 'LineWidth', 1);
hold on;
yline(rmse * 100, 'r--', 'LineWidth', 2, sprintf('RMSE: %.2f cm', rmse * 100));
xlabel('Distance Traveled (m)');
ylabel('Position Error (cm)');
title('SLAM Position Error vs Distance');
grid on;

% Save results
save('results/slam_rmse.mat', 'rmse', 'errors');
saveas(gcf, 'results/slam_rmse.png');

% Print RMSE formula used
fprintf('RMSE = sqrt(mean((slam_x - gt_x)^2 + (slam_y - gt_y)^2))\n');
fprintf('RMSE = %.4f m (%.2f cm)\n', rmse, rmse * 100);
```

### Expected Results
- RMSE: **2-15 cm** (NOT 0.087 m which is 8.7 cm)
- The fabricated 0.087 m value may be optimistic or fabricated

### Replace in Manuscript
Replace the fabricated 0.087 m RMSE claim with the true measured RMSE.

---

## Summary: Data Replacement Table

| Fabricated Value | Replace With | Location |
|-----------------|--------------|----------|
| 0.669 W | True mean power (20-40 W expected) | Power consumption section |
| 0.080 cm | True 95th percentile CTE (1.5-5.0 cm expected) | Trajectory analysis |
| 30 seconds | True stabilization time (120-300 s expected) | Algorithm 1 |
| N/A | Clarify: Virtual pheromones in software grid | Physical implementation |
| 0.087 m | True RMSE (2-15 cm expected) | SLAM evaluation |

---

## Running the Loop

To continuously collect and process data:

### Option 1: MATLAB Loop
```matlab
% Run continuously every 5 minutes
while true
    RunHardwareValidation(false);
    pause(300);  % 5 minutes
end
```

### Option 2: Python Loop
```bash
# Run the Python script continuously
python HardwareDataCollection.py --loop --interval 300
```

### Option 3: Use the Provided Loop Script
```bash
./run_continuous_validation.sh
```
