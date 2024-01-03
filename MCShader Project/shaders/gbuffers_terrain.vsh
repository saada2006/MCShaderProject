#version 120

#include "lib/util.glsl"

attribute vec4 mc_Entity;
attribute vec3 mc_midTexCoord;   

varying vec4 color;
varying vec2 texcoords;
varying vec2 lmcoords;
varying vec3 normal;
varying vec3 rawNormal;
varying float Emission;
varying float CalcLighting;
varying float Fire;
varying mat3 tbnMatrix;

//#define PLANT_FIX //Real basic sub surface scattering
//#define WAVING_PLANTS

void main(){
    #ifdef WAVING_PLANTS
    vec3 WorldPos = (gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex).xyz + cameraPosition;
    if(ShouldPlantTransform(mc_Entity.x, gl_MultiTexCoord0.t, mc_midTexCoord.t)){
        WorldPos = PlantTransform(WorldPos);
    }
    gl_Position = gbufferProjection * gbufferModelView * vec4(WorldPos -cameraPosition, 1.0f);
    #else
    gl_Position = ftransform();
    #endif
    color = gl_Color;
    texcoords = gl_MultiTexCoord0.st;
    lmcoords = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;
    rawNormal = gl_Normal;
    Emission = CalculateEmission(mc_Entity.x);
    CalcLighting = 1.0f - Emission;
    #ifdef PLANT_FIX
    if(mc_Entity.x == 31.0f){
        vec3 SunNormal = normalize((gbufferModelViewInverse * vec4(worldTime < 12000 ? normalize(sunPosition) : normalize(moonPosition), 1.0f)).xyz);
        rawNormal = mix(SunNormal, rawNormal, 0.3f);
    }
    #endif
}