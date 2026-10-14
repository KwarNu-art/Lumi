# Lumi — iPhone 7 Plus / iOS 15 prototype

Lumi is a small Theos tweak prototype that displays a floating status panel in **SpringBoard only**. It is not a system optimizer and does not change app graphics, CPU/GPU clocks, display refresh rate, or thermal limits.

## Current prototype features
- Floating `L` button while SpringBoard is active.
- Battery percentage where iOS reports it.
- iOS thermal state (`Normal`, `Fair`, `Serious`, `Critical`).
- Best-effort CPU estimate for the SpringBoard process only.
- A rough display-link callback rate while the panel is open (not game/app FPS and not a guaranteed refresh-rate measurement).

## Requirements
- iPhone 7 Plus (arm64) running iOS 15.x.
- A compatible jailbreak and tweak injection environment.
- Rootless and rootful packages are built separately by GitHub Actions. Install only the package matching your jailbreak's filesystem model.

## Build on GitHub (no Mac required)
1. Create a new GitHub repository named `Lumi`.
2. Upload the files and folders from this project, preserving `.github/workflows/build.yml`.
3. Commit to the `main` branch.
4. Open **Actions** and select **Build Lumi**. If prompted, enable workflows.
5. Wait for the run to finish, then open the run's **Artifacts** section and download `lumi-builds`.
6. Choose the `.deb` under `rootless` or `rootful` that matches your jailbreak.

The workflow uses Theos and the community `Randomblock1/theos-action` setup action. Review upstream actions and dependencies before relying on them in a personal repository.

## Before installing
First identify your jailbreak and package layout. Do not install both packages. If you do not know whether your jailbreak is rootless or rootful, stop and identify it before installation. Keep a way to remove the package if SpringBoard becomes unstable.

Install the matching `.deb` using your jailbreak's package manager. If SpringBoard crashes or loops, use Safe Mode or the jailbreak's tweak-disable/recovery instructions to remove `com.lumi.iphone`.

## Important limitations
- **Not a 100% heat reducer:** heat depends on battery health, workload, signal strength, charging, ambient temperature, and iOS thermal management.
- **No 120 Hz:** iPhone 7 Plus has a 60 Hz display. A tweak cannot make its physical display refresh at 120 Hz.
- **No universal graphics slider:** apps control their own graphics settings; a general injected tweak cannot safely force all apps to render at lower quality.
- **No guaranteed freeze prevention:** the panel cannot fix failing batteries, storage issues, OS bugs, or hardware faults.
- **CPU scope:** the CPU estimate is for SpringBoard only, not all running processes.
- **GPU and temperature:** private/system interfaces vary by OS and jailbreak. This prototype does not claim a precise GPU percentage or Celsius temperature.
- **Battery health:** check Settings → Battery → Battery Health & Charging. If the phone becomes extremely hot, swells, shuts down repeatedly, or the screen becomes unresponsive, stop using/charging it and have the battery/device inspected.

## Project files
- `Lumi.m` — Objective-C implementation
- `Makefile` — Theos build settings
- `control` — Debian package metadata
- `Lumi.plist` — injection filter (SpringBoard only)
- `.github/workflows/build.yml` — GitHub Actions build

This is an experimental starter, not a tested release. The GitHub workflow must complete successfully before a compiled package exists.
