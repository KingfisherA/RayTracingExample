add_executable("RayTracingExample"
    "${RAY_SRC_DIR}/Application.cpp"
    "${RAY_SRC_DIR}/metal_impl.cpp"
    "${RAY_SRC_DIR}/RayTracingEngine.cpp"
    "${RAY_SRC_DIR}/RayTracingEngine.hpp"
    "${RAY_SRC_DIR}/ObjCBridge.hpp"
    "${RAY_SRC_DIR}/ObjCBridge.mm"
    "${RAY_SRC_DIR}/VertexData.hpp"
)

find_package(glfw3 CONFIG REQUIRED)
find_package(fmt CONFIG REQUIRED)

target_include_directories("RayTracingExample" PRIVATE
  ${RAY_SRC_DIR}
  "/opt/metal-cpp_macOS26_iOS26-beta"
  ${GLFW_INCLUDE_DIRS}
  ${fmt_INCLUDE_DIRS}
)
target_link_libraries("RayTracingExample" PRIVATE
  $<LINK_LIBRARY:FRAMEWORK,Foundation>
  $<LINK_LIBRARY:FRAMEWORK,QuartzCore>
  $<LINK_LIBRARY:FRAMEWORK,Metal>
  glfw
  fmt::fmt
)

set(COMPILE_OPTIONS)
if((CMAKE_CXX_COMPILER_ID STREQUAL Clang) OR 
   (CMAKE_CXX_COMPILER_ID STREQUAL GNU))
    list(APPEND COMPILE_OPTIONS
      -m64
      -fPIC
      -std=c++20
    )
    if(CMAKE_BUILD_TYPE STREQUAL Debug)
      list(APPEND COMPILE_OPTIONS
        -g
        -O0
      )
    elseif(CMAKE_BUILD_TYPE STREQUAL Release)
      list(APPEND COMPILE_OPTIONS
        -O3
        -mavx2
      )
    endif()
elseif(CMAKE_CXX_COMPILER_ID STREQUAL MSVC)
  list(APPEND COMPILE_OPTIONS
      /std:c++20
    )
    if(CMAKE_BUILD_TYPE STREQUAL Debug)
      list(APPEND COMPILE_OPTIONS
        /Zi
        /Od
      )
    elseif(CMAKE_BUILD_TYPE STREQUAL Release)
      list(APPEND COMPILE_OPTIONS /O2)
    endif()
endif()
target_compile_options("RayTracingExample" PRIVATE ${COMPILE_OPTIONS})

set_target_properties("RayTracingExample" PROPERTIES
    CXX_STANDARD 20
    CXX_STANDARD_REQUIRED YES
    CXX_EXTENSIONS NO
    POSITION_INDEPENDENT_CODE True
    INTERPROCEDURAL_OPTIMIZATION False
    MSVC_RUNTIME_LIBRARY MultiThreaded$<$<CONFIG:Debug>:Debug>DLL
    OUTPUT_NAME "RayTracingExample")

if(CMAKE_CONFIGURATION_TYPES)
  set(DEBUG_BIN_DIR "${RAY_BIN_DIR}")
  set(RELEASE_BIN_DIR "${RAY_BIN_DIR}")
else()
  set(DEBUG_BIN_DIR "${RAY_BIN_DIR}/Debug")
  set(RELEASE_BIN_DIR "${RAY_BIN_DIR}/Release")
endif()

if(CMAKE_BUILD_TYPE STREQUAL Debug)
  set_target_properties("RayTracingExample" PROPERTIES
    ARCHIVE_OUTPUT_DIRECTORY "${DEBUG_BIN_DIR}"
    LIBRARY_OUTPUT_DIRECTORY "${DEBUG_BIN_DIR}"
    RUNTIME_OUTPUT_DIRECTORY "${DEBUG_BIN_DIR}"
  )
elseif(CMAKE_BUILD_TYPE STREQUAL Release)
  set_target_properties("RayTracingExample" PROPERTIES
    ARCHIVE_OUTPUT_DIRECTORY "${RELEASE_BIN_DIR}"
    LIBRARY_OUTPUT_DIRECTORY "${RELEASE_BIN_DIR}"
    RUNTIME_OUTPUT_DIRECTORY "${RELEASE_BIN_DIR}"
  )
endif()
