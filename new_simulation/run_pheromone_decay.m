% Get detailed pheromone decay data
addpath(genpath(pwd));

hwc = HardwareDataCollection();
hwc.documentPheromoneDecayModel();

fprintf('\n');
fprintf('PHEROMONE DECAY EXPERIMENT RESULTS\n');
fprintf('\n');
fprintf('KEY PARAMETERS:\n');
fprintf('  Decay rate (phi): %.4f per second\n', hwc.pheromone_decay_data.decay_rate);
fprintf('  Residual fraction: %.2f%%\n', hwc.pheromone_decay_data.residual_fraction * 100);
fprintf('\n');
fprintf('DECAY EQUATION:\n');
fprintf('  I(t) = I0 * exp(-phi * t) + I_residual\n');
fprintf('\n');
fprintf('Where:\n');
fprintf('  I(t)     = Pheromone intensity at time t\n');
fprintf('  I0       = Initial deposition intensity (255)\n');
fprintf('  phi      = Decay constant = %.4f per second\n', hwc.pheromone_decay_data.decay_rate);
fprintf('  t        = Time in seconds\n');
fprintf('  I_residual = I0 * %.4f (residual after long time)\n', hwc.pheromone_decay_data.residual_fraction);
fprintf('\n');

% Calculate derived values
phi = hwc.pheromone_decay_data.decay_rate;
half_life = log(2) / phi;
tau = 1 / phi;
I0 = 255;
I_residual = I0 * hwc.pheromone_decay_data.residual_fraction;

fprintf('DERIVED VALUES:\n');
fprintf('  Half-life: %.1f seconds\n', half_life);
fprintf('  Time constant (tau): %.1f seconds\n', tau);
fprintf('\n');

fprintf('INTENSITY AT KEY TIME POINTS:\n');
fprintf('  (Starting intensity I0 = 255)\n');
fprintf('  +----------+--------+-------------+\n');
fprintf('  | Time (s) | I(t)   | Remaining   |\n');
fprintf('  +----------+--------+-------------+\n');

for t = [0, 10, 30, 60, 90, 120, 180, 300, 600]
    I_t = I0 * exp(-phi * t) + I_residual;
    pct = 100 * I_t / I0;
    fprintf('  | %8d | %6.2f | %10.2f%% |\n', t, I_t, pct);
end
fprintf('  +----------+--------+-------------+\n');

fprintf('\n');
fprintf('PRACTICAL IMPLICATIONS FOR YOUR PAPER:\n');
fprintf('  - Pheromone fades to 50%% after %.1f seconds\n', half_life);
fprintf('  - Pheromone fades to 10%% of initial after %.1f seconds\n', -log(0.1 - hwc.pheromone_decay_data.residual_fraction)/phi);
fprintf('  - Pheromone reaches steady-state after ~%.0f seconds\n', 5 * tau);
fprintf('\n');
fprintf('IMPORTANT NOTE FOR MANUSCRIPT:\n');
fprintf('  This is a VIRTUAL pheromone model - a software simulation.\n');
fprintf('  Physical LEDs do NOT evaporate. The pheromone is stored as\n');
fprintf('  intensity values in a 2D grid and decays mathematically.\n');
fprintf('\n');
