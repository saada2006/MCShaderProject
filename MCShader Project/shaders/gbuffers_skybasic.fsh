#version 120

#include "lib/util.glsl"

varying vec4 color;

void main() {
    //discard;
    /* DRAWBUFFERS:012 */
    GCOLOR_OUT = vec4(vec3(0.0f), 1.0f);//color;
    GDEPTH_OUT = vec4(0.0f, 1.0f, 0.0f, 0.0f);
    GNORMAL_OUT = vec4(mat3(gbufferProjectionInverse) * normalize(gl_FragCoord.xyz), 1.0f);
}