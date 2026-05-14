# Experiment 6: CNN Detection — Protocol

## Objective

Validate TensorRT-based target recognition on Azure Kinect RGB stream. Target: ≥ 92% mAP across 3 classes and 3 lighting conditions.

## Required Hardware

- Azure Kinect camera
- 3 target objects: red cube, green cylinder, blue sphere
- TensorRT engine (optional) or YOLOv8 weights

## Prerequisites

```bash
# 1. Bringup the robot with camera
ros2 launch formica_experiments bringup_launch.py

# 2. Run the CNN experiment
ros2 run formica_experiments exp6_cnn

# Auto-run mode (no manual input)
ros2 run formica_experiments exp6_cnn --ros-args -p auto_run:=true
```

## Detection Model Options

| Priority | Model | Path | Fallback |
|----------|-------|------|----------|
| 1 | TensorRT engine | ~/models/formica_target_det.trt | YOLOv8 |
| 2 | YOLOv8 weights | ~/models/yolov8n.pt | HSV blob |
| 3 | HSV colour blob | Built-in | — |

The node reports which model is active in the output.

## Detection Classes

| Class ID | Name | HSV Range |
|----------|------|-----------|
| 0 | red_cube | Red hue (0-10°, 170-180°) |
| 1 | green_cylinder | Green hue (40-80°) |
| 2 | blue_sphere | Blue hue (100-130°) |

## Test Conditions

| Condition | Description |
|-----------|-------------|
| normal | Standard lab lighting |
| low_light | Reduced illumination |
| high_clutter | Additional visual noise |

## Test Distances

5 distances: 0.5 m, 1.0 m, 1.5 m, 2.0 m, 2.5 m

## Parameters

| Parameter | Old Value | New Value | Rationale |
|-----------|-----------|-----------|-----------|
| CONF_THRESHOLD | 0.85 | 0.25 | Better detection rate |
| IOU_THRESHOLD | 0.50 | 0.50 | Standard |
| MAP_TARGET | 0.92 | 0.92 | No change |

## Events Per Condition

30 frames per (condition × distance × class) combination

## Data Output

```
exp6_cnn_<timestamp>.csv           # Detection metrics
```

## CSV Columns

| Column | Description |
|--------|-------------|
| condition | Lighting condition |
| distance_m | Test distance (m) |
| class_name | Target class name |
| TP | True positives |
| FP | False positives |
| FN | False negatives |
| precision | TP / (TP + FP) |
| recall | TP / (TP + FN) |
| F1 | 2×P×R / (P+R) |
| AP | Average precision (P×R) |

## Metrics Computation

```
precision = TP / (TP + FP)
recall    = TP / (TP + FN)
F1        = 2 × precision × recall / (precision + recall)
AP        = precision × recall  (per distance)
mAP       = mean(AP) across all conditions
```

## Remediation Notes (Applied)

- Added multiple model path fallbacks
- Reduced confidence threshold: 0.85 → 0.25
- Added YOLOv8 support with proper weight loading
- Verified image dimensions (640×640 to match training)
- Reports which model is active (TensorRT/YOLO/HSV)

## After Running

1. Copy results to v1:
   ```bash
   cp ~/formica_experiments/data/exp6_cnn_<timestamp>.csv \
      ~/formica_experiments/data/v1/exp6_cnn_detection/results/
   ```

2. Calculate per-class and overall mAP

3. Record which model was used (TensorRT/YOLO/HSV) in `analysis.md`
