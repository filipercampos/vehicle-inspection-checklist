# vehicle-inspection-checklist

Electronic pre-trip **vehicle inspection checklist** for light-vehicle fleets (cars, SUVs, pickups), built in **Flutter** (web + Android).
Body damage is recorded on an **interactive 3D model of the vehicle** (hatchback, SUV or double-cab pickup, matching the vehicle being inspected): drag to rotate, tap a part to mark it.
Runs entirely on **mock data** — no backend, no API keys, no accounts. Open it and try it in 30 seconds.

**Live demo:** https://filipercampos.github.io/vehicle-inspection-checklist/ (pick any inspector to sign in).

## Run

```bash
flutter pub get
flutter run -d chrome        # or: flutter run -d <android-device>
```

Sign in by picking any inspector (mock auth), choose a vehicle and fill the checklist.

## What it does

| Screen | Highlights |
|---|---|
| Fleet | Search by plate/model, filter by vehicle type, last verdict per vehicle |
| Inspection (wizard) | Step by step: **Vehicle** (odometer + fuel) → **Body** (3D damage map: tap hood, doors, bumpers, wheels, lights, mirrors… → scratch / dent / broken / missing) → **one page per checklist section** (OK / Defect / N/A, "All OK") → **Review** (summary, live verdict, signature, submit). Each step is validated before moving on; step chips show done / issue status and allow jumping back |
| Report | Verdict banner, read-only 3D damage view, defects first, all answers, duration, template version, signature |
| History | All inspections filtered by verdict |
| Dashboard | Inspections today, blocked vehicles, fleet status bar, most frequent defects |

### Business rules (`lib/domain/inspection_rules.dart`)

- Any **critical** item with a defect → **Blocked — do not dispatch**.
- A **broken or missing safety part** on the 3D map (windshield, wheels, lights, mirrors) → **Blocked**.
- Any other defect or body damage → **Approved with restrictions**; nothing found → **Approved**.
- Every item must be answered; defects need a description; critical items cannot be N/A.
- Odometer cannot be lower than the vehicle's last reading (which advances after each submit).
- Fuel level and inspector signature are mandatory.
- Templates are versioned and every inspection stores `templateId` + `templateVersion`.

## Architecture

```
lib/
  domain/   models + pure rules (no Flutter widgets, unit-tested)
  data/     InspectionRepository port + InMemory adapter with seed data and simulated latency
  state/    Riverpod providers; DraftNotifier keeps an in-progress inspection per vehicle
  features/ screens (login, fleet, inspection, report, history, dashboard)
  ui/       theme (light/dark), shared widgets, signature pad
  ui/car3d/ vehicle viewer: pre-rendered Blender turntable + per-pixel part map (hit testing, damage tint)
tool/blender/ scripts that model each vehicle type and render its turntable and part map into assets/<type>/
  app.dart  go_router with auth redirect + StatefulShellRoute behind a navigation drawer
```

Design decisions:

- **Repository port** — the UI only knows `InspectionRepository`. Swapping mocks for an HTTP API is one provider override.
- **Rules outside widgets** — verdict and validation are pure functions, so the same rules are trivially shared with a backend.
- **Drafts survive navigation** — the draft provider is not auto-disposed; leaving the screen does not lose answers.
- **Photoreal 3D without a 3D engine** — each vehicle type is modelled procedurally in Blender from one spec-driven script (`tool/blender/build_vehicle.py`: subdivided body with real panel gaps, alloy wheels, lights, cladding, an open cargo bed for the pickup) and rendered with Cycles as a 36-frame orbit plus a plan view (`render_turntable.py`). The same scene is rendered a second time with one flat colour per `CarPart`; that pass is run-length encoded into `assets/<type>/parts.bin` (~150 KB for 37 frames). At runtime the viewer only swaps frames while dragging, looks the pointer up in the part map and tints damaged parts with a `color` blend that keeps the render's shading. No WebView, no runtime 3D dependency, ~1.3 MB of assets per vehicle type, identical on web and Android, and hit testing is a plain unit test. Re-render with `VEHICLE=pickup blender -b --factory-startup -P tool/blender/render_turntable.py` (`suv`, `car` or `pickup`).
- **Wizard with per-step rules** — `InspectionRules` exposes `readingErrors` and `sectionErrors`; the wizard blocks "Next" on the same rules the final `validate` uses.
- **Theme tokens** — `AppPalette` holds semantic colour tokens (`--bg`, `--surface`, `--accent`, `--ok`, `--warn`, `--bad`, `--amber`), Geist font, dark by default with a toggle.
- **Signature as vectors** — normalized strokes are tiny, resolution-independent and render identically in form and report.

## Tests

```bash
flutter analyze
flutter test
```

- Unit: verdict and validation rules (including body damage), repository, part map of every vehicle type (every part reachable, hit testing per view, damage regions).
- Widget: auth redirect, fleet statuses, wizard blocks invalid steps and goes back, "All OK", 3D tap → damage sheet → restricted verdict, theme toggle, full happy path (readings → body → sections → sign → submit → report).

## Stack

Flutter · Dart 3 · Riverpod 3 · go_router · intl · google_fonts (Geist)
