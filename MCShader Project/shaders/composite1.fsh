#version 120

#include "lib/util.glsl"

//#define LIGHTING_DEBUG 

varying vec2 texcoords;
varying vec3 LightDirection;
varying vec3 LightColor;
varying vec3 SkyColor;
varying float LightMapStrength;
varying vec3 LightVector;
varying float DayNightInterpolation;
varying float HandTorch;
varying float MaxDistance;

#define SOFT_SHADOW_SAMPLE_QUALITY 4.0f
#define SOFT_SHADOW_SIZE 1.0f //0.707f
#define CalculateShadow CalculateSoftShadow

const float ShadowBias = 0.005f;//0.01f;

vec3 LightMapColor = vec3(0.8f, 0.4f, 0.2f) * LightMapStrength * 0.35f;
const float MinimumLighting = 0.0f; //0.1f
const float MaximumLighting = 2.0f;

#define LIGHTING_POWER 0.7f

#define MINIMUM_RAIN_BRIGHTNESS 0.2f

float ColorSpec;

vec3 RainColor(in vec3 color){
    float InverseRainStrength = 1.0f - rainStrength;
    float ColorDarkeningFactor = clamp(InverseRainStrength + MINIMUM_RAIN_BRIGHTNESS, 0.0f, 1.0f);
    return color;// * ColorDarkeningFactor;
}

float CalculateHardShadow(in vec2 texcoord){
	vec3 ShadowPos = GetFragmentShadowSpace(texcoord);
	vec2 ShadowTexCoord = ShadowPos.xy;
	float ShadowDepthSample = texture2D(shadow, ShadowTexCoord).r;
	return step(ShadowPos.z - ShadowDepthSample, ShadowBias);
}

float GaussianCurve(in vec2 coords, float sigma){
    float value = (coords.x * coords.x) + (coords.y * coords.y);
    float sigmasquare = sigma * sigma;
    value /= sigmasquare * -2.0f;
    value = exp(value);
    value /= sigmasquare * 6.2831f;
    return value;
}

//#define ADVANCED_RANDOM_ROTATION //ANIMATED_NOISE
//The following two functions are taken from https://www.gamedev.net/tutorials/programming/graphics/contact-hardening-soft-shadows-made-fast-r4906/
const float GoldenAngle = 2.4f;
vec2 VogelDiskSample(in int sampleIndex, in int samplesCount, in float phi) {
  	float r = sqrt(sampleIndex + 0.5f) / sqrt(samplesCount);
  	float theta = sampleIndex * GoldenAngle + phi;

  	float sine, cosine;
  	//sincos(theta, sine, cosine);
	sine = sin(theta);
	cosine = sin(theta);
  
  	return vec2(r * cosine, r * sine);
}

float InterleavedGradientNoise(vec2 position_screen)
{
	vec3 magic = vec3(0.06711056f, 0.00583715f, 52.9829189f);
	return fract(magic.z * fract(dot(position_screen, magic.xy)));
}

//#define CONTACT_HARDENING_SOFT_SHADOWS
#define CONTACT_HARDENING_SOFT_SHADOW_QUALITY 24
#define CONTACT_HARDENING_SOFT_SHADOW_SIZE

const int ShadowMapSize = shadowMapResolution / 4096;

//#define GAUSSIAN_SHADOWS
//#define CLOUD_SHADOWS

vec3 CalculateSoftShadow(in vec2 texcoord, in vec3 normal, in vec3 LightPos){
	vec3 ShadowPos = GetFragmentShadowSpace(texcoord);
	#ifdef SHADOW_DISTORTION
	vec3 ShadowProjectionPos = ShadowPos * 2.0f - 1.0f;
	float Distortion = DistortionFactor(ShadowProjectionPos.xy);
	ShadowProjectionPos *= ShadowLOD;
	float CalculatedShadowBias = dot(LightVector, normal) * (Distortion * Distortion) * ShadowBias;
	#else
	float CalculatedShadowBias = dot(LightVector, normal) * ShadowBias;
	#endif
	vec3 AccumulatedSamples = vec3(0.0f);
	//#ifndef GAUSSIAN_SHADOWS
	float SampleCount = 0;
	//#endif
	#ifdef ADVANCED_RANDOM_ROTATION
	mat2 OffsetRotation = CreateRandomRotation(texcoord + frameTimeCounter);
	#else
	mat2 OffsetRotation = CreateRandomRotation(texcoord);
	#endif
	#ifdef CONTACT_HARDENING_SOFT_SHADOWS
	for(int sample = 0; sample < CONTACT_HARDENING_SOFT_SHADOW_QUALITY; sample++){
		vec2 Offset = VogelDiskSample(sample, CONTACT_HARDENING_SOFT_SHADOW_QUALITY, 5.618f) / shadowMapResolution * CONTACT_HARDENING_SOFT_SHADOW_SIZE;
	#else
	for(float x = -SOFT_SHADOW_SAMPLE_QUALITY; x <= SOFT_SHADOW_SAMPLE_QUALITY; x++){
		for(float y = -SOFT_SHADOW_SAMPLE_QUALITY; y <= SOFT_SHADOW_SAMPLE_QUALITY; y++){
			vec2 Offset = vec2(x, y) / shadowMapResolution * SOFT_SHADOW_SIZE;
	#endif
			Offset = OffsetRotation * Offset;
			vec2 SampleCoord = ShadowPos.st + Offset;
			float ShadowMapSample = texture2D(shadowtex0, SampleCoord).r; //shadow
			float LightVisiblity = step(ShadowPos.z - ShadowMapSample, CalculatedShadowBias);
			float TransparentShadowMapSample =  texture2D(shadowtex1, SampleCoord).r;
			float TransparencyVisibility = step(ShadowPos.z - TransparentShadowMapSample, CalculatedShadowBias);
			vec4 SampleColor = texture2D(shadowcolor0, SampleCoord);
			SampleColor.rgb *= SampleColor.a;
			SampleColor.rgb = mix(SampleColor.rgb * TransparencyVisibility, vec3(1.0f),  LightVisiblity);
			#ifdef GAUSSIAN_SHADOWS
			AccumulatedSamples += SampleColor.rgb * GaussianCurve(Offset, 0.14);
			SampleCount++;
			#else
			AccumulatedSamples += SampleColor.rgb;
			SampleCount++;
			#endif
	#ifdef CONTACT_HARDENING_SOFT_SHADOWS
	}
	#else
		}
	}
	#endif
	#ifdef GAUSSIAN_SHADOWS
	vec3 ShadowStrength = (1.0f - rainStrength ) * AccumulatedSamples;
	//ShadowStrength *= 0.1f;
	//ShadowStrength *= 0.35f;
	//ShadowStrength = sqrt(ShadowStrength);
	ShadowStrength /= SampleCount;
	#else
	vec3 ShadowStrength = (1.0f - rainStrength ) * AccumulatedSamples / SampleCount;
	#endif
	//ShadowStrength = sqrt(ShadowStrength);
	#ifdef CLOUD_SHADOWS
	Ray SkyRay;
	Plane SkyPlane;
	SkyRay.Origin = GetFragmentWorldSpace(texcoord);
	SkyRay.Direction = LightPos;
	SkyPlane.Normal = vec3(0.0f, -1.0f, 0.0f);
	SkyPlane.Position = vec3(cameraPosition.x, CloudHeight, cameraPosition.z);
    float RayLength = RayPlaneIntersection(SkyRay, SkyPlane);
    vec3 IntersectionPoint = SkyRay.Origin + SkyRay.Direction * RayLength;
    vec2 SkyCoords = IntersectionPoint.xz;
    vec2 SampleCoords = CloudSpeed * frameTimeCounter + SkyCoords * InverseCloudDesnity;
	SampleCoords /= 1000.0f;
	Ray SkyIntersection;
	SkyIntersection.Origin.y = IntersectionPoint.y;
	SkyIntersection.Origin.xz = SampleCoords;
	SkyIntersection.Direction = SkyRay.Direction;
	//ShadowStrength = vec3(CloudCoverage(SkyIntersection));
	#endif
	return ShadowStrength;
}

#define GLOBAL_ILLUMINATION_QUALITY 5.0f
#define GLOBAL_ILLUMINATION_SIZE 10.0f
const float GlobalIlluminationBrightness = 25.0f;
const float GlobalIlluminationConstant = 1.0f;
const float GlobalIlluminationLinear = 1.0f;
const float GlobalIlluminationQuadratic= 1.0f;
const float GlobalIlluminationStrength = 1.0f;

float CalculateGlobalIlluminationAttenuation(float PointDistances){
	return GlobalIlluminationBrightness / (
		GlobalIlluminationConstant +
		GlobalIlluminationLinear * PointDistances +
		GlobalIlluminationQuadratic * PointDistances * PointDistances
	);
}

//#define GLOBAL_ILLUMINATION_DOT_PRODUCT

vec3 CalculateGlobalIllumination(in vec2 texcoord, in vec3 normal){ //RSM GI
	vec2 RotationCoord = texcoord;
	RotationCoord.s *= frameTimeCounter;// * cos(frameTimeCounter);
	RotationCoord.t *= frameTimeCounter;// * sin(frameTimeCounter);
	mat2 OffsetRotation = CreateRandomRotation(RotationCoord);
	vec2 ShadowCoord = GetFragmentShadowSpace(texcoord).xy;
	vec3 WorldPos = GetFragmentWorldSpace(texcoord);
	vec3 AccumulatedSamples = vec3(0.0f);
	float Samples = 0.0f;
	for(float x = -GLOBAL_ILLUMINATION_QUALITY; x < GLOBAL_ILLUMINATION_QUALITY; x++){
		for(float y = -GLOBAL_ILLUMINATION_QUALITY; y < GLOBAL_ILLUMINATION_QUALITY; y++){
			vec2 Offset = vec2(x, y) / shadowMapResolution * GLOBAL_ILLUMINATION_SIZE * OffsetRotation;
			vec2 SampleCoord = ShadowCoord + Offset;
			vec4 ShadowPos = vec4(SampleCoord * 2.0f - 1.0f, texture2D(shadow, SampleCoord).r, 1.0f);
			ShadowPos = shadowProjectionInverse * ShadowPos;
			ShadowPos /= ShadowPos.w;
			vec3 SampleWorldPos = (shadowModelViewInverse * ShadowPos).xyz + cameraPosition;
			vec3 SampleVector = normalize(WorldPos - SampleWorldPos);
			float Attenuation = CalculateGlobalIlluminationAttenuation(sqrt(distance(WorldPos, SampleWorldPos)));
			vec3 SampleColor = texture2D(gaux2, SampleCoord).rgb;
			vec3 SampleNormal = texture2D(gaux3, SampleCoord).rgb * 2.0f - 1.0f;
			float TrasmittedLightStrength = max(dot(SampleNormal, SampleVector), 0.0f);
			float ReceivedLightStrength = max(dot(normal, SampleVector), 0.0f);
			#ifdef GLOBAL_ILLUMINATION_DOT_PRODUCT
			//float SampleWeight = max(dot(SampleNormal, normal), 0.0f);
			#else
			//float SampleWeight = max(sin(acos(dot(SampleNormal, normal))), 0.0f);
			#endif
			AccumulatedSamples += SampleColor * TrasmittedLightStrength * ReceivedLightStrength * Attenuation;
			Samples++;
		}
	}
	return GlobalIlluminationStrength * AccumulatedSamples;
}

const float HandLightBrightness = 1.0f;
const float HandLightConstant =  0.5f;
const float HandLightLinear = 0.2f;
const float HandLightQuadratic = 0.1f;

//#define GLOBAL_ILLUMINATION_DEBUG

//#define RSM_GLOBAL_ILLUMINATION

//#define SKY_LIGHT_GLOBAL_ILLUMINATION

//#define GAMMA_CORRECTION

/*

	#ifdef GAMMA_CORRECTION
	fragment.LightData.PointLighting = fragment.LightData.PointLighting * fragment.LightData.PointLighting;
	#endif
	vec3 WorldPos = GetFragmentWorldSpace(fragment.TexCoord);
	vec3 HandPos = cameraPosition;
	HandPos.y += 1.0f;
	float LightDistance = distance(WorldPos, HandPos);
	float HandLightAttenuation = HandLightBrightness / (HandLightConstant + HandLightLinear * LightDistance + HandLightQuadratic * LightDistance * LightDistance);
	vec3 HandLightVector = normalize(HandPos - WorldPos);
	HandLightAttenuation *= HandTorch;
	HandLightAttenuation *= mix(max(dot(HandLightVector, fragment.Normal), 0.0f), 1.0f, fragment.Depth.z);
	vec3 SunLight = pow(max(dot(fragment.Normal, LightVector), 0.0f), LIGHTING_POWER) * LightColor * mix(CalculateShadow(fragment.TexCoord), 1.0f, fragment.Depth.z);
	vec3 LightMapData = clamp(fragment.LightData.PointLighting, 0.0f, 1.0f) * LightMapColor;
	vec3 SkyLight = SkyColor * fragment.LightData.SkyLighting;
	vec3 ViewDir = normalize(cameraPosition - WorldPos);
	vec3 ReflectionDir = reflect(-LightVector, fragment.Normal);
	vec3 HalfReflectDir = normalize(LightVector + ViewDir);
	//vec3 SpecularLight = pow(max(dot(fragment.Normal, HalfReflectDir), 0.0f), fragment.SpecularPower) * LightColor * fragment.SpecularStrength;
	//ColorSpec =  pow(max(dot(fragment.Normal, HalfReflectDir), 0.0f), fragment.SpecularPower);
	vec3 HandLight = HandLightAttenuation * HandTorch * LightMapColor;
	#ifdef RSM_GLOBAL_ILLUMINATION
	vec3 GlobalIllumination = CalculateGlobalIllumination(fragment.TexCoord, fragment.Normal);
	#else
	vec3 GlobalIllumination = vec3(0.0f);
	#endif
	#ifdef SKY_LIGHT_GLOBAL_ILLUMINATION
	GlobalIllumination += SkyLight;
	#endif
	vec3 LitColor = fragment.Color * clamp(SunLight + LightMapData + GlobalIllumination, vec3(MinimumLighting), vec3(MaximumLighting));
	#ifdef GLOBAL_ILLUMINATION_DEBUG
	return GlobalIllumination;
	#else
	return mix(fragment.Color, LitColor, fragment.Depth.a);
	#endif

	*/
const float EmissiveLightStrength = 1.0f;//2.2f;

//#define MAX_LIGHTING

vec3 CalculateLighting(in Fragment fragment) {
	vec3 BasicLighting = vec3(0.0f); 
	BasicLighting += fragment.LightData.PointLighting * LightMapColor;
	BasicLighting = max(BasicLighting, SkyColor * fragment.LightData.SkyLighting);
	vec3 SunLight = max(dot(fragment.Normal, LightVector), 0.0f) * LightColor * 
	#ifdef SHADOWS
	CalculateShadow(fragment.TexCoord, fragment.Normal, LightVector);
	#else
	1.0f;
	#endif
	#ifdef MAX_LIGHTING
	vec3 Lighting = max(SunLight, BasicLighting);
	#else
	vec3 Lighting = SunLight + BasicLighting;
	#endif
	return mix(fragment.Color * (Lighting), fragment.Color * EmissiveLightStrength, fragment.Depth.z);
}

float OverExposure = 1.2f;
float UnderExposure = 0.5f;

//#define EXPOSURE_TONEMAP

//#define GAMMA_CORRECTION

const float VL_RayMaxSteps = 128.0f;

float VolumetricLighting(in Ray WorldRay){
	float Volumetric = 0.0f;
	vec3 RayPosition = WorldRay.Origin;
	for(float RayStep = 0.0f; RayStep < VL_RayMaxSteps; RayStep++){
		RayPosition += WorldRay.Direction;
		//WorldRay.Direction *= 1.3f;
		vec4 ShadowPos = shadowModelView * vec4(RayPosition, 1.0f);
		#ifdef SHADOW_DISTORTION
		ShadowPos.xy *= ShadowLOD;
		#endif
		ShadowPos = shadowProjection * ShadowPos;
		ShadowPos.xyz /= ShadowPos.w;
		ShadowPos.xy *= SHADOW_INVERSE_SIZE;
		#ifdef SHADOW_DISTORTION
		ShadowPos.xyz = DistortShadow(ShadowPos.xyz);
		#endif
		ShadowPos = ShadowPos * 0.5f + 0.5f;
		Volumetric += step(ShadowPos.z - texture2D(shadowtex0, ShadowPos.st).r, 0.0f);
	}
	Volumetric /= VL_RayMaxSteps;
	//Volumetric /= VL_RayMaxSteps;
	return Volumetric;
}

//const float ExtinctionCoefficient = 1.0f;
//const float InscatteringCoefficient = 1.0f;
const float ExtinctionMax = 6.0f;
const float InscatteringMax = 40.0f;
const float ExtinctionHeightStart = 128.0f;
const float InscatteringHeightStart = 256.0f;
const float ExtinctionCoefficientFactor = 0.025 * 0.00001f;
const float InscatteringCoefficientFactor= 0.045 * 100.0f;
vec3 AtmosphericFogColor = fogColor; 
#define AtmosphereColor AtmosphericFogColor //IDK which one is the better name so I'm doing this instead
//It's better to make all of these variables varying since it might change
//For example, I might be in water or it might be raining
//Or even snowing
//All of these things require use to change the values
//And the only way we can do that is by making them varying
//Unless if we don't care about performance and do them all in the fragment shader

vec3 AtmosphericFog(in vec3 color, in vec3 pos){
	float ExtinctionCoefficient = ExtinctionCoefficientFactor * smoothstep(0.0, ExtinctionMax, ExtinctionHeightStart - pos.y);
	float InscatteringCoefficient = InscatteringCoefficientFactor * smoothstep(0.0, InscatteringMax, InscatteringHeightStart - pos.y);
	float FogDistance = distance(cameraPosition, pos); //Not negating here to stay more true to the formula
	float Extinction = exp(-FogDistance * ExtinctionCoefficient);
	float Inscattering = exp(-FogDistance * InscatteringCoefficient);
	return color * Extinction + AtmosphereColor * (1.0f - InscatteringCoefficient);
}


const float FogRange = 10.0f;
const float FogThickness = 100.0f;
vec3 BasicFog(in vec3 color, in vec3 pos){
	float FogFactor = distance(pos, cameraPosition)/ FogThickness;
	return mix(color, skyColor, 1.0f - exp(-FogFactor));
}

void main(){
	Fragment fragment = GetFragment(texcoords);
	#ifdef LIGHTING_DEBUG
	fragment.Color = vec3(0.5f);
	#endif
	#ifdef GAMMA_CORRECTION
	fragment.Color = pow(fragment.Color, vec3(2.2f));
	#endif
	vec3 WorldPos = GetFragmentWorldSpace(texcoords);
	WorldPos -= cameraPosition;
	float CameraDistance = length(WorldPos);
	vec3 LitColor = CalculateLighting(fragment);
	LitColor = BasicFog(LitColor, WorldPos + cameraPosition); //Well, ig I need to stop doing so many recalculations
	vec4 SkySample = texture2D(gaux1, texcoords);
	//Later I should replace this with a flag to tell the shader whether the fragment is the sky or not
	vec4 CompositeData = MaxDistance - 1.0f > CameraDistance ? vec4(LitColor, fragment.Depth.z) : SkySample;
	vec4 DepthData = SampleDepth(texcoords);
	DepthData = MaxDistance - 1.0f > CameraDistance ?  DepthData : vec4(DepthData.x, 0.0f, DepthData.zw);
	Ray WorldRay;
	WorldRay.Origin = vec3(0.0f, 2.0f, 0.0f);
	WorldRay.Direction = normalize(GetFragmentWorldSpace(texcoords) - cameraPosition);
	float Volumetrics = VolumetricLighting(WorldRay);
	//CompositeData.rgb *= Volumetrics;
	/* DRAWBUFFERS:01 */
    GCOLOR_OUT = vec4(CompositeData);
	GDEPTH_OUT = vec4(DepthData);
}