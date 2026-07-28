#include "spatial_rain_engine.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <numeric>
#include <string>
#include <vector>

namespace {

constexpr int kChannels = 2;

[[noreturn]] void Fail(const std::string& message) {
  std::cerr << "FAIL: " << message << '\n';
  std::exit(1);
}

void Expect(bool condition, const std::string& message) {
  if (!condition) Fail(message);
}

std::vector<int16_t> Render(SpatialRainScene scene,
                            int seconds,
                            uint64_t seed = 0x123456789abcdefULL,
                            int64_t start_frame = 0) {
  const int frames = classipod_spatial_rain_sample_rate() * seconds;
  std::vector<int16_t> pcm(frames * kChannels);
  const int written = classipod_spatial_rain_render(
      static_cast<int32_t>(scene), seed, start_frame, frames, pcm.data());
  Expect(written == frames, "renderer returned an incomplete range");
  return pcm;
}

uint64_t Hash(const std::vector<int16_t>& pcm) {
  uint64_t hash = 1469598103934665603ULL;
  for (const int16_t sample : pcm) {
    hash ^= static_cast<uint16_t>(sample);
    hash *= 1099511628211ULL;
  }
  return hash;
}

double Rms(const std::vector<int16_t>& pcm) {
  long double energy = 0.0;
  for (const int16_t sample : pcm) {
    energy += static_cast<long double>(sample) * sample;
  }
  return std::sqrt(static_cast<double>(energy / pcm.size()));
}

double StereoDifferenceRatio(const std::vector<int16_t>& pcm) {
  long double side = 0.0;
  long double mid = 0.0;
  for (size_t i = 0; i < pcm.size(); i += 2) {
    const double left = pcm[i];
    const double right = pcm[i + 1];
    side += (left - right) * (left - right);
    mid += (left + right) * (left + right);
  }
  return std::sqrt(static_cast<double>(side / std::max(mid, 1.0L)));
}

std::vector<double> WindowRms(const std::vector<int16_t>& pcm,
                              int window_frames) {
  std::vector<double> levels;
  for (size_t start = 0;
       start + window_frames * kChannels <= pcm.size();
       start += window_frames * kChannels) {
    long double energy = 0.0;
    for (size_t i = start; i < start + window_frames * kChannels; ++i) {
      energy += static_cast<long double>(pcm[i]) * pcm[i];
    }
    levels.push_back(std::sqrt(
        static_cast<double>(energy / (window_frames * kChannels))));
  }
  return levels;
}

double MeanAbsoluteDelta(const std::vector<int16_t>& pcm) {
  long double total = 0.0;
  for (size_t i = 2; i < pcm.size(); i += 2) {
    total += std::abs(static_cast<int>(pcm[i]) - pcm[i - 2]);
  }
  return static_cast<double>(total / (pcm.size() / 2 - 1));
}

double LowMidRms(const std::vector<int16_t>& pcm) {
  double state = 0.0;
  long double energy = 0.0;
  for (size_t i = 0; i < pcm.size(); i += 2) {
    const double mono = (static_cast<double>(pcm[i]) + pcm[i + 1]) * 0.5;
    state += 0.075 * (mono - state);
    energy += state * state;
  }
  return std::sqrt(static_cast<double>(energy / (pcm.size() / 2)));
}

double SharpnessAtLoudestWindow(const std::vector<int16_t>& pcm,
                                int window_frames) {
  const auto levels = WindowRms(pcm, window_frames);
  const auto loudest =
      static_cast<size_t>(std::max_element(levels.begin(), levels.end()) -
                          levels.begin());
  const size_t start = loudest * window_frames * kChannels;
  const size_t end = start + window_frames * kChannels;
  long double delta = 0.0;
  for (size_t i = start + 2; i < end; i += 2) {
    delta += std::abs(static_cast<int>(pcm[i]) - pcm[i - 2]);
  }
  return static_cast<double>(delta / (window_frames - 1)) /
         std::max(levels[loudest], 1.0);
}

void TestRangeDeterminism() {
  constexpr uint64_t seed = 91;
  const int rate = classipod_spatial_rain_sample_rate();
  const int frames = rate * 2;
  std::vector<int16_t> whole(frames * kChannels);
  std::vector<int16_t> split(frames * kChannels);
  Expect(classipod_spatial_rain_render(1, seed, rate * 7, frames,
                                      whole.data()) == frames,
         "whole render failed");
  const int first = frames / 3;
  Expect(classipod_spatial_rain_render(1, seed, rate * 7, first,
                                      split.data()) == first,
         "first split render failed");
  Expect(classipod_spatial_rain_render(1, seed, rate * 7 + first,
                                      frames - first,
                                      split.data() + first * kChannels) ==
             frames - first,
         "second split render failed");
  Expect(whole == split, "absolute ranges are not sample deterministic");
}

void TestAllocatedRenderBoundary() {
  constexpr int frames = 257;
  int16_t* pcm = classipod_spatial_rain_render_alloc(0, 73, 48123, frames);
  Expect(pcm != nullptr, "allocated renderer returned null");
  std::vector<int16_t> direct(frames * kChannels);
  Expect(classipod_spatial_rain_render(0, 73, 48123, frames, direct.data()) ==
             frames,
         "direct allocation comparison failed");
  Expect(std::equal(direct.begin(), direct.end(), pcm),
         "allocated renderer differs from direct rendering");
  classipod_spatial_rain_free(pcm);
}

void TestScenes() {
  std::vector<uint64_t> hashes;
  std::vector<double> rms;
  std::vector<double> brightness;
  for (int scene = 0; scene < 4; ++scene) {
    const auto pcm = Render(static_cast<SpatialRainScene>(scene), 12);
    hashes.push_back(Hash(pcm));
    rms.push_back(Rms(pcm));
    brightness.push_back(MeanAbsoluteDelta(pcm));
    Expect(StereoDifferenceRatio(pcm) > 0.16,
           "scene collapses toward mono: " + std::to_string(scene));
    Expect(rms.back() > 350.0 && rms.back() < 15000.0,
           "scene level is unusable: " + std::to_string(scene));
  }
  std::sort(hashes.begin(), hashes.end());
  Expect(std::adjacent_find(hashes.begin(), hashes.end()) == hashes.end(),
         "weather scenes produced identical PCM");
  Expect(rms[1] > rms[0] * 1.18,
         "heavy rain does not have a denser acoustic bed than drizzle");
  Expect(brightness[0] > 80.0 && brightness[2] > 80.0,
         "rain impact texture lacks broadband transients");
}

void TestLightningTransient() {
  const auto pcm = Render(SpatialRainScene::kLightningStorm, 18);
  auto levels = WindowRms(pcm, classipod_spatial_rain_sample_rate() / 4);
  std::sort(levels.begin(), levels.end());
  const double median = levels[levels.size() / 2];
  const double peak = levels.back();
  Expect(peak > median * 2.45,
         "lightning scene lacks a very large rolling thunder swell: " +
             std::to_string(peak / median));
  const int sustained_windows = static_cast<int>(std::count_if(
      levels.begin(), levels.end(),
      [median](double level) { return level > median * 1.30; }));
  Expect(sustained_windows >= 14,
         "rolling thunder does not remain elevated long enough: " +
             std::to_string(sustained_windows));
  const double sharpness = SharpnessAtLoudestWindow(
      pcm, classipod_spatial_rain_sample_rate() / 10);
  Expect(sharpness < 0.72,
         "thunder starts with a discharge-like crack: " +
             std::to_string(sharpness));
}

void TestStormWindAndDrizzleScale() {
  const auto drizzle = Render(SpatialRainScene::kDrizzle, 12);
  const auto heavy = Render(SpatialRainScene::kHeavyRain, 12);
  const auto storm = Render(SpatialRainScene::kStorm, 12);
  const auto lightning = Render(SpatialRainScene::kLightningStorm, 12);

  Expect(Rms(drizzle) < Rms(heavy) * 0.42,
         "drizzle remains too dense or too large");
  Expect(MeanAbsoluteDelta(drizzle) < MeanAbsoluteDelta(heavy) * 0.52,
         "drizzle impacts remain too large");
  const double heavy_wind_band = LowMidRms(heavy);
  Expect(LowMidRms(storm) > heavy_wind_band * 1.65,
         "storm lacks a dominant gale layer");
  Expect(LowMidRms(lightning) > heavy_wind_band * 1.55,
         "lightning storm lacks a dominant gale layer");
}

}  // namespace

int main() {
  Expect(classipod_spatial_rain_sample_rate() == 48000,
         "renderer must use Android-native 48 kHz");
  Expect(classipod_spatial_rain_channel_count() == kChannels,
         "initial decoder must output stereo");
  TestRangeDeterminism();
  TestAllocatedRenderBoundary();
  TestScenes();
  TestLightningTransient();
  TestStormWindAndDrizzleScale();
  std::cout << "PASS: spatial rain acoustic contract\n";
  return 0;
}
