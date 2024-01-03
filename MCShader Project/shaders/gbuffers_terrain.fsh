#version 120

#include "lib/util.glsl"

varying vec4 color;
varying vec2 texcoords;
varying vec2 lmcoords;
varying vec3 normal;
varying vec3 rawNormal;
varying float Emission;
varying float CalcLighting;
varying float Fire;
varying mat3 tbnMatrix;

void main(){
    vec4 Color = texture2D(texture, texcoords);
    /* DRAWBUFFERS:0123 */
    GCOLOR_OUT = Color * color;
    GDEPTH_OUT = vec4(PackTwo16BitTo32Bit(lmcoords.s ,lmcoords.t), 0.0f, Emission, CalcLighting);
    GNORMAL_OUT = vec4(rawNormal, 0.0f);
    GSPECULAR_OUT = vec4(0.0f);
}