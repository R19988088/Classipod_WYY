# Spatial Rain Engine Implementation Plan

> **For AI workers:** Execute inline with TDD and preserve the dirty worktree.

**Goal:** Add an Android-first procedural spatial rain renderer with four
acoustically distinct weather scenes and a portable Dart fallback.

**Architecture:** C++ renders deterministic PCM ranges from independent spatial
events. Dart dynamically loads the renderer on Android and keeps the current
`StreamAudioSource` contract. CMake packages the renderer with the APK.

**Tech stack:** C++17, Android NDK/CMake, `dart:ffi`, Flutter/just_audio.

---

### Task 1: Native acoustic contract

**Files:**
- Create: `android/app/src/main/cpp/spatial_rain_engine.h`
- Create: `android/app/src/main/cpp/spatial_rain_engine_test.cpp`

- [x] Define the four scene IDs and a C API that renders an absolute stereo PCM
  frame range.
- [x] Add a native executable test for determinism, range continuity, stereo
  separation, scene distinction, density, and thunder transients.
- [x] Compile the test before implementation and confirm the missing symbols
  fail the link.

### Task 2: Spatial rain synthesis

**Files:**
- Create: `android/app/src/main/cpp/spatial_rain_engine.cpp`

- [x] Implement deterministic event distributions for near, mid, far, front,
  rear, left, and right drop positions.
- [x] Implement material-dependent impact resonances, distance filtering,
  propagation delay, early reflections, diffuse rain beds, wind, and thunder.
- [x] Encode spatial events to a second-order ambisonic basis and decode to
  stereo with a layout-independent decoder boundary.
- [x] Add soft limiting and TPDF dither, then pass the native executable test.

### Task 3: Android packaging and Dart bridge

**Files:**
- Create: `android/app/src/main/cpp/CMakeLists.txt`
- Create: `lib/features/white_noise/services/native_spatial_rain_renderer.dart`
- Modify: `android/app/build.gradle.kts`
- Modify: `lib/features/white_noise/services/procedural_audio_source.dart`
- Modify: `test/unit_tests/procedural_audio_source_test.dart`

- [x] Add CMake external native build configuration.
- [x] Add an FFI bridge that loads only on Android and returns `null` when the
  native renderer is absent.
- [x] Route only the four rain scenes through native aligned PCM rendering;
  retain Dart rendering for all other sounds and platforms.
- [x] Move the stream to 48 kHz and verify arbitrary byte ranges still match.

### Task 4: Verification

**Files:** all files above.

- [x] Run the C++ acoustic test under AddressSanitizer.
- [x] Run the procedural, sound-model, controller, and player-service Flutter
  unit tests.
- [x] Run scoped Flutter analysis; full analysis remains blocked by existing
  errors under `0_backup/`.
- [x] Build an arm64 production APK and inspect the APK for the native library.
- [x] Run `git diff --check` and review only the scoped changes.
