//ObjCBridge.mm
//
#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>
#define GLFW_EXPOSE_NATIVE_COCOA
#include <GLFW/glfw3native.h>
//
#include <Metal/Metal.h>
#include <Metal/Metal.hpp>
#include <QuartzCore/CAMetalLayer.h>
#include <QuartzCore/CAMetalLayer.hpp>
#include <QuartzCore/QuartzCore.hpp>
//
#include "ObjCBridge.hpp"


namespace Ray::ObjCBridge {
    //
    void BindMetalLayerToWindow(GLFWwindow *window, CA::MetalLayer *metalLayer) {
        NSWindow* cocoa_window = glfwGetCocoaWindow(window);
        CAMetalLayer* native_layer = (__bridge CAMetalLayer*)metalLayer;
        [[cocoa_window contentView] setLayer:native_layer];
        [native_layer setMaximumDrawableCount:2];
        [[cocoa_window contentView] setWantsLayer:YES];
        [[cocoa_window contentView] setNeedsLayout:YES];
    }
    //
}