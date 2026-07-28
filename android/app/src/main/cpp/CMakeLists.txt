cmake_minimum_required(VERSION 3.22.1)

project(classipod_spatial_audio LANGUAGES CXX)

add_library(
  classipod_spatial_audio
  SHARED
  spatial_rain_engine.cpp
)

target_compile_features(classipod_spatial_audio PRIVATE cxx_std_17)
target_compile_options(
  classipod_spatial_audio
  PRIVATE
  -Wall
  -Wextra
  -Werror
)
