
xcrun metal -c ./src/RayTrace.metal -o ./metal-build/RayTrace.air &&
xcrun metallib ./metal-build/RayTrace.air -o ./metal-build/RayTrace.metallib
