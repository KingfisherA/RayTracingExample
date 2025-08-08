// RayTracingEngine.cpp
#include <cassert>
#include <cstring>
#include <iostream>
#include <simd/simd.h>
#include <simd/vector_types.h>
//
#include <Metal/Metal.hpp>
#include <QuartzCore/CAMetalLayer.hpp>
#include <QuartzCore/QuartzCore.hpp>
//
#include "Metal/MTLCommandBuffer.hpp"
#include "Metal/MTLLogState.hpp"
#include "Metal/MTLResource.hpp"
#include "ObjCBridge.hpp"
#include "RayTracingEngine.hpp"

//
//
namespace Ray {
//
RayTracingEngine::RayTracingEngine() {}
//
bool RayTracingEngine::Init() {
  bool initSuccess = InitDevice() && CreateDisplay() && CreateQuad() &&
                     CreateDefaultLibrary() && CreateCommandQueue() &&
                     CreateRenderPipeline() && CreateUniformBuffer();

  RenderFrame();

  return initSuccess;
}
bool RayTracingEngine::InitDevice() {
  // Initialization code for the ray tracing engine
  mDevice = MTL::CreateSystemDefaultDevice();

  if (!mDevice) {
    std::cerr << "Failed to create a connection to a metal device.\n";
    return false;
  }

  return true;
}
bool RayTracingEngine::CreateDisplay() {

  glfwInit();
  glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
  mWindow =
      glfwCreateWindow(mWidth, mHeight, "Ray Tracing Engine", nullptr, nullptr);

  if (!mWindow) {
    std::cerr << "Failed to create GLFW window\n";
    return false;
  }

  glfwSetWindowUserPointer(mWindow, (void *)this);
  glfwGetFramebufferSize(mWindow, &mWidth, &mHeight);
  glfwSetFramebufferSizeCallback(mWindow, &UpdateFramebufferCallback);
  glfwSetKeyCallback(mWindow, &KeyboardCallback);

  mMetalLayer = CA::MetalLayer::layer();
  mMetalLayer->setDevice(mDevice);
  mMetalLayer->setPixelFormat(MTL::PixelFormatBGRA8Unorm);
  mMetalLayer->setDrawableSize(CGSize{(float)mWidth, (float)mHeight});

  ObjCBridge::BindMetalLayerToWindow(mWindow, mMetalLayer);

  return true;
}
bool RayTracingEngine::CreateDefaultLibrary() {
  NS::Error *libError = nullptr;
  mLibrary = mDevice->newLibrary(NS::URL::fileURLWithPath(NS::String::string(
                                     "/Users/charlie/dev/C++/RayTracingExample/"
                                     "metal-build/RayTrace.metallib",
                                     NS::ASCIIStringEncoding)),
                                 &libError);
  if (libError) {
    std::cerr << "Failed to load default metal library\n";
    return false;
  }
  return true;
}
bool RayTracingEngine::CreateCommandQueue() {
  mCommandQueue = mDevice->newCommandQueue();
  return true;
}
bool RayTracingEngine::CreateRenderPipeline() {
  MTL::Function *vertexShader = mLibrary->newFunction(NS::String::string(
      "vertexShader", NS::StringEncoding::ASCIIStringEncoding));
  assert(vertexShader);
  MTL::Function *fragmentShader = mLibrary->newFunction(NS::String::string(
      "fragmentShader", NS::StringEncoding::ASCIIStringEncoding));
  assert(fragmentShader);

  MTL::VertexDescriptor *vertexDescriptor =
      MTL::VertexDescriptor::alloc()->init();

  vertexDescriptor->attributes()->object(0)->setFormat(MTL::VertexFormatFloat2);
  vertexDescriptor->attributes()->object(0)->setBufferIndex(0);
  vertexDescriptor->attributes()->object(0)->setOffset(0);

  // vertexDescriptor->attributes()->object(1)->setFormat(MTL::VertexFormatFloat2);
  // vertexDescriptor->attributes()->object(1)->setBufferIndex(0);
  // vertexDescriptor->attributes()->object(1)->setOffset(sizeof(simd::float4));

  vertexDescriptor->layouts()->object(0)->setStride(sizeof(simd::float2));

  MTL::RenderPipelineDescriptor *pipelineDescriptor =
      MTL::RenderPipelineDescriptor::alloc()->init();
  pipelineDescriptor->setLabel(NS::String::string(
      "RayTracingPipeline", NS::StringEncoding::ASCIIStringEncoding));
  pipelineDescriptor->setVertexFunction(vertexShader);
  pipelineDescriptor->setFragmentFunction(fragmentShader);
  pipelineDescriptor->setVertexDescriptor(vertexDescriptor);
  assert(pipelineDescriptor);
  pipelineDescriptor->colorAttachments()->object(0)->setPixelFormat(
      (MTL::PixelFormat)mMetalLayer->pixelFormat());

  NS::Error *error = nullptr;
  mRenderPipelineState =
      mDevice->newRenderPipelineState(pipelineDescriptor, &error);

  vertexDescriptor->release();
  pipelineDescriptor->release();

  return true;
}
bool RayTracingEngine::CreateQuad() {
  simd::float2 quadVertices[] = {{-1.0f, -1.0f}, {-1.0f, 1.0f}, {1.0f, 1.0f},
                                 {-1.0f, -1.0f}, {1.0f, 1.0f},  {1.0f, -1.0f}};

  mQuadVertexBuffer = mDevice->newBuffer(&quadVertices, sizeof(quadVertices),
                                         MTL::ResourceStorageModeShared);

  return true;
}
bool RayTracingEngine::CreateUniformBuffer() {
  mUniformBufferData.dimensions = {(float)mWidth, (float)mHeight};
  mUniformBufferData.frameIdx = 0;
  mUniformBuffer =
      mDevice->newBuffer(&mUniformBufferData, sizeof(RayTracingEngine::UBO),
                         MTL::ResourceStorageModeShared);

  return true;
}
void RayTracingEngine::UpdateUniformBuffer() {
  memcpy(mUniformBuffer->contents(), &mUniformBufferData,
         sizeof(RayTracingEngine::UBO));
}
//
void RayTracingEngine::Run() {
  // Main loop for running the ray tracing engine
  while (!glfwWindowShouldClose(mWindow)) {

    RenderFrame();

    glfwPollEvents();
  }
}
//
void RayTracingEngine::RenderFrame() {
  NS::AutoreleasePool *autoPool = NS::AutoreleasePool::alloc()->init();
  metalDrawable = mMetalLayer->nextDrawable();

  mUniformBufferData.frameIdx++;
  UpdateUniformBuffer();

  MTL::CommandBuffer *cmdBuffer = mCommandQueue->commandBuffer();

  MTL::RenderPassDescriptor *renderPassDescriptor =
      MTL::RenderPassDescriptor::alloc()->init();
  MTL::RenderPassColorAttachmentDescriptor *cd =
      renderPassDescriptor->colorAttachments()->object(0);
  cd->setTexture(metalDrawable->texture());
  cd->setLoadAction(MTL::LoadActionClear);
  cd->setClearColor(
      MTL::ClearColor(42.0f / 255.0f, 42.0f / 255.0f, 42.0f / 255.0f, 1.0));
  cd->setStoreAction(MTL::StoreActionStore);



  MTL::RenderCommandEncoder *renderCommandEncoder =
      cmdBuffer->renderCommandEncoder(renderPassDescriptor);
  renderCommandEncoder->setRenderPipelineState(mRenderPipelineState);
  renderCommandEncoder->setVertexBuffer(mQuadVertexBuffer, 0, 0);
  renderCommandEncoder->setVertexBuffer(mUniformBuffer, 0, 1);
  renderCommandEncoder->drawPrimitives(MTL::PrimitiveTypeTriangle, 0, 6, 1);
  renderCommandEncoder->endEncoding();

  cmdBuffer->presentDrawable(metalDrawable);
  cmdBuffer->commit();
  cmdBuffer->waitUntilCompleted();

  renderPassDescriptor->release();

  autoPool->release();
}
//
void RayTracingEngine::Destroy() {
  // Cleanup code for the ray tracing engine
  glfwDestroyWindow(mWindow);
  glfwTerminate();

  mUniformBuffer->release();
  mQuadVertexBuffer->release();
  mDevice->release();
}
//
void RayTracingEngine::UpdateFramebufferCallback(GLFWwindow *window, int width,
                                                 int height) {
  RayTracingEngine *engine =
      static_cast<RayTracingEngine *>(glfwGetWindowUserPointer(window));
  engine->ResizeMetalFramebuffer(width, height);
}
void RayTracingEngine::KeyboardCallback(GLFWwindow *window, int key,
                                        int scancode, int action, int mods) {
  RayTracingEngine *engine =
      static_cast<RayTracingEngine *>(glfwGetWindowUserPointer(window));

  switch (key) {
  case GLFW_KEY_F: {
    engine->RenderFrame();
  } break;
  default:
    break;
  }
}
void RayTracingEngine::ResizeMetalFramebuffer(int width, int height) {
  mMetalLayer->setDrawableSize(CGSizeMake(width, height));

  mUniformBufferData.dimensions = {(float)width, (float)height};
  UpdateUniformBuffer();
  mWidth = width;
  mHeight = height;
  this->RenderFrame();
}
} // namespace Ray