# Spatial Rain Engine Design

## Goal

Replace the four rain presets' volume-shaped noise with a deterministic,
procedural spatial scene that remains convincing on stereo speakers and can be
decoded to 5.1 later without redesigning the rain model.

## Architecture

Android renders rain in a small C++ DSP library. Dart keeps ownership of the
existing two-hour seekable WAV stream and delegates aligned PCM ranges to the
native renderer. If the library is absent, including non-Android platforms,
the existing Dart renderer remains the fallback.

The native scene is expressed as independent acoustic events rather than output
channels. Each drop has azimuth, front/back depth, distance, height, size,
surface, arrival time, and reflection parameters. Events are encoded through a
second-order ambisonic basis and decoded to the requested output layout. The
first decoder is stereo; the event and bus representation remains independent
of that decoder so a 5.1 matrix can be added without changing weather synthesis.

## Weather Models

- Drizzle: sparse small drops, close transient detail, broad outdoor depth,
  little wind, and a quiet diffuse rain bed.
- Heavy rain: dense overlapping near/mid/far drops, multiple impact surfaces,
  stronger diffuse canopy and ground reflections.
- Storm: heavy rain plus a moving wind field, gust-driven direction changes,
  lower-frequency sheets, and occasional distant thunder.
- Lightning storm: storm bed plus irregular close and distant strikes. A strike
  has a sharp leader/crack, delayed multi-path tearing, distance-dependent high
  frequency loss, and a long spatial rumble.

Changing preset changes event distributions and acoustic structure, not only
gain. Near drops retain high-frequency attack and inter-channel arrival-time
differences. Far drops lose high frequencies, become more diffuse, and carry a
higher reflected-to-direct ratio. Rear events use spectral and reflection cues
in addition to channel level so stereo speakers convey depth without claiming
literal rear-speaker localization.

## Rendering And Performance

The stream uses 48 kHz stereo 16-bit PCM for broad Android compatibility.
Rendering is stateless by absolute frame position, so seeking and range retries
remain deterministic. A chunk first receives its diffuse weather bed, then only
drop and thunder events whose finite responses overlap that chunk are mixed.
This avoids evaluating every virtual source for every sample. Final output uses
soft limiting and deterministic TPDF dither.

## Validation

Native tests verify deterministic range rendering, chunk-boundary continuity,
non-collapsed stereo, distinct spectra/dynamics for all four scenes, dense event
activity, and lightning transients above the rain bed. Dart tests retain WAV
range, header, controller, and fallback coverage. Android build verification
must confirm that `libclassipod_spatial_audio.so` is packaged for arm64-v8a.
