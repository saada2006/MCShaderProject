#version 120

#include "lib/util.glsl"

varying vec2 texcoords;
varying vec4 color;
#ifdef REFLECTIVE_SHADOW_MAPS
varying vec3 normal;
varying vec2 lmcoords;
varying float Emission;
varying float CalcLighting;
#endif


void main(){
    vec4 BlockColor = texture2D(texture, texcoords);
    BlockColor *= color;
    GCOLOR_OUT =  BlockColor;
}

