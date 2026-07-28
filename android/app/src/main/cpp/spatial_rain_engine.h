#ifndef CLASSIPOD_SPATIAL_RAIN_ENGINE_H_
#define CLASSIPOD_SPATIAL_RAIN_ENGINE_H_

#include <cstdint>

enum class SpatialRainScene : int32_t {
  kDrizzle = 0,
  kHeavyRain = 1,
  kStorm = 2,
  kLightningStorm = 3,
};

extern "C" {

int32_t classipod_spatial_rain_sample_rate();
int32_t classipod_spatial_rain_channel_count();

// Writes interleaved signed 16-bit PCM and returns the number of frames written.
int32_t classipod_spatial_rain_render(int32_t scene,
                                     uint64_t seed,
                                     int64_t start_frame,
                                     int32_t frame_count,
                                     int16_t* output);

int16_t* classipod_spatial_rain_render_alloc(int32_t scene,
                                             uint64_t seed,
                                             int64_t start_frame,
                                             int32_t frame_count);
void classipod_spatial_rain_free(int16_t* output);

}

#endif  // CLASSIPOD_SPATIAL_RAIN_ENGINE_H_
