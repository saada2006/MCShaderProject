#version 120

#include "lib/util.glsl"

varying vec2 texcoords;
varying vec3 WorldRay;

void main(){
    gl_Position = ftransform();
    gl_Position /= gl_Position.w;
    gl_Position.z = 0.99;
    texcoords = gl_MultiTexCoord0.st;
    vec4 WorldRayProjection = gl_Position;
    WorldRayProjection.z = 1.0f;
    WorldRayProjection = gbufferProjectionInverse * WorldRayProjection;
    WorldRayProjection /= WorldRayProjection.w;
    WorldRay = (gbufferModelViewInverse * WorldRayProjection).xyz;
}