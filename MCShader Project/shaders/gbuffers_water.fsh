#version 120

#include "lib/util.glsl"

varying vec4 color;
varying vec2 texcoords;
varying vec2 lmcoords;
varying vec3 rawNormal;
varying float WaterMask;

//#define DEFAULT_WATER
const float WaterTransparency = 0.5f;
#ifdef DEFAULT_WATER
#define WATER_COLOR texture2D(texture, texcoords)
#else
#define WATER_COLOR vec4(0.1f, 0.2f, 0.7f, WaterTransparency)
#endif

void main(){
    vec4 BlockColor = mix( texture2D(texture, texcoords), WATER_COLOR * color, WaterMask);
    /* DRAWBUFFERS:512 */
    GCOLOR_OUT = vec4(BlockColor);
    GDEPTH_OUT = vec4(PackTwo16BitTo32Bit(lmcoords.s ,lmcoords.t), WaterMask, 0.0f, 1.0f);
    GNORMAL_OUT = vec4(rawNormal, 1.0f);
    //GSPECULAR_OUT = vec4(2.0f);
}