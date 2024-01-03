#version 120

#include "lib/util.glsl"

varying vec2 texcoords;
varying vec3 LightDirection;
varying vec3 LightVector;
varying vec3 LightColor;
varying vec3 SkyColor;
varying float LightMapStrength;
varying float DayNightInterpolation;
varying float HandTorch;
varying float MaxDistance;

//#define VIBRANCY_BOOST

float GetDayNightInterpolationFactor(in int time, in float changeFactor){
    float x = float(time) / 24000.0f;
    x = x * 2.0f - 1.0f;
    //x *= 2.0f;
    x = pow(x, changeFactor) + 1.0f;
    return 1.0f / x;
}

void GetWorldLightingData(in int time, out vec3 dir, out vec3 color, out vec3 sky, out float lmstren){
    vec3 light; 
    int SmoothTime = time;// + 750;
    if(SmoothTime < 12000){
        light = sunPosition;
	} else {
        light = moonPosition;
	}
    dir = normalize(gbufferModelViewInverse * vec4(light, 1.0f)).xyz;
    float InterpolationFactor = clamp(GetDayNightInterpolationFactor(time, 4.0f), 0.0f, 1.0f);
    DayNightInterpolation = InterpolationFactor;
    vec3 daycolor = CalculateSunColor();//vec3(1.0f);
    vec3 daysky = vec3(0.2f, 0.4f, 0.8f);
    vec3 nightcolor = vec3(0.1f, 0.15f, 0.9f) * 0.25;//CalculateMoonColor() * ;//vec3(0.1f, 0.2f, 0.6f) * 0.1f;//vec3(0.1f, 0.2f, 0.6f);
    vec3 nightsky = vec3(0.01f);
    float daytorchstrength = 20.0f / 16.0f;
    float nighttorchstrength = 35.0f / 16.0f;//80.0f / 16.0f;
    color = mix(daycolor, nightcolor, InterpolationFactor);
    sky = mix(daysky, nightsky, InterpolationFactor);
    lmstren = mix(daytorchstrength, nighttorchstrength, InterpolationFactor);
}

//#define MAX_LIGHTING

void main(){
    gl_Position = ftransform();
    gl_Position /= gl_Position.w;
    texcoords = gl_MultiTexCoord0.st;
    GetWorldLightingData(worldTime, LightVector, LightColor, SkyColor, LightMapStrength);
    //LightMapStrength = 1.0f;
    HandTorch = min(CalculateEmission(heldItemId) + CalculateEmission(heldItemId2), 1.0f);
    MaxDistance = far;
    #ifdef VIBRANCY_BOOST
    SkyColor *= 1.2f;
    LightColor *= 1.3f;
    SkyColor *= 1.0f + (0.5f * rainStrength);
    #else
    #ifdef MAX_LIGHTING
    SkyColor *= 0.605437f;
    #else
    SkyColor *= 0.607f;
    #endif
    LightColor *= (2.4 + 5.4f) / 2.0f;

    #endif

    //SkyColor *= 0.707f;
    //LightColor *= 1.4142f;// * 2.0f;
   //LightColor *= 1000.0f;
}