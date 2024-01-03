#version 120

#include "lib/util.glsl"

varying vec2 texcoords;
varying float RainBloom;

void main() {
	gl_Position = ftransform();
	texcoords = gl_MultiTexCoord0.st;
	RainBloom = rainStrength * 0.5f;
	RainBloom++;
}
