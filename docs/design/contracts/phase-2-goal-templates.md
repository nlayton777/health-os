# Phase 2 — Goal Templates Contract

Predefined goal templates for the Goal UI. Users can select a template as a starting point.

---

## Goal Templates (JSON)

```json
[
  {
    "category": "strength",
    "templates": [
      { "title": "Back Squat", "target_unit": "lbs", "benchmark_test_type": "1rm_test", "default_cadence_weeks": 8 },
      { "title": "Bench Press", "target_unit": "lbs", "benchmark_test_type": "1rm_test", "default_cadence_weeks": 8 },
      { "title": "Deadlift", "target_unit": "lbs", "benchmark_test_type": "1rm_test", "default_cadence_weeks": 8 },
      { "title": "Overhead Press", "target_unit": "lbs", "benchmark_test_type": "1rm_test", "default_cadence_weeks": 8 },
      { "title": "Strict Pull-ups", "target_unit": "reps", "benchmark_test_type": "max_reps_test", "default_cadence_weeks": 8 }
    ]
  },
  {
    "category": "endurance",
    "templates": [
      { "title": "5K Run Time", "target_unit": "seconds", "benchmark_test_type": "race_effort", "default_cadence_weeks": 12 },
      { "title": "10K Run Time", "target_unit": "seconds", "benchmark_test_type": "race_effort", "default_cadence_weeks": 16 },
      { "title": "Half Marathon Time", "target_unit": "seconds", "benchmark_test_type": "race_effort", "default_cadence_weeks": 16 },
      { "title": "100K Cycling Time", "target_unit": "seconds", "benchmark_test_type": "race_effort", "default_cadence_weeks": 16 },
      { "title": "FTP (Cycling)", "target_unit": "watts", "benchmark_test_type": "ftp_test", "default_cadence_weeks": 12 }
    ]
  },
  {
    "category": "body_composition",
    "templates": [
      { "title": "Body Weight", "target_unit": "lbs", "benchmark_test_type": "scale", "default_cadence_weeks": 1 },
      { "title": "Body Fat Percentage", "target_unit": "percent", "benchmark_test_type": "dexa_scan", "default_cadence_weeks": 13 },
      { "title": "Lean Body Mass", "target_unit": "lbs", "benchmark_test_type": "dexa_scan", "default_cadence_weeks": 13 }
    ]
  },
  {
    "category": "biomarker",
    "templates": [
      { "title": "Testosterone", "target_unit": "ng/dL", "benchmark_test_type": "lab_work", "default_cadence_weeks": 13 },
      { "title": "CRP (C-Reactive Protein)", "target_unit": "mg/L", "benchmark_test_type": "lab_work", "default_cadence_weeks": 13 },
      { "title": "Total Cholesterol", "target_unit": "mg/dL", "benchmark_test_type": "lab_work", "default_cadence_weeks": 26 },
      { "title": "Fasting Glucose", "target_unit": "mg/dL", "benchmark_test_type": "lab_work", "default_cadence_weeks": 13 }
    ]
  },
  {
    "category": "recovery",
    "templates": [
      { "title": "Average Sleep Duration", "target_unit": "hours", "benchmark_test_type": "auto_tracked", "default_cadence_weeks": 4 },
      { "title": "Average HRV", "target_unit": "ms", "benchmark_test_type": "auto_tracked", "default_cadence_weeks": 4 },
      { "title": "Average Resting Heart Rate", "target_unit": "bpm", "benchmark_test_type": "auto_tracked", "default_cadence_weeks": 4 }
    ]
  }
]
```
