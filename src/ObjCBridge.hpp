#pragma once

#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>

#include <Metal/Metal.hpp>
#include <QuartzCore/CAMetalLayer.hpp>
#include <QuartzCore/QuartzCore.hpp>


namespace Ray::ObjCBridge
{
    void BindMetalLayerToWindow(GLFWwindow *window, CA::MetalLayer *metalLayer);
} // namespace Ray::ObjCBridge
