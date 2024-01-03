#version 120

#include "lib/util.glsl"

attribute vec4 mc_Entity;
attribute vec4 at_tangent;     

varying vec4 color;
varying vec2 texcoords;
varying vec2 lmcoords;
varying vec3 normal;
varying vec3 rawNormal;
varying float WaterMask; //To fix non-water objects that for some reason run in this shader
varying vec3 SceneWorldPos;
varying float Reflectance;
varying mat3 tbnMatrix;

#define WAVE_STRENGTH 0.7945f
#define WAVE_FREQUENCY 4.5f / 2.0f
#define WAVE_AMPLITUDE 0.2245f

#define MATH_PI 3.1415927

float RandomSineWave(in float x){
    return sin(2 * x) + sin(MATH_PI * x);
}

float RealisticWaterDisplacement(in float pos, in float time){
    float SinWave = WAVE_STRENGTH * pos + WAVE_FREQUENCY * time;
    return WAVE_AMPLITUDE * ((RandomSineWave(SinWave) / 2.0f) * 0.5f + 0.5f);
}

vec3 RealisticWater(in vec3 pos){
    float Displacement = RealisticWaterDisplacement(pos.x, frameTimeCounter) * RealisticWaterDisplacement(pos.z, frameTimeCounter);
    pos.y += Displacement;
    return pos;
}

vec4 TransformWater(in vec3 pos){
    vec4 WorldPos = gbufferProjectionInverse * vec4(pos, 1.0f);
    WorldPos /= WorldPos.w;
    WorldPos = gbufferModelViewInverse * WorldPos;
    WorldPos.xyz += cameraPosition;
    vec3 WavePos = RealisticWater(WorldPos.xyz);
    return gbufferProjection * gbufferModelView * vec4(WavePos, 1.0f);
}

void main(){
    vec3 WorldPos = (gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex).xyz + cameraPosition;
    if(mc_Entity.x == 8 || mc_Entity.x == 9){
        WaterMask = 1.0f;
    } else{
        WaterMask = 0.0f;
    }
    vec3 WavePos = RealisticWater(WorldPos.xyz);
    vec3 Displacement = WavePos - WorldPos;
    WorldPos = mix(WorldPos, WavePos, WaterMask);
    WorldPos -= cameraPosition;
    SceneWorldPos = WorldPos;
    gl_Position = gbufferProjection * gbufferModelView * vec4(WorldPos, 1.0f);
    color = gl_Color;
    texcoords = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoords = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    rawNormal = mat3(gbufferModelViewInverse) * gl_NormalMatrix * gl_Normal;
    //Code taken from Slidurs Vibrant v1.22
    vec3 tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
	vec3 binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
	tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
					 tangent.y, binormal.y, normal.y,
					 tangent.z, binormal.z, normal.z);
    ///vec3 WaterNormal = Displacement * 10;
    ///WaterNormal = normalize(WaterNormal);
    //WaterNormal.y = rawNormal.y;
    //WaterNormal = normalize(WaterNormal);
    ////rawNormal = mix( rawNormal, WaterNormal, WaterMask * 0.2f);
}