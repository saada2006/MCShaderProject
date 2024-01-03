#version 120

#include "lib/util.glsl"

varying vec4 color;
varying vec2 texcoords;
varying vec2 lmcoords;
varying vec3 normal;
varying vec3 rawNormal;
varying float Emission;
varying float CalcLighting;

void main(){
    /* DRAWBUFFERS:0123 */
    GCOLOR_OUT = texture2D(texture, texcoords) * color;
    GDEPTH_OUT = vec4(PackTwo16BitTo32Bit(lmcoords.s ,lmcoords.t), 0.0f, 0.0f, 1.0f);
    GNORMAL_OUT = vec4(rawNormal, 1.0f); //alpha is used for determining normal weight
}