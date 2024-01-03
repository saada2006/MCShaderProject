#version 120

#include "lib/util.glsl"

varying vec2 texcoords;

const float UnderExposure = 0.5f;
const float OverExposure = 1.2f;
const float Contrast = 2.2f;

//#define BLOOM_HDR

void main(){
    vec4 ColorData = texture2D(gcolor, texcoords);
    float ColorBrightness = (ColorData.r + ColorData.g + ColorData.b) / 3.0;
    if(ColorBrightness < 0.25f){
        ColorData.rgb = vec3(0.0f);
    }
    #ifdef BLOOM_HDR
    ColorData.rgb = mix(ColorData.rgb * UnderExposure, ColorData.rgb * OverExposure, ColorData.rgb);
    ColorData.rgb = pow(ColorData.rgb, vec3(Contrast));
    #endif
    #ifdef BLOOM
    /* DRAWBUFFERS:4 */
    gl_FragData[0] = vec4(ColorData.rgb * ColorData.a, 1.0f);
    #endif
}