#version 120

#include "lib/util.glsl"

varying vec2 texcoords;
varying vec3 ViewCoords;

void main() {
    #ifdef SCREEN_SPACE_REFLECTIONS
    gl_Position = ftransform();
    texcoords = gl_MultiTexCoord0.st;
    ViewCoords = (gbufferProjectionInverse * vec4(gl_Position.xy, 1.0f, 1.0f)).xyz;
    #else
    gl_Position = vec4(100000.0f);
    #endif
}