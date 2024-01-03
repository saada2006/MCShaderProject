#version 120

#include "lib/util.glsl"

varying vec4 color;
varying vec2 texcoords;
varying vec2 lmcoords;
varying vec3 normal;
varying vec3 rawNormal;

void main(){
    gl_Position = ftransform();
    color = gl_Color; 
    texcoords = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoords = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    rawNormal = mat3(gbufferModelViewInverse) * gl_NormalMatrix * gl_Normal;
}