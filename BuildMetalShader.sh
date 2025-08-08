xcrun metal -c ./src/RayTrace.metal -o ./metal-build/RayTrace.air &&
xcrun metal -c ./libs/Loki/Loki/loki.metal -o ./metal-build/loki.air &&
xcrun metallib ./metal-build/RayTrace.air ./metal-build/loki.air -o ./metal-build/RayTrace.metallib 
