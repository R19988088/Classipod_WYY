#include "spatial_rain_engine.h"

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <new>
#include <vector>

namespace {

constexpr int kSampleRate = 48000;
constexpr int kChannels = 2;
constexpr double kPi = 3.14159265358979323846;
constexpr double kSpeedOfSound = 343.0;

struct SceneProfile {
  double drops_per_second;
  double bed_gain;
  double drop_gain;
  double near_probability;
  double minimum_drop_size;
  double maximum_drop_size;
  double wind_gain;
  double thunder_interval;
};

struct StereoGain {
  double left;
  double right;
};

uint64_t Mix(uint64_t value) {
  value ^= value >> 30;
  value *= 0xbf58476d1ce4e5b9ULL;
  value ^= value >> 27;
  value *= 0x94d049bb133111ebULL;
  return value ^ (value >> 31);
}

uint64_t Key(uint64_t seed, int64_t index, uint64_t salt) {
  return Mix(seed ^ Mix(static_cast<uint64_t>(index)) ^ salt);
}

double Unit(uint64_t seed, int64_t index, uint64_t salt) {
  constexpr double scale = 1.0 / static_cast<double>(1ULL << 53);
  return static_cast<double>(Key(seed, index, salt) >> 11) * scale;
}

double Bipolar(uint64_t seed, int64_t index, uint64_t salt) {
  return Unit(seed, index, salt) * 2.0 - 1.0;
}

int64_t FloorDiv(int64_t value, int64_t divisor) {
  int64_t quotient = value / divisor;
  const int64_t remainder = value % divisor;
  if (remainder != 0 && ((remainder < 0) != (divisor < 0))) --quotient;
  return quotient;
}

double SmoothNoise(int64_t frame,
                   int64_t step,
                   uint64_t seed,
                   uint64_t salt) {
  const int64_t left = FloorDiv(frame, step);
  const double fraction =
      static_cast<double>(frame - left * step) / static_cast<double>(step);
  const double eased = fraction * fraction * (3.0 - 2.0 * fraction);
  return Bipolar(seed, left, salt) * (1.0 - eased) +
         Bipolar(seed, left + 1, salt) * eased;
}

SceneProfile Profile(int32_t scene) {
  switch (static_cast<SpatialRainScene>(scene)) {
    case SpatialRainScene::kDrizzle:
      return {34.0, 0.028, 0.19, 0.34, 0.05, 0.30, 0.0, 0.0};
    case SpatialRainScene::kHeavyRain:
      return {245.0, 0.120, 0.38, 0.48, 0.18, 1.0, 0.0, 0.0};
    case SpatialRainScene::kStorm:
      return {315.0, 0.145, 0.42, 0.40, 0.20, 1.0, 0.48, 17.0};
    case SpatialRainScene::kLightningStorm:
      return {285.0, 0.130, 0.39, 0.38, 0.20, 1.0, 0.44, 18.5};
  }
  return {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0};
}

StereoGain DecodeSecondOrder(double azimuth,
                             double elevation,
                             double distance) {
  const double cos_elevation = std::cos(elevation);
  const double x = std::cos(azimuth) * cos_elevation;
  const double y = std::sin(azimuth) * cos_elevation;
  const double z = std::sin(elevation);

  // ACN/SN3D-like basis. Keeping this boundary explicit lets a 5.1 decoder
  // replace only the matrix while the rain scene remains unchanged.
  const double w = 0.70710678118;
  const double v = x * y;
  const double t = z * y;
  const double r = 1.5 * z * z - 0.5;
  const double s = z * x;
  const double u = 0.5 * (x * x - y * y);
  double left = 0.46 * w + 0.30 * x + 0.39 * y + 0.08 * v + 0.05 * t +
                0.06 * r + 0.04 * s + 0.09 * u;
  double right = 0.46 * w + 0.30 * x - 0.39 * y - 0.08 * v - 0.05 * t +
                 0.06 * r + 0.04 * s + 0.09 * u;

  // Stereo speakers cannot produce literal rear localization. Rearward sources
  // therefore carry narrower direct sound; their reflections restore width.
  const double rear = std::max(0.0, -x);
  const double rear_narrowing = 1.0 - rear * 0.34;
  left *= rear_narrowing;
  right *= rear_narrowing;
  const double normalization = 1.05 / std::sqrt(std::max(0.35, distance));
  return {left * normalization, right * normalization};
}

double DropSignal(int64_t event,
                  int sample,
                  int duration,
                  double size,
                  double distance,
                  int surface,
                  uint64_t seed,
                  bool reflected) {
  if (sample < 0 || sample >= duration) return 0.0;
  const double time = static_cast<double>(sample) / kSampleRate;
  const double attack = 1.0 - std::exp(-time * (reflected ? 900.0 : 2400.0));
  const double decay_rate =
      (72.0 - size * 28.0) * (reflected ? 0.46 : 1.0);
  const double envelope = attack * std::exp(-time * decay_rate);
  const double far_loss = 1.0 / (1.0 + distance * 0.055);
  const int noise_step = 1 + static_cast<int>(distance * 0.16) +
                         (reflected ? 2 : 0);
  const double burst = SmoothNoise(sample, noise_step, seed,
                                   0x8128ULL + event * 0x91ULL);

  const double base =
      surface == 0 ? 1280.0 : surface == 1 ? 720.0 : surface == 2 ? 2380.0
                                                             : 410.0;
  const double frequency = base * (0.72 + size * 0.68) /
                           (1.0 + distance * 0.006);
  const double phase = 2.0 * kPi * frequency * time;
  const double resonance =
      std::sin(phase) + 0.31 * std::sin(phase * 1.93 + 0.7) +
      (surface == 2 ? 0.18 * std::sin(phase * 3.14 + 1.1) : 0.0);
  const double tonal = resonance * std::exp(-time * (38.0 + surface * 7.0));
  return (burst * (0.72 + 0.28 * far_loss) + tonal * 0.36) * envelope;
}

void AddDrop(std::vector<double>* mix,
             int64_t chunk_start,
             int frame_count,
             int64_t event,
             int64_t event_frame,
             const SceneProfile& profile,
             uint64_t seed) {
  const double chooser = Unit(seed, event, 0xd001ULL);
  double distance;
  if (chooser < profile.near_probability) {
    distance = 0.55 + 2.8 * std::pow(Unit(seed, event, 0xd002ULL), 1.8);
  } else if (chooser < 0.86) {
    distance = 3.4 + 8.0 * Unit(seed, event, 0xd003ULL);
  } else {
    distance = 11.5 + 22.0 * Unit(seed, event, 0xd004ULL);
  }
  const double azimuth = Bipolar(seed, event, 0xd005ULL) * kPi;
  const double elevation =
      0.08 + Unit(seed, event, 0xd006ULL) * (kPi * 0.39);
  const double size =
      profile.minimum_drop_size +
      (profile.maximum_drop_size - profile.minimum_drop_size) *
          std::pow(Unit(seed, event, 0xd007ULL), 1.5);
  const int surface = static_cast<int>(Unit(seed, event, 0xd008ULL) * 4.0);
  const int duration = static_cast<int>(
      kSampleRate * (0.018 + size * 0.047 + std::min(distance, 20.0) * 0.0014));
  const double distance_gain = 1.0 / (0.72 + distance * 0.31);
  const double rear = std::max(0.0, -std::cos(azimuth));
  const double air_loss = std::exp(-distance * (0.025 + size * 0.008));
  const double amplitude = profile.drop_gain * (0.38 + size * 0.92) *
                           distance_gain * air_loss;
  const StereoGain direct = DecodeSecondOrder(azimuth, elevation, distance);
  const double head_delay = std::sin(azimuth) * 0.00062;
  const int left_delay = static_cast<int>(std::max(0.0, head_delay) * kSampleRate);
  const int right_delay =
      static_cast<int>(std::max(0.0, -head_delay) * kSampleRate);

  const double reflection_ratio =
      std::min(0.62, 0.13 + distance * 0.018 + rear * 0.16);
  const int reflection_delay = static_cast<int>(
      kSampleRate * (0.006 + distance / kSpeedOfSound * 0.72 +
                     0.018 * Unit(seed, event, 0xd009ULL)));
  const StereoGain reflection =
      DecodeSecondOrder(-azimuth * 0.72, -elevation * 0.32, distance + 4.0);
  const int response_end = duration + reflection_delay;
  const int64_t local_start =
      std::max<int64_t>(0, event_frame - chunk_start - 32);
  const int64_t local_end = std::min<int64_t>(
      frame_count, event_frame - chunk_start + response_end + 32);

  for (int64_t local = local_start; local < local_end; ++local) {
    const int64_t absolute = chunk_start + local;
    const int direct_sample = static_cast<int>(absolute - event_frame);
    const double left_signal = DropSignal(event, direct_sample - left_delay,
                                          duration, size, distance, surface,
                                          seed, false);
    const double right_signal = DropSignal(event, direct_sample - right_delay,
                                           duration, size, distance, surface,
                                           seed, false);
    const int reflected_sample = direct_sample - reflection_delay;
    const double reflected = DropSignal(event, reflected_sample, duration, size,
                                        distance + 4.0, surface, seed, true);
    (*mix)[local * 2] +=
        amplitude * (left_signal * direct.left +
                     reflected * reflection.left * reflection_ratio);
    (*mix)[local * 2 + 1] +=
        amplitude * (right_signal * direct.right +
                     reflected * reflection.right * reflection_ratio);
  }
}

double ThunderSignal(int64_t frame,
                     int64_t strike_frame,
                     int64_t strike,
                     double distance,
                     int channel,
                     double pan,
                     uint64_t seed) {
  const double delay = (channel == 0 ? std::max(0.0, pan)
                                     : std::max(0.0, -pan)) *
                       0.0014;
  const double local =
      static_cast<double>(frame - strike_frame) / kSampleRate - delay;
  if (local < 0.0 || local >= 11.8) return 0.0;
  const double pan_gain = std::sqrt(std::clamp(
      channel == 0 ? (1.0 - pan) * 0.5 : (1.0 + pan) * 0.5, 0.0, 1.0));
  const auto snap = [&](double start, double gain, uint64_t salt) {
    const double time = local - start;
    if (time < 0.0 || time >= 0.032) return 0.0;
    const int64_t sample = static_cast<int64_t>(time * kSampleRate);
    const double white = Bipolar(seed, sample, salt);
    const double previous =
        sample > 0 ? Bipolar(seed, sample - 1, salt) : white;
    const double spike = Unit(seed, sample, salt + 1) < 0.026
                             ? Bipolar(seed, sample, salt + 2) * 2.1
                             : 0.0;
    return gain * std::tanh((white - previous * 0.98) * 2.3 + spike) *
           std::exp(-time * 145.0);
  };
  const auto arc_tail = [&](double time) {
    if (time < 0.0 || time >= 0.115) return 0.0;
    const int64_t sample = static_cast<int64_t>(time * kSampleRate);
    const double white = Bipolar(seed, sample, 0xa020ULL + strike * 17 + channel);
    const double previous = sample > 0
                                ? Bipolar(seed, sample - 1,
                                          0xa020ULL + strike * 17 + channel)
                                : white;
    const double high_pass = white - previous * 0.985;
    const double impulse = Unit(seed, sample, 0xa021ULL + strike * 19 + channel) <
                                   (time < 0.012 ? 0.34 : time < 0.05 ? 0.12 : 0.04)
                               ? Bipolar(seed, sample,
                                         0xa022ULL + strike * 23 + channel) *
                                     1.4
                               : 0.0;
    return std::tanh((high_pass * 1.55 + impulse) * 1.2) *
           std::exp(-time * 55.0) * 0.46;
  };
  const auto sub_bass = [&](double time, double gain) {
    if (time < 0.0 || time >= 2.5) return 0.0;
    const double phase = 2.0 * kPi *
                         (25.0 * time +
                          80.0 * (1.0 - std::exp(-time * 0.8)) / 0.8);
    const double envelope = std::exp(-time * 1.2);
    return gain * (std::sin(phase) * 0.70 + std::sin(phase * 2.0) * 0.20 +
                   std::sin(phase * 0.5) * 0.30) *
           envelope * std::tanh(envelope * 2.0);
  };

  // Reference chain: return stroke, arc tail, bass impact, two branch
  // re-strikes, then independently moving rolling and distant reflections.
  const double branch_one = 0.045 + Unit(seed, strike, 0xa030ULL) * 0.060;
  const double branch_two = branch_one + 0.030 +
                            Unit(seed, strike, 0xa031ULL) * 0.070;
  double crack = snap(0.0, 1.20, 0xa010ULL + strike * 29 + channel * 3) +
                 arc_tail(local - 0.003) +
                 snap(branch_one, 0.68,
                      0xa011ULL + strike * 31 + channel * 5) +
                 snap(branch_two, 0.40,
                      0xa012ULL + strike * 37 + channel * 7);
  const double boom = sub_bass(local - 0.005, 1.20) +
                      sub_bass(local - branch_one - 0.010, 0.70);

  const double rumble_time = local - 0.080;
  double rumble = 0.0;
  if (rumble_time >= 0.0 && rumble_time < 7.0) {
    const int64_t rumble_frame =
        static_cast<int64_t>(rumble_time * kSampleRate);
    const double brown =
        0.56 * SmoothNoise(rumble_frame, 110, seed,
                           0xa040ULL + strike * 41 + channel * 7) +
        0.29 * SmoothNoise(rumble_frame, 310, seed,
                           0xa041ULL + strike * 43 + channel * 11) +
        0.15 * SmoothNoise(rumble_frame, 760, seed,
                           0xa042ULL + strike * 47 + channel * 13);
    const double roll_fast =
        0.5 + 0.5 * std::sin(rumble_time * 2.3 + strike * 0.71 + channel);
    const double roll_slow = 0.5 +
                             0.5 * std::sin(rumble_time * 0.7 +
                                            strike * 1.37 + channel * 3.0);
    const double envelope = std::pow(std::max(0.0, 1.0 - rumble_time / 7.0),
                                     1.5);
    rumble = brown * (0.40 + 0.60 * roll_fast * roll_slow) * envelope * 5.80;
  }

  double echoes = 0.0;
  for (int echo = 0; echo < 2; ++echo) {
    const double echo_delay = echo == 0
                                  ? 0.18 + Unit(seed, strike, 0xa050ULL) * 0.15
                                  : 0.40 + Unit(seed, strike, 0xa051ULL) * 0.30;
    const double echo_time = local - echo_delay;
    if (echo_time < 0.0 || echo_time >= (echo == 0 ? 5.0 : 7.0)) continue;
    const int64_t echo_frame = static_cast<int64_t>(echo_time * kSampleRate);
    const double low_pass_noise =
        0.68 * SmoothNoise(echo_frame, 350 + echo * 170, seed,
                           0xa060ULL + strike * 53 + echo * 17 + channel * 3) +
        0.32 * SmoothNoise(echo_frame, 860 + echo * 290, seed,
                           0xa061ULL + strike * 59 + echo * 19 + channel * 5);
    echoes += low_pass_noise * std::exp(-echo_time * (0.50 + echo * 0.20)) *
              (echo == 0 ? 0.34 : 0.22);
  }
  return (crack + boom + rumble + echoes) * pan_gain /
         (0.78 + distance * 0.048);
}

void AddThunder(std::vector<double>* mix,
                int32_t scene,
                int64_t start_frame,
                int frame_count,
                const SceneProfile& profile,
                uint64_t seed) {
  if (profile.thunder_interval <= 0.0) return;
  const int64_t interval =
      static_cast<int64_t>(profile.thunder_interval * kSampleRate);
  const int64_t first = FloorDiv(start_frame - 13 * kSampleRate, interval) - 1;
  const int64_t last = FloorDiv(start_frame + frame_count, interval) + 1;
  for (int64_t strike = first; strike <= last; ++strike) {
    const double jitter = 0.12 + 0.58 * Unit(seed, strike, 0xb001ULL + scene);
    const int64_t strike_frame =
        strike * interval + static_cast<int64_t>(jitter * interval);
    const bool close = scene == 3 && Unit(seed, strike, 0xb002ULL) > 0.42;
    const double distance = close
                                ? 1.8 + 7.5 * Unit(seed, strike, 0xb003ULL)
                                : 12.0 + 32.0 * Unit(seed, strike, 0xb004ULL);
    const double pan = Bipolar(seed, strike, 0xb005ULL) * 0.86;
    const double scene_gain = scene == 3 ? 1.42 : 0.38;
    for (int local = 0; local < frame_count; ++local) {
      const int64_t frame = start_frame + local;
      (*mix)[local * 2] += scene_gain * ThunderSignal(
                                           frame, strike_frame, strike,
                                           distance, 0, pan, seed);
      (*mix)[local * 2 + 1] += scene_gain * ThunderSignal(
                                               frame, strike_frame, strike,
                                               distance, 1, pan, seed);
    }
  }
}

void AddDiffuseBed(std::vector<double>* mix,
                   int32_t scene,
                   int64_t start_frame,
                   int frame_count,
                   const SceneProfile& profile,
                   uint64_t seed) {
  for (int frame = 0; frame < frame_count; ++frame) {
    const int64_t absolute = start_frame + frame;
    const double drift =
        0.74 + 0.26 * (SmoothNoise(absolute, kSampleRate * 3, seed,
                                   0xc001ULL + scene) +
                       1.0) *
                          0.5;
    const double common =
        0.48 * SmoothNoise(absolute, 2, seed, 0xc010ULL + scene) +
        0.31 * SmoothNoise(absolute, 9, seed, 0xc020ULL + scene) +
        0.21 * SmoothNoise(absolute, 41, seed, 0xc030ULL + scene);
    const double left_side =
        SmoothNoise(absolute, 5, seed, 0xc040ULL + scene) * 0.48;
    const double right_side =
        SmoothNoise(absolute, 7, seed, 0xc050ULL + scene) * 0.48;
    const double far_layer =
        SmoothNoise(absolute, 113, seed, 0xc060ULL + scene) * 0.34;
    (*mix)[frame * 2] +=
        profile.bed_gain * drift * (common * 0.74 + left_side + far_layer);
    (*mix)[frame * 2 + 1] +=
        profile.bed_gain * drift * (common * 0.74 + right_side + far_layer);

    if (profile.wind_gain > 0.0) {
      const double gust_shape = std::pow(
          (SmoothNoise(absolute, kSampleRate * 2, seed, 0xc070ULL + scene) +
           1.0) *
              0.5,
          1.7);
      const double gust = 0.52 + 0.72 * gust_shape;
      const double direction = SmoothNoise(absolute, kSampleRate * 5, seed,
                                           0xc080ULL + scene);
      const double wind_roar =
          0.72 * (SmoothNoise(absolute, 34, seed, 0xc090ULL + scene) -
                  SmoothNoise(absolute, 260, seed, 0xc091ULL + scene)) +
          0.28 * SmoothNoise(absolute, 420, seed, 0xc092ULL + scene);
      const double whistle_gate = std::pow(
          (SmoothNoise(absolute, kSampleRate * 3, seed, 0xc0a0ULL + scene) +
           1.0) *
              0.5,
          3.0);
      const double wind_whistle =
          (SmoothNoise(absolute, 7, seed, 0xc0b0ULL + scene) -
           SmoothNoise(absolute, 24, seed, 0xc0b1ULL + scene)) *
          whistle_gate;
      const double left = std::sqrt((1.0 - direction * 0.72) * 0.5);
      const double right = std::sqrt((1.0 + direction * 0.72) * 0.5);
      const double left_air =
          wind_roar + wind_whistle * 0.25 +
          SmoothNoise(absolute, 73, seed, 0xc0c0ULL + scene) * 0.16;
      const double right_air =
          wind_roar + wind_whistle * 0.25 +
          SmoothNoise(absolute, 89, seed, 0xc0d0ULL + scene) * 0.16;
      (*mix)[frame * 2] += profile.wind_gain * gust * left_air * left;
      (*mix)[frame * 2 + 1] += profile.wind_gain * gust * right_air * right;
    }
  }
}

int16_t Quantize(double sample,
                 uint64_t seed,
                 int64_t frame,
                 int channel) {
  const double limited = std::tanh(sample * 1.12) / std::tanh(1.12);
  const double dither =
      (Unit(seed, frame * 2 + channel, 0xe001ULL) -
       Unit(seed, frame * 2 + channel, 0xe002ULL)) /
      32768.0;
  const double scaled =
      std::clamp(limited + dither, -1.0, 1.0) * 32767.0;
  return static_cast<int16_t>(std::lrint(scaled));
}

}  // namespace

extern "C" int32_t classipod_spatial_rain_sample_rate() {
  return kSampleRate;
}

extern "C" int32_t classipod_spatial_rain_channel_count() {
  return kChannels;
}

extern "C" int32_t classipod_spatial_rain_render(int32_t scene,
                                                  uint64_t seed,
                                                  int64_t start_frame,
                                                  int32_t frame_count,
                                                  int16_t* output) {
  if (scene < 0 || scene > 3 || start_frame < 0 || frame_count < 0 ||
      output == nullptr) {
    return 0;
  }
  if (frame_count == 0) return 0;
  const SceneProfile profile = Profile(scene);
  std::vector<double> mix(static_cast<size_t>(frame_count) * kChannels, 0.0);
  AddDiffuseBed(&mix, scene, start_frame, frame_count, profile, seed);

  const double event_interval =
      static_cast<double>(kSampleRate) / profile.drops_per_second;
  constexpr int64_t kMaximumResponseFrames = kSampleRate / 4;
  const int64_t first = static_cast<int64_t>(std::floor(
                            (start_frame - kMaximumResponseFrames) /
                            event_interval)) -
                        2;
  const int64_t last =
      static_cast<int64_t>(std::ceil((start_frame + frame_count) /
                                     event_interval)) +
      2;
  for (int64_t event = first; event <= last; ++event) {
    const double jitter = Bipolar(seed, event, 0xf001ULL + scene) * 0.44;
    const int64_t event_frame = static_cast<int64_t>(
        std::llround((static_cast<double>(event) + jitter) * event_interval));
    AddDrop(&mix, start_frame, frame_count, event, event_frame, profile, seed);
  }
  AddThunder(&mix, scene, start_frame, frame_count, profile, seed);

  for (int frame = 0; frame < frame_count; ++frame) {
    output[frame * 2] =
        Quantize(mix[frame * 2], seed, start_frame + frame, 0);
    output[frame * 2 + 1] =
        Quantize(mix[frame * 2 + 1], seed, start_frame + frame, 1);
  }
  return frame_count;
}

extern "C" int16_t* classipod_spatial_rain_render_alloc(
    int32_t scene,
    uint64_t seed,
    int64_t start_frame,
    int32_t frame_count) {
  if (frame_count <= 0 ||
      static_cast<uint64_t>(frame_count) >
          std::numeric_limits<size_t>::max() / (sizeof(int16_t) * kChannels)) {
    return nullptr;
  }
  auto* output = new (std::nothrow)
      int16_t[static_cast<size_t>(frame_count) * kChannels];
  if (output == nullptr) return nullptr;
  if (classipod_spatial_rain_render(scene, seed, start_frame, frame_count,
                                    output) != frame_count) {
    delete[] output;
    return nullptr;
  }
  return output;
}

extern "C" void classipod_spatial_rain_free(int16_t* output) {
  delete[] output;
}
