// Application.cpp
//
#include "RayTracingEngine.hpp"

int main()
{
    sleep(1);

    Ray::RayTracingEngine engine;
    if (!engine.Init())
        return EXIT_FAILURE;
    engine.Run();
    engine.Destroy();

    return 0;
}