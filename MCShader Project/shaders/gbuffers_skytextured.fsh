#version 120

#include "lib/util.glsl"

varying vec4 color;
varying vec2 texcoords;

void main() {
    /* DRAWBUFFERS:0123 */
    #if 0
    GCOLOR_OUT = texture2D(texture, texcoords) * color * vec4(1.0f);
    GDEPTH_OUT = vec4(0.0f, 0.0f, 0.0f, 0.0f);
    #endif
    //discard;
    GDEPTH_OUT = vec4(0.0f, 1.0f, 0.0f, 0.0f);

}