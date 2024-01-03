#include "util.glsl"

varying vec2 texcoords;

//#define USE_ARRAY_WEIGHTS //Use precomputed array weights
//#define LOGARITHMIC_BLOOM_CURVE
//#define SQUARED_BLOOM_CURVE
//#define AVERAGE_BLOOM
//#define LOD_BLOOM
//#define BLOOM

#define BLOOM_FACTOR 1.0f
#define BLOOM_COORD_MULT 1.0f

#ifdef USE_ARRAY_WEIGHTS
#define BLUR_SIZE 5
#else
#define BLUR_SIZE 51
#endif

#ifndef BLOOM_FACTOR
#define BLOOM_FACTOR 1.0f
#endif

#ifdef USE_ARRAY_WEIGHTS
const float BlurWeights[BLUR_SIZE] = float[](0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216); //Taken from learnopengl.com
#else
const float BlurSpread = 4000.0f;
float GetBlurWeight(in int iteration, in float sigma){
    float x = float(iteration) * //Correct the blur distance, I am using 1080p monitor
    #ifdef HORIZONTAL_BLUR
    1.0f / (viewWidth / 1920.0f);
    #else
    1.0f / (viewHeight / 1080.0f);
    #endif
    //x *= 1024.0f;
    x = pow(2.71828, -(x * x) / 2 * (sigma * sigma));
    x = x / sqrt(2 * 3.14 * sigma);
    return x;// * 0.025f;
}
#endif

const float CurveFactor = 0.56f;
#ifdef LOD_BLOOM
const int LevelOfDetail = 5;
#else
const int LevelOfDetail = 0;
#endif

void main(){
    #ifdef BLOOM
    float CameraDistance = distance(GetFragmentWorldSpace(texcoords), cameraPosition);
    float Sigma;
    #ifdef LOGARITHMIC_BLOOM_CURVE 
    const float LogOffset = 1.0f;
    Sigma = log(CameraDistance + LogOffset) / (log(CameraDistance + LogOffset) + 1);
    Sigma = Sigma * CurveFactor;
    #else
    Sigma = sqrt(CameraDistance) / (sqrt(CameraDistance) + 1.0f);
    Sigma = Sigma * CurveFactor;
    #endif
    #ifdef SQUARED_BLOOM_CURVE
    Sigma = Sigma * Sigma;
    #endif
    Sigma = 0.14f;
    //Sigma = 0.0014f;
    vec3 AccumulatedSamples = texture2D(gaux1, texcoords).rgb * 
    #ifdef USE_ARRAY_WEIGHTS
    BlurWeights[0];
    #else
    GetBlurWeight(0, Sigma);
    #endif
    #ifdef LOD_BLOOM
    vec2 TexelSize = vec2(1.0f / viewWidth, 1.0f / viewHeight) * 15;
    #else
    vec2 TexelSize = vec2(1.0f / viewWidth, 1.0f / viewHeight);
    #endif
    //TexelSize = vec2(1.0f / viewWidth, 1.0f / viewHeight);

    //TexelSize = CreateRandomRotation(texcoords + frameTimeCounter) * TexelSize;
    for(int iteration = 1; iteration < BLUR_SIZE; iteration++){
        vec2 Offset = vec2(0.0f);
        #ifdef HORIZONTAL_BLUR
        Offset.x = TexelSize.x * iteration;
        #else
        Offset.y = TexelSize.y * iteration;
        #endif
        AccumulatedSamples += (texture2DLod(gaux1, texcoords + Offset, LevelOfDetail).rgb + texture2DLod(gaux1, texcoords - Offset, LevelOfDetail).rgb) * 
        #ifdef USE_ARRAY_WEIGHTS
        BlurWeights[iteration];
        #else
        GetBlurWeight(iteration, 0.44); //0.54f
        #endif
    }
    #ifdef AVERAGE_BLOOM
    AccumulatedSamples /= BLUR_SIZE;
    AccumulatedSamples *= 22.2f;
    #endif
    /* DRAWBUFFERS:4 */
    gl_FragData[0] = vec4(AccumulatedSamples, 1.0f);
    #endif
}