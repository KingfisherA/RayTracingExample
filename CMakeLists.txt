# CMake Build Script for the Ray Tracing Example Project

cmake_minimum_required(VERSION 3.24)

project("RayTracingExample" LANGUAGES CXX)
get_filename_component(RAY_DIR ${CMAKE_CURRENT_SOURCE_DIR} ABSOLUTE)

set(RAY_PLATFORM ${CMAKE_SYSTEM_NAME})
string(TOLOWER ${RAY_PLATFORM} RAY_PLATFORM)
set(RAY_SRC_DIR ${RAY_DIR}/src)
set(RAY_LIB_DIR ${RAY_DIR}/Libraries)
set(RAY_BIN_DIR ${RAY_DIR}/bin/${RAY_PLATFORM})

include(Projects/RayTracingExample.cmake)