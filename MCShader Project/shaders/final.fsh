#version 120

#include "lib/util.glsl"

varying vec2 texcoords;
varying float RainBloom;

#define BLOOM_RADIUS 8.0f
#define BLOOM_SIZE 4.0f
#define BLOOM_POWER 40.0f
#define BLOOM_STRENGTH 0.25f
#define BLOOM_MIX 0.2f
#define BLOOM_CUTOFF vec3(0.0f)

float GetBlurSize(in float cameraDistance){
	cameraDistance -= near;
	cameraDistance /= far;
	cameraDistance += 0.2f;
	cameraDistance = clamp(cameraDistance, 0.0f, 1.0f);
	return pow(1.0f - cameraDistance, 2.0f);
}

float CalculateBloomWeight(vec2 origin, vec2 sample){
	float factor = distance(origin, sample);
	return 1.0f / (pow(factor, 2.0f) + 1.0f);
}

bool IsBloomColor(vec3 ColorSample){
	vec3 Cutoff = BLOOM_CUTOFF;
	return (ColorSample.r > Cutoff.r) && (ColorSample.g > Cutoff.g) && (ColorSample.b > Cutoff.b);
	//return (dot(ColorSample, BLOOM_CUTOFF) > 1.0f);
}
/*
vec3 CalculateBloom(in vec2 texcoord){
	mat2 Rotation = CreateRandomRotation(texcoord);
	vec3 AccumulatedSamples = vec3(0.0f);
	float Samples = 0.0f;
	float BlurSize = GetBlurSize(length(GetFragmentWorldSpace(texcoords)  - cameraPosition));
	for(float x = -BLOOM_RADIUS; x < BLOOM_RADIUS; x++){
		for(float y = -BLOOM_RADIUS; y < BLOOM_RADIUS; y++){
			vec2 offset = vec2(cos(x * 10) * x, sin(y * 10) * y) * BLOOM_SIZE;
			offset.x /= viewWidth;
			offset.y /= viewHeight;
			//offset = Rotation * offset;
			vec2 SampleCoord = texcoord + offset;
			vec4 ColorData = texture2D(gcolor, SampleCoord);
			vec3 ColorSample = ColorData.rgb;

			if(ColorData.a > 0.0f && IsBloomColor(ColorSample)){
				ColorSample = ColorSample * CalculateBloomWeight(texcoord, SampleCoord);
				AccumulatedSamples += ColorSample;
				Samples++;
			}
		}
	}
	return clamp(AccumulatedSamples / Samples, vec3(0.0f), vec3(1.0f));
}
*/
vec3 CalculateBloom(in vec2 texcoord){
	mat2 Rotation = CreateRandomRotation(texcoord);
	vec3 AccumulatedSamples = vec3(0.0f);
	float Samples = 0.0f;
	for(float x = 0; x < BLOOM_RADIUS; x++){
		for(float y = 0; y < BLOOM_RADIUS; y++){
			vec2 offset = vec2(x / viewWidth, y / viewHeight) * BLOOM_SIZE;
			vec2 SampleCoord = texcoord + offset;
			vec4 ColorData = texture2D(gcolor, SampleCoord);
			float SampleWeight = dot(ColorData.rgb, vec3(1.0f)) * ColorData.a;
			ColorData.rgb = ColorData.rgb * 1.0f / (pow(length(offset) * 40.0f, BLOOM_POWER) + 0.8f) * SampleWeight;// * pow(length(ColorData.rgb) / length(vec3(0.9f)), 3.0f);
			AccumulatedSamples = AccumulatedSamples + ColorData.rgb;
			Samples++;
		}
	}
	float BloomStrength = BLOOM_STRENGTH * RainBloom;
	return BloomStrength * AccumulatedSamples / Samples;
}

//#define BLOOM_DEBUG
//#define RSM_DEBUG
//#define EXPOSURE_TONEMAP
//#define GAMMA_CORRECTION
//#define TONEMAP
//#define BLOOM_POST_PROCESSING
//#define VIBRANCY_BOOST
//#define VIBRANCY_LIMITER

const float Exposure = 1.0f;
const float BloomUnderExposure = 0.9f;//0.5f;
const float BloomOverExposure = 1.2f;
const float OverExposure = 7.2f; //A bit off but ok
const float UnderExposure = 1.0f / 20.2f;
const float Contrast = 2.2f;
const float BloomContrast = 1.0f / 2.2f;
const float ColorContrast = 1.2f;
const float FinalColorConstrast = 2.2f;

//#define SHADOW_MAP_DEBUG

void main(){
	vec3 Color = SampleColor(texcoords);
	vec3 Bloom = texture2DLod(gaux1, texcoords, 0).rgb;//CalculateBloom(texcoords);
	vec3 FinalColor = Color;
	#ifdef VIBRANCY_BOOST
	FinalColor.rgb = mix(FinalColor.rgb * UnderExposure, FinalColor.rgb * OverExposure, FinalColor.rgb);
	#ifdef VIBRANCY_LIMITER
	FinalColor = FinalColor / (FinalColor + 0.7f);
	#endif
	#endif
	//FinalColor = pow(FinalColor, vec3(0.7f));
	#ifdef TONEMAP
	vec3 OriginalColor = FinalColor;
	#ifdef EXPOSURE_TONEMAP
	FinalColor = 1.0f - exp(-FinalColor * Exposure);
	#else
	FinalColor = FinalColor / (FinalColor + 1.0f);
	//FinalColor = FinalColor / (FinalColor + 1.0f);
	//FinalColor = FinalColor / (FinalColor + 1.0f);
	FinalColor = saturation(FinalColor, 1.15f); //1.45 with one more tonemap enabled
	//FinalColor = FinalColor / (FinalColor + 1.0f);
	#endif
	//FinalColor = mix(OriginalColor, FinalColor, FinalColor);
	#endif
	Bloom = clamp(Bloom, vec3(0.0f), vec3(1.0f));
	#ifdef BLOOM
	#ifdef BLOOM_POST_PROCESSING
	Bloom.rgb = mix(Bloom.rgb * BloomUnderExposure, Bloom.rgb * BloomOverExposure, Bloom.rgb);
    Bloom.rgb = pow(Bloom.rgb, vec3(BloomContrast));
	#endif
	FinalColor += Bloom;
	#endif
	#ifdef GAMMA_CORRECTION
	FinalColor = pow(FinalColor, vec3(1.0f / 2.2f));
	#endif
	#ifdef VIBRANCY_BOOST
	//FinalColor *= ColorContrast;
	//FinalColor = pow(FinalColor, vec3(ColorContrast)); //I am not dumb, I am just too lazy to do ColorContrast / 2.2f in the previous line
	#endif
	//FinalColor *= 1.2f;
	//FinalColor = 1.0f - FinalColor;
	#ifdef SHADOW_MAP_DEBUG
	FinalColor = vec3(texture2D(shadow, texcoords));
	#endif
	FinalColor = pow(FinalColor, vec3(FinalColorConstrast));
	FinalColor *= FinalColorConstrast;
	//FinalColor = FinalColor / (FinalColor + 1.0f);
	FinalColor = sqrt(FinalColor);
	GCOLOR_OUT = vec4(FinalColor, 1.0f);
}