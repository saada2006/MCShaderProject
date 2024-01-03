#version 120

#include "lib/util.glsl" //Includes the required uniforms

varying vec2 texcoords;

#define texcoord texcoords

#define BLOOM_SIZE 3

float GaussianCurve(in vec2 coords, float sigma){
    float value = (coords.x * coords.x) + (coords.y * coords.y);
    float sigmasquare = sigma * sigma;
    value /= sigmasquare * -2;
    value = exp(value);
    value /= sigmasquare * 6.2831f;
    return value;
}

const float BloomBlurPower [7] = float[](0.0001, 0.06, 0.08, 0.14, 0.28, 10.44, 0.56);
const float BloomBlurFactor [7] = float[] (10.0f, 3.0f, 1.5f, 1.25f, 1.125f, 1.0f, 0.8f);

vec3 CalculateBloomLOD(in int LOD, in vec2 texcoords) {
    vec3 AccumulatedSamples = vec3(0.0f);
    float Scale = exp2(float(LOD));
    float Sigma = BloomBlurPower[LOD];
    mat2 RandomRotation = CreateRandomRotation(texcoords + frameTimeCounter);
    for(float x = -BLOOM_SIZE; x <= BLOOM_SIZE; x++){
        for(float y = -BLOOM_SIZE; y <= BLOOM_SIZE; y++){
            vec2 PositionOffset = RandomRotation * vec2(x, y);
            vec2 TexelOffset = vec2(PositionOffset.x / viewWidth, PositionOffset.y / viewHeight) * Scale;
            float Weight = GaussianCurve(PositionOffset, Sigma);
            AccumulatedSamples += texture2DLod(gaux1, texcoords + TexelOffset, LOD).rgb * Weight;
        }
    }
    return AccumulatedSamples * BloomBlurFactor[LOD];
}

struct BloomData {
    vec3 BlurLOD0;
    vec3 BlurLOD1;
    vec3 BlurLOD2;
    vec3 BlurLOD3;
    vec3 BlurLOD4;
    vec3 BlurLOD5;
    vec3 BlurLOD6;
    vec3 Bloom;
};

//#define LOD_BLOOM

vec3 CalculateBloom(in int LOD, in vec2 offset) {

	float scale = pow(2.0f, float(LOD));

	float padding = 0.02f;

	if (	texcoord.s - offset.s + padding < 1.0f / scale + (padding * 2.0f) 
		&&  texcoord.t - offset.t + padding < 1.0f / scale + (padding * 2.0f)
		&&  texcoord.s - offset.s + padding > 0.0f 
		&&  texcoord.t - offset.t + padding > 0.0f) {
		
		vec3 bloom = vec3(0.0f);
		float allWeights = 0.0f;

		for (int i = 0; i < 6; i++) {
			for (int j = 0; j < 6; j++) {

				float weight = 1.0f - distance(vec2(i, j), vec2(2.5f)) * 0.72;
					  weight = clamp(weight, 0.0f, 1.0f);
					  weight = 1.0f - cos(weight * 3.1415 * 0.5f);
					  weight = pow(weight, 2.0f);
				vec2 coord = vec2(i - 2.5, j - 2.5);
					 coord.x /= viewWidth;
					 coord.y /= viewHeight;
					

				vec2 finalCoord = (texcoord.st + coord.st - offset.st) * scale;

				if (weight > 0.0f)
				{
					bloom += pow(clamp(texture2D(gaux1, finalCoord, 0).rgb, vec3(0.0f), vec3(1.0f)), vec3(2.2f)) * weight;
					allWeights += 1.0f * weight;
				}
			}
		}

		bloom /= allWeights;

		return bloom;

	} else {
		return vec3(0.0f);
	}
	
}

#define BLOOM_FUNC CalculateBloomLOD

void main() {
	vec3 bloom  = CalculateBloom(2, vec2(0.0f)				+ vec2(0.000f, 0.000f)	);
		 bloom += CalculateBloom(3, vec2(0.0f, 0.25f)		+ vec2(0.000f, 0.025f)	);
		 bloom += CalculateBloom(4, vec2(0.125f, 0.25f)		+ vec2(0.025f, 0.025f)	);
		 bloom += CalculateBloom(5, vec2(0.1875f, 0.25f)	+ vec2(0.050f, 0.025f)	);
		 bloom += CalculateBloom(6, vec2(0.21875f, 0.25f)	+ vec2(0.075f, 0.025f)	);
		 bloom += CalculateBloom(7, vec2(0.25f, 0.25f)		+ vec2(0.100f, 0.025f)	);
		 //bloom += CalculateBloom(8, vec2(0.28f, 0.25f)		+ vec2(0.125f, 0.025f)	);
		 bloom = pow(bloom, vec3(1.0f / (1.0f + 1.2f)));

	/* DRAWBUFFERS:4 */
	gl_FragData[0] = texture2D(gaux1, texcoord.st);
}