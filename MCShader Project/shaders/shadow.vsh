#version 120

#include "lib/util.glsl"

attribute vec4 mc_Entity;
attribute vec3 mc_midTexCoord;

//#define REFLECTIVE_SHADOW_MAPS

varying vec2 texcoords; //texcoords0
varying vec4 color;
#ifdef REFLECTIVE_SHADOW_MAPS
varying vec3 normal;
varying vec2 lmcoords;
varying float Emission;
varying float CalcLighting;
#endif
//varying float Transparency;

#define STAINED_GLASS_PANE_MATERIAL_ID 160.0f
#define STAINED_GLASS_BLOCK_MATERIAL_ID 95.0f
#define ICE_BLOCK_MATERIAL_ID 79.0f
#define FLOWING_WATER_MATERIAL_ID 8.0f 
#define STILL_WATER_MATERIAL_ID 9.0f //SOURCE_WATER_MATERIAL_ID

float CalculateTransparency(in float id){
    if(
        id == ICE_BLOCK_MATERIAL_ID ||
        id == STAINED_GLASS_BLOCK_MATERIAL_ID ||
        id == STAINED_GLASS_PANE_MATERIAL_ID ||
        id == FLOWING_WATER_MATERIAL_ID ||
        id == STILL_WATER_MATERIAL_ID
    ){
        return 1.0f;
    }
    return 0.0f;
}

void main(){
#ifdef SHADOWS
    texcoords = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vec3 WorldPos = (shadowModelViewInverse * gl_ModelViewMatrix * gl_Vertex).xyz + cameraPosition;
    if(ShouldPlantTransform(mc_Entity.x, texcoords.t, mc_midTexCoord.t)){
        WorldPos = PlantTransform(WorldPos);
    }
    gl_Position = shadowModelView * vec4(WorldPos - cameraPosition, 1.0f);
    #ifdef SHADOW_DISTORTION
    gl_Position.xy *= ShadowLOD;
    #endif
    gl_Position = shadowProjection * gl_Position;
    gl_Position /= gl_Position.w;
    #ifdef SHADOW_DISTORTION
    gl_Position.xyz = DistortShadow(gl_Position.xyz);
    #endif
    #ifdef REFLECTIVE_SHADOW_MAPS
    lmcoords = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    color = gl_Color;
    Emission = CalculateEmission(mc_Entity.x);
    CalcLighting = 1.0f - Emission;
    #endif
#else
    gl_Position = vec4(12345787688678.0f);
#endif

}
