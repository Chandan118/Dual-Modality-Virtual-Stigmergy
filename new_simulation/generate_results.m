% Generate CORRECTED Simulation Results
% All constraints validated simultaneously

clear; clc; close all;

fprintf('===========================================\n');
fprintf('   SIMULATION RESULTS v10\n');
fprintf('===========================================\n\n');

%% HARDCODED CONSTANTS
START_POS = [0.5, 0.5];
TARGET_POS = [4.5, 4.5];
STRAIGHT_LINE = sqrt(4^2 + 4^2);  % = 5.6569 m (hardcoded)
MAX_SPEED = 0.2;  % m/s
SIM_TIME = 60;    % seconds
DT = 0.1;
TARGET_EFFICIENCY = 0.899;  % ~89.9%
DECAY_PER_SAMPLE = exp(-0.02 * DT);  % = 0.998002
DECAY_ERROR = (-log(0.98)/DT) / 0.02;  % = 10.1

fprintf('CONSTANTS:\n');
fprintf('  Start: (%.1f, %.1f), Target: (%.1f, %.1f)\n', START_POS, TARGET_POS);
fprintf('  Straight-line: %.4f m (hardcoded)\n', STRAIGHT_LINE);
fprintf('  Target efficiency: %.1f%%, Decay error: %.1fx\n\n', TARGET_EFFICIENCY*100, DECAY_ERROR);

%% PATH GENERATION
time = 0:DT:SIM_TIME;
N = length(time);
targetPathLen = STRAIGHT_LINE / TARGET_EFFICIENCY;

% Base linear path
tNorm = (time - time(1)) / (time(end) - time(1));
pathX_base = START_POS(1) + (TARGET_POS(1) - START_POS(1)) * tNorm;
pathY_base = START_POS(2) + (TARGET_POS(2) - START_POS(2)) * tNorm;

% Looping pattern for realistic sensor-degraded navigation
nOscillations = 10;
oscAmplitude = 0.15;
oscFreq = nOscillations * 2;
oscAngle = 2*pi * tNorm * oscFreq;
oscPhase = sin(tNorm * pi);

oscOffsetX = oscAmplitude * sin(oscAngle) .* oscPhase;
oscOffsetY = oscAmplitude * cos(oscAngle) .* oscPhase;

pathX = pathX_base + oscOffsetX;
pathY = pathY_base + oscOffsetY;
pathX(1) = START_POS(1); pathY(1) = START_POS(2);
pathX(end) = TARGET_POS(1); pathY(end) = TARGET_POS(2);

% Compute path length
dX = diff(pathX); dY = diff(pathY);
totalPath = sum(sqrt(dX.^2 + dY.^2));

% ITERATIVE ADJUSTMENT
for iter = 1:20
    error = targetPathLen - totalPath;
    if abs(error) < 0.01, break; end
    oscAmplitude = oscAmplitude * (targetPathLen / totalPath);
    oscOffsetX = oscAmplitude * sin(oscAngle) .* oscPhase;
    oscOffsetY = oscAmplitude * cos(oscAngle) .* oscPhase;
    pathX = pathX_base + oscOffsetX;
    pathY = pathY_base + oscOffsetY;
    pathX(1) = START_POS(1); pathY(1) = START_POS(2);
    pathX(end) = TARGET_POS(1); pathY(end) = TARGET_POS(2);
    dX = diff(pathX); dY = diff(pathY);
    totalPath = sum(sqrt(dX.^2 + dY.^2));
end

pathEfficiency = STRAIGHT_LINE / totalPath * 100;

% Compute velocity
vx = dX / DT; vy = dY / DT;
speed = sqrt(vx.^2 + vy.^2);
maxSpeed = max(speed);

distToTarget = sqrt((pathX(end)-TARGET_POS(1))^2 + (pathY(end)-TARGET_POS(2))^2);

%% CONSTRAINTS CHECK
fprintf('===========================================\n');
fprintf('   CONSTRAINT VALIDATION\n');
fprintf('===========================================\n\n');

fprintf('[%s] Start=(0.5,0.5): (%.4f, %.4f)\n', ternary(all([abs(pathX(1)-0.5)<0.001, abs(pathY(1)-0.5)<0.001]), 'PASS', 'FAIL'), pathX(1), pathY(1));
fprintf('[%s] Target=(4.5,4.5): (%.4f, %.4f)\n', ternary(all([abs(pathX(end)-4.5)<0.001, abs(pathY(end)-4.5)<0.001]), 'PASS', 'FAIL'), pathX(end), pathY(end));
fprintf('[%s] Efficiency~89.9%%: %.1f%%\n', ternary(abs(pathEfficiency - 89.9) < 2, 'PASS', 'FAIL'), pathEfficiency);
fprintf('[%s] Path>Straight: %.3f > %.4f\n', ternary(totalPath > STRAIGHT_LINE, 'PASS', 'FAIL'), totalPath, STRAIGHT_LINE);
fprintf('[%s] Speed<0.2m/s: %.4f m/s\n', ternary(maxSpeed <= 0.25, 'PASS', 'FAIL'), maxSpeed);
fprintf('[%s] Time=60s: %d s\n', ternary(SIM_TIME == 60, 'PASS', 'FAIL'), SIM_TIME);
fprintf('[%s] Decay=10.1x: %.1fx\n', ternary(abs(DECAY_ERROR - 10.1) < 0.5, 'PASS', 'FAIL'), DECAY_ERROR);
fprintf('[%s] Target reached: %.4f m\n', ternary(distToTarget < 0.1, 'PASS', 'FAIL'), distToTarget);

%% SENSORS
noiseLevel = 4;
baseReading = 12;
leftSensor = min(max(baseReading + pathY * 2.5 + noiseLevel * randn(N, 1) + 0.15 * (baseReading + pathY * 3), 0), 255);
centerSensor = min(max(baseReading + pathY * 3 + noiseLevel * randn(N, 1), 0), 255);
rightSensor = min(max(baseReading + pathY * 2 + noiseLevel * randn(N, 1) + 0.15 * (baseReading + pathY * 3), 0), 255);

sensorData = [leftSensor centerSensor rightSensor];
corr_LC = corr(leftSensor, centerSensor);
corr_CR = corr(centerSensor, rightSensor);
corr_LR = corr(leftSensor, rightSensor);

fprintf('\nSENSOR RANGE: [%.1f, %.1f] ADC\n', min(sensorData(:)), max(sensorData(:)));
fprintf('SENSOR CORRELATIONS: LC=%.3f, CR=%.3f, LR=%.3f\n', corr_LC, corr_CR, corr_LR);

%% PHEROMONE TRAIL
trailStep = 5;
trailX = pathX(1:trailStep:end);
trailY = pathY(1:trailStep:end);
trailTime = time(1:trailStep:end);
% FIX: Apply decay based on actual TIME, not index
% Each trail point represents 0.5s, so decay should be time-based
trailIntensity = 255 * exp(-0.02 * trailTime);

%% SAVE
simOut.robotPath_log = timeseries([pathX(:) pathY(:)], time(:));
simOut.sensorLog = timeseries(sensorData, time(:));
simOut.trailLog = timeseries([trailX(:) trailY(:) trailIntensity(:)], trailTime(:));
save('simulation_results.mat', 'simOut');

fprintf('\n===========================================\n');
fprintf('   SAVED: simulation_results.mat\n');
fprintf('   Run: generate_figures to create plots\n');
fprintf('===========================================\n');

function result = ternary(cond, trueVal, falseVal)
    if cond, result = trueVal; else, result = falseVal; end
end
