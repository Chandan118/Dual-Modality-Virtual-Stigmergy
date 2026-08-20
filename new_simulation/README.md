# Real-Space Optical Pheromone Exchange Simulation

A comprehensive MATLAB/Simulink simulation for validating optical pheromone-based swarm robotics navigation in realistic environments.

## Project Overview

This simulation addresses the gap between virtual stigmergy (computational pheromone communication) and real-world optical pheromone exchange. It quantifies how navigation performance is impacted by realistic sensory input, including floor imperfections, sensor noise, and trail overlap.

## Features

### 1. Realistic Floor Surface Model (`RealisticFloor.m`)
- Procedurally generated floor with imperfections
- Dust particle simulation
- Variable reflectivity mapping
- Surface texture noise
- Scratches and marks

### 2. TCRT5000 Sensor Array Model (`TCRT5000SensorArray.m`)
- 4-sensor infrared reflectance array
- Realistic noise modeling:
  - Thermal noise
  - Shot noise
  - 1/f (flicker) noise
  - Quantization noise
- Crosstalk between adjacent sensors
- Trail direction estimation

### 3. WS2812B LED Pheromone Model (`WS2812BPheromone.m`)
- LED spot size modeling (finite light pattern)
- Trail overlap handling (max/additive/average)
- Pheromone decay over time
- Spatial intensity falloff

### 4. Navigation Controller (`NavigationController.m`)
- PID-based trail following
- Dual-mode support:
  - **Ideal Mode**: Perfect sensing, no noise
  - **Realistic Mode**: TCRT5000 sensor readings
- Wheel velocity computation for differential drive

### 5. Performance Comparison Framework (`PerformanceComparator.m`)
- Trail deviation analysis
- Search time comparison
- Success rate metrics
- Path efficiency calculation

## File Structure

```
new Simulation/
├── RealSpace_Pheromone_Simulation.m    # Main simulation script
├── RealisticFloor.m                    # Floor surface model
├── TCRT5000SensorArray.m               # Sensor array model
├── WS2812BPheromone.m                  # LED pheromone model
├── PheromoneMap.m                      # Pheromone interface
├── NavigationController.m              # Navigation controller
├── PerformanceComparator.m             # Comparison framework
├── runSimulation.m                      # Simulation runner
├── generateVisualizations.m             # Visualization functions
├── saveResults.m                        # Results export
├── createSimulinkModel.m               # Simulink model generator
├── createCustomBlocks.m                # Custom S-Function blocks
├── testSimulation.m                    # Component testing
└── README.md                           # This file
```

## Usage

### Quick Start

1. **Open MATLAB** (2026b recommended for MacBook M2)

2. **Navigate to the simulation folder**:
   ```matlab
   cd '/Users/chandansheikder/Documents/Bio-Inspired Thesis/chapter 6 reseach paper/new Simulation'
   ```

3. **Run the full simulation**:
   ```matlab
   RealSpace_Pheromone_Simulation
   ```

### Step-by-Step Execution

1. **Test individual components**:
   ```matlab
   testSimulation
   ```

2. **Create and open Simulink model**:
   ```matlab
   createSimulinkModel
   ```

3. **Create custom S-Function blocks**:
   ```matlab
   createCustomBlocks
   ```

4. **Run the main simulation**:
   ```matlab
   RealSpace_Pheromone_Simulation
   ```

## Simulation Parameters

### Floor Model
- `arena_width`, `arena_height`: Arena dimensions (default: 5.0 x 5.0 m)
- `floor_resolution`: Floor grid resolution (default: 0.005 m)
- `floor_imperfection_level`: Floor roughness factor (default: 0.3)
- `dust_density`: Dust particles per m² (default: 500)
- `reflectivity_base`: Base floor reflectivity (default: 0.8)

### TCRT5000 Sensors
- `num_sensors`: Number of sensors (default: 4)
- `sensor_spacing`: Spacing between sensors (default: 0.012 m)
- `sensor_noise`: Noise amplitude (default: 0.05)
- `sensor_crosstalk`: Crosstalk factor (default: 0.1)

### WS2812B LED
- `led_intensity`: LED brightness (default: 255)
- `led_spot_size`: Light spot diameter (default: 0.02 m)
- `decay_rate`: Trail decay rate (default: 0.02 /s)

### Robot
- `max_speed`: Maximum velocity (default: 0.2 m/s)
- `turn_rate`: Maximum turn rate (default: 2.0 rad/s)
- `robot_radius`: Robot size (default: 0.05 m)

## Output Files

Results are saved to the `./results/` folder:

- `parameters.mat` - Simulation parameters
- `results.mat` - Performance results
- `simData.mat` - Full simulation data
- `results_summary.csv` - CSV summary
- `report.txt` - Text report
- `*.png` - Visualization figures

## Key Metrics

### Performance Comparison: Ideal vs Realistic

| Metric | Ideal | Realistic | Impact |
|--------|-------|-----------|--------|
| Trail Deviation | Low | Higher | Sensor noise effect |
| Search Time | Faster | Slower | Noise & crosstalk |
| Success Rate | 100% | Lower | Sensor limitations |
| Path Efficiency | Higher | Lower | Trail following errors |

## Hardware Specifications (Simulated)

### TCRT5000 Reflective IR Sensor
- Operating range: 0.5mm to 5mm
- Peak wavelength: 850nm (infrared)
- Response time: ~20μs

### WS2812B RGB LED
- Operating voltage: 5V
- Communication: 800kHz
- Color: Red (625nm) for pheromone

## Citation

If you use this simulation in your research, please cite:

```
Real-Space Optical Pheromone Exchange Simulation
Chandan Sheikder, 2026
```

## Troubleshooting

### MATLAB Not Found
Ensure MATLAB 2026b is installed and accessible from terminal:
```bash
which matlab
```

### Simulation Runs Slow
- Reduce simulation time: `params.sim_time = 30;`
- Increase time step: `params.dt = 0.05;`
- Reduce arena size: `params.arena_width = 3;`

### Out of Memory
- Reduce dust density: `params.dust_density = 100;`
- Increase floor resolution: `params.floor_resolution = 0.02;`

## Author

**Chandan Sheikder**
- MacBook M2 Pro
- MATLAB 2026b

## License

This simulation is provided for academic research purposes.

## Acknowledgments

This simulation addresses reviewer feedback regarding the need for realistic sensory modeling in swarm robotics validation.
