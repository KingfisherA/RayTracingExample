#pragma once

#include "QuartzCore/CAMetalDrawable.hpp"
#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>

#include <Metal/Metal.hpp>
#include <QuartzCore/CAMetalLayer.hpp>
#include <QuartzCore/QuartzCore.hpp>

#include <simd/simd.h>

namespace Ray {
class RayTracingEngine {
public:
  RayTracingEngine();

  bool Init();
  void Run();
  void Destroy();

private:
  static void UpdateFramebufferCallback(GLFWwindow *window, int width,
                                        int height);
  static void KeyboardCallback(GLFWwindow *window, int key, int scancode,
                               int action, int mods);
  void ResizeMetalFramebuffer(int width, int height);

  bool InitDevice();
  bool CreateDisplay();
  bool CreateDefaultLibrary();
  bool CreateCommandQueue();
  bool CreateRenderPipeline();
  bool CreateQuad();

  bool CreateUniformBuffer();
  void UpdateUniformBuffer();

  bool CreateAccumulationTexture();
  void ResetAccumulation();

  void RenderFrame();

  // GLFW
  GLFWwindow *mWindow = nullptr;
  int mWidth = 800, mHeight = 600;

  // Metal
  MTL::Device *mDevice = nullptr;
  CA::MetalLayer *mMetalLayer = nullptr;
  CA::MetalDrawable *metalDrawable = nullptr;
  MTL::Library *mLibrary = nullptr;
  MTL::Buffer *mQuadVertexBuffer = nullptr;
  MTL::CommandQueue *mCommandQueue = nullptr;
  MTL::RenderPipelineState *mRenderPipelineState = nullptr;
  // Running average of all frames since the last reset
  MTL::Texture *mAccumulationTexture = nullptr;
  bool mAnimate = false;

  //
  struct UBO {
    simd::float2 dimensions{};
    int frameIdx = 0;
    int accumFrame = 0;
    float time = 0.0f;
  } mUniformBufferData;
  MTL::Buffer *mUniformBuffer = nullptr;
};

} // namespace Ray