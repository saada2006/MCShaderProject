#version 120

#include "lib/util.glsl"

varying vec2 texcoords;
varying vec3 WorldRay;

//Taken from https://community.khronos.org/t/texture2dlod-cant-be-found/3624
float MipmapLevel(in vec2 coords, in vec2 texSize)
{
	vec2 coordInPix = coords * texSize;
	vec2 dx = dFdx(coordInPix);
	vec2 dy = dFdy(coordInPix);
	float d = max(dot(dx, dx), dot(dy, dy));
	return 0.4 * log2(d);
}

float PhaseRayleigh(in float theta){
    float cosine = cos(theta);
    float phase = 1.0f + cosine * cosine;
    phase *= 0.75f;
    return phase;
}

float PhaseMie(in float theta, in float g){
    float gsquare = g * g;
    float cosine = cos(theta);
    float phase0 = 3 * (1 - gsquare);
    phase0 /= 2 *(2 + gsquare);
    float phase1 = 1 + cosine * cosine;
    phase1 /= pow(1 + gsquare - 2 * g * cosine, 1.5f);
    return phase0 * phase1;
}

float Polarisability(in float refraction, in float density) {
    float polarisablity = (refraction * refraction - 1.0f);
    polarisablity *= polarisablity;
    polarisablity *= 19.7392088022f; //Could combine with previous but too lazy
    return polarisablity / (3.0f * density * density);
}

float ScatteringCoefficientRayleigh(in float lambda, in float refraction,in float density){
    float ScatteringCoefficient = 12.5663706144f * density;
    ScatteringCoefficient /= (lambda * lambda * lambda);
    return ScatteringCoefficient * Polarisability(refraction, density);
}

float ScatteringCoefficientMie(in float refraction,in float density){
    float ScatteringCoefficient = 12.5663706144f * density;
    //ScatteringCoefficient /= (lambda * lambda * lambda);
    return ScatteringCoefficient * Polarisability(refraction, density);
}

float DensityRayleigh(in float height){
    return exp(height / 8000);
}

float DensityMie(in float height){
    return exp(height / 1200);
}

float SpectralIntensity(in float lamda){ //Todo, fill in later
    return 1.0f;
}

float ScatteringIntensityRayleigh(in float lambda, in float theta, in float altitude){
    return SpectralIntensity(lambda) * DensityRayleigh(altitude) * PhaseRayleigh(theta) * ScatteringCoefficientRayleigh(theta, 1.0f, 1.3);
}

float Phase(in float theta, in float g){
    float Phase0 = 3 * (1 - g * g);
    Phase0 /= 2 * (2 + g * g);
    float Phase1 = 1 + cos(theta) * cos(theta);
    Phase1 /= (1 + g * g - 2 * g * cos(theta));
    return Phase0 * Phase1;
}

float ScatteringConstantRayleigh(in float lambda){
    return lambda / 4.0f;
}

float ScatteringConstantMie(in float lambda){
    return 1.0f;
}

const float OpticalDepthSamples = 5.0f;
const float OpticalDepthSampleWeight = 1.0f / OpticalDepthSamples;

float OutScatteringRayleigh(in float lambda, in vec3 start, in vec3 end){
    float value = 0.0f;
    vec3 IntegrationVector = end - start;
    float IntegrationLength = length(IntegrationVector) / OpticalDepthSamples;
    Ray IntegrationRay;
    IntegrationRay.Origin = start;
    IntegrationRay.Direction = normalize(IntegrationVector);
    vec3 IntegrationPosition = IntegrationRay.Origin;
    for(float IntegrationSample = 0; IntegrationSample < OpticalDepthSamples; IntegrationSample++){
        value += exp(IntegrationPosition.y / 8000.0f) * OpticalDepthSampleWeight;
        IntegrationPosition += IntegrationRay.Direction * IntegrationLength;
    }
    return value * 12.5663706144f * ScatteringConstantRayleigh(lambda);
}

float OutScatteringMie(in float lambda, in vec3 start, in vec3 end){
    float value = 0.0f;
    vec3 IntegrationVector = end - start;
    float IntegrationLength = length(IntegrationVector) / OpticalDepthSamples;
    Ray IntegrationRay;
    IntegrationRay.Origin = start;
    IntegrationRay.Direction = normalize(IntegrationVector);
    vec3 IntegrationPosition = IntegrationRay.Origin;
    for(float IntegrationSample = 0; IntegrationSample < OpticalDepthSamples; IntegrationSample++){
        value += exp(IntegrationPosition.y / 1200.0f) * OpticalDepthSampleWeight;
        IntegrationPosition += IntegrationRay.Direction * IntegrationLength;
    }
    return value * 12.5663706144f * ScatteringConstantMie(lambda);
}

const float InScatteringSamples = 5.0f;
const float InScatteringSampleWeight = 1.0f / InScatteringSamples;

float InScatteringRayleigh(in float lambda, in float theta, vec3 view, vec3 SunWorldPos){
    float value = 0.0f;
    vec3 CameraLocation = vec3(0.0f); //Keeping it anyway so the code is more intuitive and simple
    vec3 SunPosition = normalize(sunPosition) * 100000000;
    vec3 IntegrationPosition = CameraLocation;
    for(float Integration = 0.0f; Integration < InScatteringSamples; Integration++){
        value += InScatteringSampleWeight * ( exp(-IntegrationPosition.y / 8000.0f) * exp(-OutScatteringRayleigh(lambda, CameraLocation, IntegrationPosition)-OutScatteringRayleigh(lambda, CameraLocation, IntegrationPosition)));
        IntegrationPosition += view * 100.0f;
    }
    return Phase(theta, 0.0f) * ScatteringConstantRayleigh(lambda) * value;
}


    const float RayleighBrightness = 3.3f;
    const float MieBrightness = 0.1f;
    const float RayleighStrength = 0.139f;
    const float MieStrength = 0.0264f;
    const float SpotBrightness = 500.0f;
    const float SurfaceHeight = 0.98;
    const float ScatterStrength = 0.028;
    const float MieCollectionPower = 0.39;
    const float RayleighCollectionPower = 0.81;
    const float MieFactor = 1.0f;
    const float RayleighFactor = 1.0f;
    const float MieDistribution = -0.76f;
    const int StepCount = 15;
    const vec3 AirColor = vec3(0.18867780436772762, 0.4978442963618773, 0.6616065586417131);

float HenyeyGreensteinPhase(float alpha, float g){
    float a = 3.0*(1.0-g*g);
    float b = 2.0*(2.0+g*g);
    float c = 1.0+alpha*alpha;
    float d = pow(1.0+g*g-2.0*g*alpha, 1.5);
    return (a/b)*(c/d);
}

float AtmosphericDepth(vec3 position, vec3 dir){
    float a = dot(dir, dir);
    float b = 2.0*dot(dir, position);
    float c = dot(position, position)-1.0;
    float det = b*b-4.0*a*c;
    float detSqrt = sqrt(det);
    float q = (-b - detSqrt)/2.0;
    float t1 = c/q;
    return t1;
}

float HorizonExtinction(vec3 position, vec3 dir, float radius){
    float u = dot(dir, -position);
    if(u<0.0){
        return 1.0;
    }
    vec3 near = position + u*dir;
    if(length(near) < radius){
        return 0.0;
    }
    else{
        vec3 v2 = normalize(near)*radius - position;
        float diff = acos(dot(normalize(v2), dir));
        return smoothstep(0.0, 1.0, pow(diff*2.0, 3.0));
    }
}

vec3 AbsorbLight(float dist, vec3 color, float factor){
    return color-color*pow(AirColor, vec3(factor/dist));
}



void main(){
    vec3 NWorldRay = normalize(WorldRay);
    vec4 TransparentColor =  texture2D(gaux2, texcoords);
    vec4 ReflectiveColor = TransparentColor;
    TransparentColor.rgb = mix(TransparentColor.rgb, ReflectiveColor.rgb, step(vec3(0.001f), TransparentColor.rgb));
    vec3 BackgroundColor = texture2D(gcolor, texcoords).rgb;
    vec3 BlendColor = mix(TransparentColor.rgb, BackgroundColor, TransparentColor.a).rgb;
    vec3 GetRealColor = pow(BlendColor, vec3(0.0000001));
    BlendColor = mix(BackgroundColor, BlendColor, GetRealColor);
    /* DRAWBUFFERS:04 */
    gl_FragData[0] = vec4(BlendColor, 1.0f);
    gl_FragData[1] = vec4(AtmosphericScattering(NWorldRay), 0.25f);
}