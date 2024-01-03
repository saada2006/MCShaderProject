#version 120

#include "lib/util.glsl"

varying vec4 color;
varying vec2 texcoords;

vec4 GetSunColor(in int time){
    if(time < 12000){
        return vec4(CalculateSunColor(), 1.0f);
    }
}

void main(){
    gl_Position = ftransform();
    color = GetSunColor(worldTime);
    texcoords = gl_MultiTexCoord0.st;
}