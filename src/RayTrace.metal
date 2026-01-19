//
//  RayTrace.metal
//  MetalEngine
//
//  Created by Charlie Wheelwright on 15/07/2025.
//
//Metal implementation of https://github.com/SebLague/Ray-Tracing/tree/Episode01
//
#include <metal_stdlib>
#import "../libs/Loki/Loki/loki_header.metal"

using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]];
};

struct VertexOut
{
    float4 position [[position]];
    float2 uvCoord;
    int frameIdx;
    float aspect;
};

struct UBO
{
    float2 dimensions;
    int frameIdx;
};

float4x4 Perspective(float fovyRadians, 
                    float aspect, 
                    float nearZ, 
                    float farZ) 
{
    float ys = 1 / tan(fovyRadians * 0.5);
    float xs = ys / aspect;
    float zs = farZ / (nearZ - farZ);
    return float4x4(xs, 0,  0, 0,
                    0, ys,  0,          0,
                    0,  0, zs, nearZ * zs,
                    0,  0, -1,          0 );
}

constant float PI = 3.14159265359;
constant float FOV = (45.0f/180.0f) * PI;
constant float nearPlane = 0.001f;
constant float farPlane = 100.0f;

vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
                           constant VertexIn* vertexData [[buffer(0)]], 
                           constant UBO* uniformBuffer [[buffer(1)]])
{
    VertexOut out;
    out.position = float4(vertexData[vertexID].position, 0.0f, 1.0f);
    out.aspect = uniformBuffer->dimensions.x/uniformBuffer->dimensions.y;

    // float4x4 mvpMatrix = Perspective((45.0f/180.0f) * PI, uniformBuffer->dimensions.y/uniformBuffer->dimensions.x, 0.001f, 100.0f);
    // out.rayOrigin = (mvpMatrix * float4(vertexData[vertexID].position, 1.0f)).xyz;
    out.uvCoord = (vertexData[vertexID].position + float2(1.0f)) * 0.5f;
    out.frameIdx = uniformBuffer->frameIdx;

    return out;
}

//Fragment shader program

struct Ray
{
    float3 origin;
    float3 dir;
};

struct Material
{
    //
    float3 colour;
    //
    float emissionStrength;
    float3 emissionColour;
    //Zero is diffuse and one is specular
    float specular;
    //
    float refract;
};

constant float RAY_INFTY = 1E38;
struct HitInfo
{
    float dst;
    float3 hitPoint;
    float3 normal;
    Material material;
};

struct Sphere
{
  float3 centre;
  float radius;  
  Material material;
};


//
// Constants
//
constant float epsilon = 0.001f;
constant int MaxBounces = 10;
constant int NumberOfRaysPerFragment = 180;
constant float DivergeStrength = 0.0001f;
constant int NumSpheres = 5;

// --- RNG Stuff ---

// PCG (permuted congruential generator). Thanks to:
// www.pcg-random.org and www.shadertoy.com/view/XlGcRh
// uint NextRandom(thread uint& state)
// {
//     state = state * 747796405 + 2891336453;
//     uint result = ((state >> ((state >> 28) + 4)) ^ state) * 277803737;
//     result = (result >> 22) ^ result;
//     return result;
// }

// float RandomValue(thread uint& state)
// {
//     return NextRandom(state) / 4294967295.0; // 2^32 - 1
// }

float RandomValue(thread Loki& state)
{
    return state.rand();
}

// Random value in normal distribution (with mean=0 and sd=1)
float RandomValueNormalDistribution(thread Loki& state)
{
    // Thanks to https://stackoverflow.com/a/6178290
    float theta = 2.0f * PI * RandomValue(state);
    float rho = sqrt(-2.0f * log(1.0f - RandomValue(state)));
    return rho * cos(theta);
}

// Calculate a random direction
float3 RandomDirection(thread Loki& state)
{
    // Thanks to https://math.stackexchange.com/a/1585996
    float x = RandomValueNormalDistribution(state);
    float y = RandomValueNormalDistribution(state);
    float z = RandomValueNormalDistribution(state);
    return normalize(float3(x, y, z));
}

float3 RandomHemisphereDirection(float3 normal, thread Loki& state)
{
    float3 dir = RandomDirection(state);
    return dir * sign(dot(dir, normal));
}

float2 RandomPointInCircle(thread Loki& state)
{
    float angle = RandomValue(state) * 2 * PI;
    float2 pointOnCircle = float2(cos(angle), sin(angle));
    return pointOnCircle;// * sqrt(RandomValue(state));
}

constant float SunFocus = 1.0f;
constant float SunIntensity = 1.0f;
constant float3 SkyColourHorizon = {25.0f/255.0f,142.0f/255.0f,186.0f/255.0f};
constant float3 SkyColourZenith = {224.0f/255.0f,240.0f/255.0f,240.0f/255.0f};
constant float3 GroundColourStart = {97.0f/255.0f, 97.0f/255.0f, 97.0f/255.0f};
constant float3 GroundColourEnd = {197.0f/255.0f, 197.0f/255.0f, 197.0f/255.0f};
constant float3 SunPos = float3(1.0f, 1.0f, 0.0f);

float3 GetEnvironmentLight(Ray ray)
{
    float skyGradientT = pow(smoothstep(0.0f, 0.4f, ray.dir.y), 0.8f);
    float groundGradientT = pow(smoothstep(-0.35f, 0.0f, ray.dir.y), 0.8f);
    float groundToSkyT = smoothstep(-0.01f, 0.0f, ray.dir.y);
    float3 skyGradient = mix(SkyColourHorizon, SkyColourZenith, skyGradientT);
    float3 groundGradient = mix(GroundColourStart, GroundColourEnd, groundGradientT);

    float3 sun = float3(0.0f);// float3(pow(max(0.0f, dot(normalize(ray.dir), normalize(SunPos))), SunFocus) * SunIntensity);
    
    float3 composite = mix(groundGradient, skyGradient, groundToSkyT) + sun;
    return composite*0.9f;
}

HitInfo RaySphere(Sphere sphere, Ray ray)
{
    HitInfo info;
    info.dst = RAY_INFTY;
    info.hitPoint = float3(0.0f);
    info.normal = float3(0.0f);

    float3 offest = ray.origin - sphere.centre;
    float a = dot(ray.dir, ray.dir);
    float b = 2 * dot(ray.dir, offest);
    float c = dot(offest, offest) - (sphere.radius * sphere.radius);

    float d = b * b - 4 * a * c;

    if (d > 0)
    {
        float s = sqrt(d);
        float dstNear = (-b - s) / (2 * a);
        float dstFar = (-b + s) / (2 * a);

        float dst = dstNear;//dstNear >= 0.0f ? dstNear : dstFar;

        if (dst > 0.0f)
        {
            info.dst = dst;
            info.hitPoint = ray.origin + ray.dir * dst;
            info.normal = normalize(info.hitPoint - sphere.centre);
        }
    }

    return info;
}

HitInfo RayCollision(Ray ray, thread Sphere* spheres)
{
    HitInfo closestHit;
    closestHit.dst = RAY_INFTY;

    for(int i = 0; i < NumSpheres; ++i)
    {
        Sphere sphere = spheres[i];
        HitInfo info = RaySphere(sphere, ray);
        
        if(info.dst != RAY_INFTY && info.dst < closestHit.dst)
        {
            closestHit = info;
            closestHit.material = sphere.material;
        }
    }

    return closestHit;
}

float FresnelReflectAmount(float n1, float n2, float3 incident, float3 normal)
{
        // Schlick aproximation
        float r0 = (n1-n2) / (n1+n2);
        r0 *= r0;
        float cosX = -dot(normal, incident);
        if (n1 > n2)
        {
            float n = n1/n2;
            float sinT2 = n*n*(1.0-cosX*cosX);
            // Total internal reflection
            if (sinT2 > 1.0)
                return 1.0;
            cosX = sqrt(1.0-sinT2);
        }
        float x = 1.0-cosX;
        float ret = r0+(1.0-r0)*x*x*x*x*x;

        return ret;
}

float3 RefractInternalReflection(float3 dir, float3 normal, float eta)
{
    bool frontFacing = dot(dir, normal) < 0.0;
    float ri = frontFacing ? 1.0f/eta : eta;

    float cosTheta = min(dot(-dir, normal), 1.0f);
    float sinTheta = sqrt(1.0f - cosTheta*cosTheta);

    if(ri * sinTheta > 1.0f)
        return reflect(dir, normal);
    else
        return refract(dir, normal, ri); 
}

float3 Trace(Ray ray, thread Sphere* spheres, thread Loki& state)
{
    float3 incomingLight = float3(0.0f);
    float3 rayColour = float3(1.0f);

    for(int bounce = 0; bounce < MaxBounces; bounce++)
    {
        HitInfo collision = RayCollision(ray, spheres);

        if(collision.dst != RAY_INFTY && collision.dst > epsilon)
        {
            Material material = collision.material;
            ray.origin = collision.hitPoint;

            float3 diffuseDir = collision.normal + RandomDirection(state);
            float3 specularDir = reflect(ray.dir, collision.normal);
            float eta = 1.33f;
            float3 refractDir = RefractInternalReflection(ray.dir, collision.normal, eta);

            if(material.refract == 1.0f)
            {
                float kr = FresnelReflectAmount(1.0f, 1.33f, ray.dir, collision.normal);
                kr = (material.specular + (1.0f-material.specular) * kr);

                if(kr >= RandomValue(state))
                    ray.dir = normalize(specularDir);
                else
                    ray.dir = normalize(refractDir);
            }
            else if(material.specular >= RandomValue(state))
                ray.dir = normalize(specularDir);
            else
                ray.dir = normalize(diffuseDir);


            ray.origin += ray.dir * epsilon;

            float3 emittedLight = material.emissionColour * material.emissionStrength;
            incomingLight += emittedLight * rayColour;
            rayColour *= material.colour;
        }
        else
        {
            incomingLight += GetEnvironmentLight(ray) * rayColour;
            break;
        }

    }

    return incomingLight;
}

fragment float4 fragmentShader(VertexOut vDataIn [[stage_in]]) {
    Loki loki = Loki((uint)(vDataIn.uvCoord.x * 73464950.0f), (uint)(vDataIn.uvCoord.y * 283948042.0f) /*, vDataIn.frameIdx * 8000*/);

    float planeHeight = nearPlane * tan(0.5f * FOV) * 2.0f;
    float planeWidth = planeHeight * vDataIn.aspect;

    float3 viewParams = float3(planeWidth, planeHeight, nearPlane);
    float3 viewPoint = float3(vDataIn.uvCoord - float2(0.5f), 1.0f) * viewParams;

    float3 camPos = float3(0.0f, 0.0f, 0.0f);

    float motion = cos((float)vDataIn.frameIdx/50.0f);

    Sphere spheres[NumSpheres] = {
        {{-0.2f, 0.0f, 1.0f}, 0.1f, {{1.0f,0.0f,0.0f}, 0.0f, float3(0.0f), 0.0f, 0.0f}},
        {{0.0f, motion*0.1f, 1.0f},  0.1f, {{1.0f,1.0f,1.0f}, 0.0f, float3(0.0f), 1.0f, 0.0f}},
        {{motion*0.1f + 0.2f, 0.1f, 0.9f},  0.1f, {{0.0f, 0.5f,1.0f}, 0.0f, float3(0.0f), 0.2f, 0.0f}},
        {{0.15f, motion*0.2f, 0.6f},  0.08f, {{1.0f, 1.0f, 1.0f}, 0.0f, float3(0.0f), 0.1f, 1.0f}},
        {{motion*0.1f, motion*0.1f, 0.8f}, 0.02f, {float3(0.0f), 50.0f, float3(1.0f), 0.0f, 0.0f}}
    };

    Ray ray;
    float3 totalIncomingLight = 0.0f;

    for (int rayIndex = 0; rayIndex < NumberOfRaysPerFragment; rayIndex++)
    {
        ray.origin = camPos;
        ray.dir = normalize(viewPoint - ray.origin);

        float2 jitter = RandomPointInCircle(loki) * DivergeStrength;
        ray.dir += float3(jitter, 0.0f);
        ray.origin += float3(jitter, 0.0f);
        
        totalIncomingLight += Trace(ray, spheres, loki);
    }
    
    totalIncomingLight /= NumberOfRaysPerFragment;


    return float4(totalIncomingLight, 1.0f);
}
