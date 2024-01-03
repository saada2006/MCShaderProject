#version 120

#include "lib/util.glsl"

varying vec2 texcoords;
varying vec3 ViewCoords;

const float RayMaxSteps = 2048.0f; //Now I am too lazy to do maths but since we multiply by 1.3 each ray step, we should get thousands of blocks of reflection distance
const float RayMaxRefinements = 16.0f; //16 ray refinements for getting as 65536 times closer
float RayStepDistance = 30.0f; //We start off with 3 blocks, with ray refinements we can get up to 0.00004577636 blocks of accuracy in a best case scenario (how do I speel it)

const float RayBias = 0.0005f; //Because I have no idea how to do accurate reflections

/*
Function that returns camera-space hit coordinates of screen space reflection
ReflectionRay.Origin refers to the camera space position the ray starts at
ReflectionRay.Direction refers to the camera space direction vector of the ray
*/
vec3 ComputeRayTraceReflection(in Ray ReflectionRay) {
    vec3 RayPosition = ReflectionRay.Origin + ReflectionRay.Direction * 1.3f; //Ray starts at the reflections origin
    vec3 RayStepDistance = ReflectionRay.Direction; //Ray step distance
    vec4 RayScreenPos; //Screen position of ray
    for(float RayStep = 0.0f; RayStep < RayMaxSteps; RayStep++){
        RayScreenPos = vec4(RayPosition, 1.0f);
        RayScreenPos = gbufferProjection * RayScreenPos;
        RayScreenPos /= RayScreenPos.w;
        RayScreenPos = RayScreenPos * 0.5f + 0.5f;
        float DepthSample = texture2D(depthtex0, RayScreenPos.st).r;
        float DepthDifference = DepthSample - RayScreenPos.z;
        if(DepthDifference > 0.0f){
            return RayPosition;
        }
        RayPosition += RayStepDistance; //Trace along ray
        RayStepDistance *= 1.3f; //Each step gets bigger
    }
    return vec3(0.0f);
}

/*
Function that returns color of screen space reflection
ReflectionRay.Origin refers to the camera space position the ray starts at
ReflectionRay.Direction refers to the camera space direction vector of the ray
*/

//#define BREAK_ON_SCENE_EXIT
//#define RAY_BIAS
vec3 ScreenSpaceReflection(in Ray ReflectionRay) {
    vec3 RayPosition = ReflectionRay.Origin; //Ray starts at the reflections origin
    vec3 RayStepDistance = ReflectionRay.Direction * 0.1f; //Ray step distance
    vec4 RayScreenPos; //Screen position of ray
    for(float RayStep = 0.0f; RayStep < RayMaxSteps; RayStep++){
        RayScreenPos = vec4(RayPosition, 1.0f);
        RayScreenPos = gbufferProjection * RayScreenPos;
        RayScreenPos /= RayScreenPos.w;
        RayScreenPos = RayScreenPos * 0.5f + 0.5f;
        #ifdef BREAK_ON_SCENE_EXIT
        if(RayScreenPos.s < 0.0f || RayScreenPos.s > 1.0f ||RayScreenPos.t < 0.0f || RayScreenPos.t > 1.0f || RayScreenPos.z < 0.0f || RayScreenPos.z > 1.0f){
            break; //More branching yay 
            //But I saw this in another shaderpack so I copied it anyway
        }
        #endif
        float DepthSample = texture2D(depthtex0, RayScreenPos.st).r;
        float DepthDifference = DepthSample - RayScreenPos.z;
        #ifdef RAY_BIAS
        DepthDifference += RayBias;
        #endif
        if(DepthDifference < 0.0f){
            vec3 RefinementStep = ReflectionRay.Direction;
            for(float Refinement = 0.0f; Refinement < RayMaxRefinements; Refinement++){
                RayScreenPos = vec4(RayPosition, 1.0f);
                RayScreenPos = gbufferProjection * RayScreenPos;
                RayScreenPos /= RayScreenPos.w;
                RayScreenPos = RayScreenPos * 0.5f + 0.5f;
                if(RayScreenPos.s < 0.0f || RayScreenPos.s > 1.0f ||RayScreenPos.t < 0.0f || RayScreenPos.t > 1.0f || RayScreenPos.z < 0.0f || RayScreenPos.z > 1.0f){
                    break; //More branching yay 
                    //But I saw this in another shaderpack so I copied it anyway
                }
                float DepthSampleRefinement = texture2D(depthtex0, RayScreenPos.st).r;
                float DepthDifferenceRefinement = DepthSample - RayScreenPos.z;
                #ifdef RAY_BIAS
                DepthDifference += RayBias;
                #endif
                RefinementStep *= 0.5f;
                vec3 CurrentRefinement = RefinementStep;
                if(DepthDifferenceRefinement < 0.0f){
                    CurrentRefinement = -CurrentRefinement;
                }
                RayPosition += CurrentRefinement;
            }
            return texture2D(gcolor, RayScreenPos.st).rgb;
        }
        RayPosition += RayStepDistance; //Trace along ray
        //RayStepDistance *= 1.03f; //Each step gets bigger
    }
    return AtmosphericScattering(mat3(gbufferModelViewInverse) * ReflectionRay.Direction);
}

void main(){
    Ray ReflectionRay;
                          //mat3(gbufferModelView) * (GetFragmentWorldSpace(texcoords) - cameraPosition);
    ReflectionRay.Origin = (gbufferModelView * vec4(GetFragmentWorldSpace(texcoords) - cameraPosition, 1.0f)).xyz;
    //ReflectionRay.Origin -= gbufferModelView[3].xyz;
    ReflectionRay.Direction = reflect(normalize(ReflectionRay.Origin), normalize(mat3(gbufferModelView) * SampleNormal(texcoords)));
    vec3 ReflectionColor = ScreenSpaceReflection(ReflectionRay);
    vec3 ComputedColor = mix(SampleColor(texcoords), ReflectionColor, SampleDepth(texcoords).g);
    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(ComputedColor, 0.0f);
}