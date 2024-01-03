#ifndef UTIL_FRAG
#define UTIL_FRAG

#extension GL_EXT_gpu_shader4 : enable

const int RGBA = 1;
const int RGBA32F = 1;
const int gcolorFormat = RGBA32F;
const int gdepthFormat = RGBA32F;
const int gnormalFormat = RGBA32F;
const int shadowMapResolution = 4096;
const float sunPathRotation = -40.0f;
const int noiseTextureResolution = 256;
const bool gaux1MipmapEnabled = true;
const bool shadowcolor0Nearest = true;
const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;
const float wetnessHalflife = 70.0f;
const float drynessHalflife = 70.0f;
const float shadowDistance = 128.0f;
const float eyeBrightnessHalflife = 20.0;
const float centerDepthHalflife = 1.0;
//const float actualSeaLevel = SEA_LEVEL - 0.1111111111111111;
const float ambientOcclusionLevel = 0.0f;

#define DYNAMIC_LIGHT

#define GCOLOR_OUT gl_FragData[0]
#define GDEPTH_OUT gl_FragData[1]
#define GNORMAL_OUT gl_FragData[2]
#define GSPECULAR_OUT gl_FragData[3]

uniform sampler2D gcolor;
uniform vec3 cameraPosition;
uniform sampler2D gdepthtex;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform sampler2D shadow;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform float near;
uniform float far;
uniform vec3 fogColor;
uniform float viewHeight;
uniform float viewWidth;
uniform sampler2D noisetex;
uniform sampler2D lightmap;
uniform sampler2D gdepth;
uniform sampler2D gnormal;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int worldTime;
uniform sampler2D texture;
uniform float frameTimeCounter;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelView;
uniform float sunAngle;
uniform float rainStrength;
uniform sampler2D specular;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D gaux4;
uniform int heldItemId;   
uniform int heldItemId2;  
uniform sampler2D shadowcolor;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelViewInverse;
uniform float aspectRatio;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform float centerDepthSmooth;
uniform vec3 skyColor;
uniform float eyeAltitude;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform sampler2D depthtex3;
uniform sampler2D normals;

//#define VIBRANCY_BOOST
//#define BLOOM

#define SHADOW_INVERSE_SIZE 1.0f
//#define SHADOWS

struct LightMap {
	float PointLighting;
	float SkyLighting;
};

struct Fragment {
	vec3 Color;
	vec3 Normal;
	vec4 Depth;
	vec2 TexCoord;
	float DiffuseEmission;
	LightMap LightData;
};

bool IsHalfPlant(in float block){
	return (block == 31.0f || block == 51.0f); //Of course fire is a "plant"

    //return true; //for now //and not now
}

bool IsFullPlant(in float block){
	return (block == 18.0f);
}

bool ShouldPlantTransform(in float block, in float texcoord, in float half){
	if(IsHalfPlant(block) && texcoord < half){
		return true;
	}
	else if(IsFullPlant(block)){
		return true;
	}
	return false;
}

const float LightmapPackingFactor = 32.0f;

int EncodeLightmap(in vec2 lmcoords){
	int Compressed = 0;
	int PointLighting = int(lmcoords.s * LightmapPackingFactor);
	int SkyLighting = int(lmcoords.t * LightmapPackingFactor);
	int Copy;
	Compressed = Compressed | SkyLighting;
	Compressed = Compressed >> 16;
	Copy = Compressed;
	Compressed = 0;
	Compressed = Compressed | PointLighting;
	Compressed = Compressed | Copy;
	return Compressed;
}

float ConvertIntFloatBinary(in int data){
	return float(data);
}

int ConvertFloatIntBinary(in float data){
	return int(data);
}

vec2 DecodeLightmap(in int lighting){
	return vec2(
		float((lighting >> 16) << 16) / LightmapPackingFactor,
		float(lighting << 16) / LightmapPackingFactor
	);
}

const float PosStrength = 1.0f;
const float WaveStrength = 2.0f; //Frequncy
const float Amplitude = 0.14f;
const float WaveTimeFactor = 2.0f;

float PlantDisplacement(in float pos){
	float SineWave = 0.0f;
	SineWave += pos * PosStrength;
	SineWave += WaveStrength * frameTimeCounter;
	return sin(SineWave) * Amplitude;
}

vec3 PlantTransform(in vec3 plant){
	vec3 Offset = vec3(0.0f);
    Offset.x = PlantDisplacement(plant.x);
	//Offset.y = PlantDisplacement(plant.y);
    Offset.z = PlantDisplacement(plant.z);
	Offset *= sin(2 * frameTimeCounter) + sin(3.1415 * frameTimeCounter) * 0.5f;
	plant.xyz += Offset;
	return plant;
}

const float GetShadowLOD(const int shadowRes){
	switch(shadowRes){
		case 4096:
			return 1.0f;
		case 2048:
			return 1.7f;
		case 1024:
			return 2.2f;
		case 512:
			return 3.2f;
		case 256:
			return 7.879f;
		default:
			return 0.0f; //or 1.0f? someone pls tell me
	}
}

//Taken from SEUS PTGI E7:
float PackTwo4BitTo8Bit(float a, float b)
{
	float data;

	a = clamp(a, 0.0, 15.0 / 16.0);
	b = clamp(b, 0.0, 15.0 / 16.0);

	a *= 15.0;
	b *= 15.0;

	a = floor(a);
	b = floor(b);

	data = a * exp2(4.0);
	data += b;

	data /= exp2(8.0) - 1;

	return data;
}

vec2 UnpackTwo4BitFrom8Bit(float value)
{
	vec2 data;

	value *= exp2(8.0) - 1;

	data.x = floor(value / exp2(4.0));
	data.y = mod(value, exp2(4.0));

	data.x /= 15.0;
	data.y /= 15.0;

	return data;
}







float PackTwo8BitTo16Bit(float a, float b)
{
	float data;

	a = clamp(a, 0.0, 255.0 / 256.0);
	b = clamp(b, 0.0, 255.0 / 256.0);

	a *= 255.0;
	b *= 255.0;
	
	a = floor(a);
	b = floor(b);

	data = a * exp2(8.0);
	data += b;



	data /= exp2(16.0) - 1;

	return data;

	// vec2 d = vec2(a, b);
	// d = clamp(d, vec2(0.0), vec2(255.0 / 256.0));
	// d *= 256.0;

	// float data = dot(d, vec2(1.0 / exp2(8.0), 1.0 / exp2(16.0)));

	// return data;
}

vec2 UnpackTwo8BitFrom16Bit(float value)
{
	vec2 data;

	value *= exp2(16.0) - 1;

	data.x = floor(value / exp2(8.0));
	data.y = mod(value, exp2(8.0));

	data.x /= 255.0;
	data.y /= 255.0;

	return data;
}




// float PackTwo16BitTo32Bit(float a, float b)
// {
// 	a = clamp(a, 0.0, 1.0);
// 	b = clamp(b, 0.0, 1.0);

// 	a *= 65536.0;
// 	b *= 65536.0;

// 	int ai = int(a);
// 	int bi = int(b);

// 	int data = ai << 16;
// 	data += bi & 0x0000FFFF;

// 	float dataf = float(data) / 0xFFFFFFFF;

// 	return dataf;
// }

// vec2 UnpackTwo16BitFrom32Bit(float value)
// {
// 	int data = int(value * 0xFFFFFFFF);

// 	int ai = data >> 16;
// 	int bi = data & 0x0000FFFF;

// 	float a = float(ai) / 65536.0;
// 	float b = float(bi) / 65536.0;

// 	return vec2(a, b);
// }

#if 0

float PackTwo16BitTo32Bit(float a, float b)
{
	float data;

	a = clamp(a, 0.0, 255.0 / 256.0);
	b = clamp(b, 0.0, 255.0 / 256.0);

	a *= 65535.0;
	b *= 65535.0;

	a = floor(a);
	b = floor(b);

	data = a * exp2(16.0);
	data += b;

	data /= exp2(32.0) - 1;

	return data;


	// float data;

	// a = clamp(a, 0.01, 2047.0 / 2048.0);
	// b = clamp(b, 0.01, 2047.0 / 2048.0);

	// a *= 2047.0;
	// b *= 2047.0;

	// a = floor(a);
	// b = floor(b);

	// data = a * exp2(11.0);
	// data += b;

	// data /= exp2(22.0) - 1;
	// data += 1.0;

	// return data;
}

vec2 UnpackTwo16BitFrom32Bit(float value)
{
	vec2 data;

	value *= exp2(32.0) - 1;

	data.x = floor(value / exp2(16.0));
	data.y = mod(value, exp2(16.0));

	data.x /= 65535.0;
	data.y /= 65535.0;

	return data;


	// vec2 data;

	// value -= 1.0;
	// value *= exp2(22.0) - 1;

	// data.x = floor(value / exp2(11.0));
	// data.y = mod(value, exp2(11.0));

	// data.x /= 2047.0;
	// data.y /= 2047.0;

	// return data;
}


#else


float PackTwo16BitTo32Bit(float a, float b) {
	vec2 v = vec2(a, b);
	// v = clamp(v, vec2(0.0), vec2(1.0));
    return dot(floor(v*8191.9999),vec2(1./8192.,1.));
}
vec2 UnpackTwo16BitFrom32Bit(float v) {
    return vec2(fract(v)*(8192./8191.),floor(v)/8191.);
}

#endif


vec4 PackFloatRGBA(float v)
{
	vec4 enc = vec4(1.0, 255.0, 65025.0, 16581375.0) * v;
	enc = fract(enc);
	enc -= enc.yzww * vec4(1.0 / 255.0, 1.0 / 255.0, 1.0 / 255.0, 0.0);
	return enc;
}

float UnpackFloatRGBA(vec4 rgba)
{
	return dot(rgba, vec4(1.0, 1.0 / 255.0, 1.0 / 65025.0, 1.0 / 16581375.0));
}

#define SHADOW_DISTORT_FACTOR 0.10f
const float ShadowLOD = 1.0f;//2.2f;

float CubeLength(in vec2 vector){
    return pow(abs(vector.x * vector.x * vector.x) + abs(vector.y * vector.y * vector.y), 1.0f / 3.0f);
}

float DistortionFactor(in vec2 position) {
	return CubeLength(position) + SHADOW_DISTORT_FACTOR;
}

vec3 DistortShadowPos(in vec3 ShadowPos, in float distortion){
    return vec3(ShadowPos.xy / distortion, ShadowPos.z * 0.5f);
}

//#define SHADOW_DISTORTION

vec3 DistortShadow(vec3 pos){
	#ifdef SHADOW_DISTORTION
    return DistortShadowPos(pos, DistortionFactor(pos.xy));
	#else
	return pos;
	#endif
}

//#define CEL_SHADING
const float CelShadingLayers = 1.0f;
const float CelShadingAccuracy = 4.0f; //Real layers = CelShadingAccuracy / 2

//#define BRIGHTNESS_ADJUSTEMENT

vec2 ConvertLighting(in vec2 lighting){
	vec2 NewLighting = lighting;
	//NewLighting = NewLighting * NewLighting;
	//NewLighting *= 0.707;
	//NewLighting = sqrt(NewLighting);
	//NewLighting.x = pow(NewLighting.x, 3.4f);
	//Code taken from Continuum shaders
	//Apply inverse square law and normalize for natural light falloff
	float lightmap = NewLighting.r;
	lightmap 		= clamp(lightmap * 1.10f, 0.0f, 1.0f);
	lightmap 		= 1.0f - lightmap;
	lightmap 		*= 5.6f;
	lightmap 		= 1.0f / pow((lightmap + 0.8f), 2.0f);
	lightmap 		-= 0.02435f;

	// if (lightmap <= 0.0f)
		// lightmap = 1.0f;

	lightmap 		= max(0.0f, lightmap);
	lightmap 		*= 0.008f;
	lightmap 		= clamp(lightmap, 0.0f, 1.0f);
	lightmap 		= pow(lightmap, 0.9f);
	NewLighting.r = lightmap;
	NewLighting.r = pow(lighting.r, 8.0f) * 8;
	NewLighting.r = NewLighting.r / ( NewLighting.r + 1.0f);
	#ifdef BRIGHTNESS_ADJUSTEMENT
	NewLighting.r = pow(NewLighting.r, 1.675f);
	NewLighting.r *= 18.0f;
	#endif
	#ifdef CEL_SHADING
	NewLighting.r = float(int(NewLighting.r * CelShadingLayers * CelShadingAccuracy))  / (CelShadingLayers * CelShadingAccuracy);
	#endif
	return NewLighting;
}

vec3 SampleColor(in vec2 texcoord){
	return texture2D(gcolor, texcoord).rgb;
}

vec3 SampleNormal(in vec2 texcoord){
	return texture2D(gnormal, texcoord).rgb;
}

vec4 SampleDepth(in vec2 texcoord){
	return texture2D(gdepth, texcoord);
}

Fragment GetFragment(in vec2 texcoord){
	Fragment fragment;
	fragment.Color = SampleColor(texcoord);
	fragment.Normal = SampleNormal(texcoord);
	fragment.Depth = SampleDepth(texcoord);
	fragment.TexCoord = texcoord;
	vec2 Lighting = ConvertLighting(UnpackTwo16BitFrom32Bit(fragment.Depth.r));
	fragment.LightData.PointLighting = Lighting.r;
	fragment.LightData.SkyLighting = Lighting.g;
	fragment.DiffuseEmission = texture2D(gnormal, texcoord).a;
	return fragment;
}

vec3 GetFragmentWorldSpace(in vec2 texcoord){
	float DepthSample = texture2D(gdepthtex, texcoord).r ;
	vec4 WorldPos = vec4(texcoord.s * 2.0f - 1.0f, texcoord.t * 2.0f - 1.0f, DepthSample * 2.0f - 1.0f, 1.0f);
	WorldPos = gbufferProjectionInverse * WorldPos;
	WorldPos /= WorldPos.w;
	WorldPos = gbufferModelViewInverse * WorldPos;
	return WorldPos.xyz + cameraPosition;
}

vec3 GetFragmentShadowSpace(in vec2 texcoord){
	vec4 ShadowPos = shadowModelView * vec4(GetFragmentWorldSpace(texcoord) - cameraPosition, 1.0f);
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
	return ShadowPos.xyz;
}

mat2 CreateRandomRotation(in vec2 texcoord){
	float Rotation = texture2D(noisetex, texcoord * vec2(viewWidth / noiseTextureResolution, viewHeight / noiseTextureResolution)).r;
	return mat2(cos(Rotation), -sin(Rotation), sin(Rotation), cos(Rotation));
}

vec3 CalculateSunColor(){
    vec4 SunDirection = gbufferModelViewInverse * vec4(sunPosition, 1.0f);
    vec3 SunVector = normalize(SunDirection.xyz);
    vec3 HorizonVector = SunVector;
    HorizonVector.y = 0.0f;
    HorizonVector = normalize(HorizonVector);
    float SunHeight = 1.0f - clamp(dot(HorizonVector, SunVector) - 0.2f, 0.0f, 1.0f);
    vec3 Color = vec3(5.0f, 20.0f, 40.0f);
    vec3 ColorMult;
    ColorMult.r = SunHeight * 0.7f;
    ColorMult.g = SunHeight * 0.1f;
    ColorMult.b = SunHeight * 0.05f;
    vec3 SunColor = (Color * ColorMult);
    return clamp(SunColor + 0.1f, vec3(0.0f), vec3(1.0f));
}

vec3 CalculateMoonColor(){
	return vec3(0.75f, 0.85f, 1.0f);
}

float CalculateEmission(in float id){
    if (id == 10.0f || id == 11.0f || id == 50.0f || id == 89.0f || id == 124.0f) {
        return 1.0f;
    }
    if(id == 51.0f){
        return 1.0f;
    }
    return 0.0f;
}

//Taken from KUDA v6.5.56
/*
vec3 drawStars(vec3 clr, vec3 fragpos) {

	#ifdef stars

		const float starsScale = 0.05;
		const float starsMovementSpeed = 0.001;

		vec4 worldPos = gbufferModelViewInverse * vec4(fragpos.xyz, 1.0);

		float position = dot(normalize(fragpos.xyz), upPosition);
		float horizonPos = max(1.0 - pow(abs(position) * 0.013, 1.0), 0.0);

		vec2 coord = (worldPos.xz / (worldPos.y / pow(position, 0.75)) * starsScale) + vec2(frameTimeCounter * starsMovementSpeed);

		float noise  = texture2D(noisetex, coord).x;
					noise += texture2D(noisetex, coord * 2.0).x / 2.0;
					noise += texture2D(noisetex, coord * 6.0).x / 6.0;

		noise = max(noise - 1.4, 0.0);
		noise = mix(noise, 0.0, clamp(getWorldHorizonPos(fragpos) + horizonPos, 0.0, 1.0));

		clr = mix(clr, vec3(2.5), noise * TimeMidnight * (1.0 - weatherRatio));

	#endif

	return clr;

}
*/

const float MipmapFactor = 10000000.0f;

//#define PERLIN_CLOUD_NOISE

const float CloudHeight = 256.0f;
#ifdef PERLIN_CLOUD_NOISE
const float CloudDensity = 0.5f;
#else
const float CloudDensity = 10000.0f;
#endif
const float CloudDistance = 10000.0f;
const float InverseCloudDesnity = 1.0f / CloudDensity;
const float CloudSpeed = 100.0f;
const float CloudVisualDensity = 1.0f; //Actually its sort of inverse
const float CloudSampleQuality = 1.0f;
const float CloudThickness = 42.0f;
const vec3 CloudDiffuse = vec3(193.0f / 255.0f, 190.0f / 255.0f, 186.0f / 255.0f);
const float CloudFactor = 0.9f;

struct Ray{
    vec3 Origin;
    vec3 Direction;
};

struct Plane {
    vec3 Position;
    vec3 Normal;
};


//Copied from https://www.scratchapixel.com/lessons/3d-basic-rendering/minimal-ray-tracer-rendering-simple-shapes/ray-plane-and-ray-disk-intersection#:~:text=A%20disk%20is%20generally%20defined,the%20ray%2Dplane%20intersection%20test.
float RayPlaneIntersection(in Ray ray, in Plane plane){
    float div = dot(ray.Direction, plane.Normal);
    //TODO:
    //We wont be checking if it is negative via if because branching is slow
    //However, we have step, I might use that
    float num = dot(plane.Position - ray.Origin, plane.Normal);
    return num / div;
}

float RayPlaneIntersectionNegative(in Ray ray, in Plane plane, out float negative){
    float div = dot(ray.Direction, plane.Normal);
	negative = step(0.0f, div); 
    //TODO:
    //We wont be checking if it is negative via if because branching is slow
    //However, we have step, I might use that
    float num = dot(plane.Position - ray.Origin, plane.Normal);
    return num / div;
}

//Taken from https://gist.github.com/patriciogonzalezvivo/670c22f3966e662d2f83
//However I do need to replace this with a more effiecnet algorithm

#define PI 3.1415

float rand(vec2 c){
	return fract(sin(dot(c.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

float noise(vec2 p, float freq ){
	float unit = viewWidth/freq;
	vec2 ij = floor(p/unit);
	vec2 xy = mod(p,unit)/unit;
	//xy = 3.*xy*xy-2.*xy*xy*xy;
	xy = .5*(1.-cos(PI*xy));
	float a = rand((ij+vec2(0.,0.)));
	float b = rand((ij+vec2(1.,0.)));
	float c = rand((ij+vec2(0.,1.)));
	float d = rand((ij+vec2(1.,1.)));
	float x1 = mix(a, b, xy.x);
	float x2 = mix(c, d, xy.x);
	return mix(x1, x2, xy.y);
}

float pNoise(vec2 p, int res){
	float persistance = .5;
	float n = 0.;
	float normK = 0.;
	float f = 4.;
	float amp = 1.;
	int iCount = 0;
	for (int i = 0; i<50; i++){
		n+=amp*noise(p, f);
		f*=2.;
		normK+=amp;
		amp*=persistance;
		if (iCount == res) break;
		iCount++;
	}
	float nf = n/normK;
	return nf*nf*nf*nf;
}
//Taken from https://gist.github.com/patriciogonzalezvivo/670c22f3966e662d2f83
//	Classic Perlin 3D Noise 
//	by Stefan Gustavson
//
vec4 permute(vec4 x){return mod(((x*34.0)+1.0)*x, 289.0);}
vec4 taylorInvSqrt(vec4 r){return 1.79284291400159 - 0.85373472095314 * r;}
vec3 fade(vec3 t) {return t*t*t*(t*(t*6.0-15.0)+10.0);}

float cnoise(vec3 P){
  vec3 Pi0 = floor(P); // Integer part for indexing
  vec3 Pi1 = Pi0 + vec3(1.0); // Integer part + 1
  Pi0 = mod(Pi0, 289.0);
  Pi1 = mod(Pi1, 289.0);
  vec3 Pf0 = fract(P); // Fractional part for interpolation
  vec3 Pf1 = Pf0 - vec3(1.0); // Fractional part - 1.0
  vec4 ix = vec4(Pi0.x, Pi1.x, Pi0.x, Pi1.x);
  vec4 iy = vec4(Pi0.yy, Pi1.yy);
  vec4 iz0 = Pi0.zzzz;
  vec4 iz1 = Pi1.zzzz;

  vec4 ixy = permute(permute(ix) + iy);
  vec4 ixy0 = permute(ixy + iz0);
  vec4 ixy1 = permute(ixy + iz1);

  vec4 gx0 = ixy0 / 7.0;
  vec4 gy0 = fract(floor(gx0) / 7.0) - 0.5;
  gx0 = fract(gx0);
  vec4 gz0 = vec4(0.5) - abs(gx0) - abs(gy0);
  vec4 sz0 = step(gz0, vec4(0.0));
  gx0 -= sz0 * (step(0.0, gx0) - 0.5);
  gy0 -= sz0 * (step(0.0, gy0) - 0.5);

  vec4 gx1 = ixy1 / 7.0;
  vec4 gy1 = fract(floor(gx1) / 7.0) - 0.5;
  gx1 = fract(gx1);
  vec4 gz1 = vec4(0.5) - abs(gx1) - abs(gy1);
  vec4 sz1 = step(gz1, vec4(0.0));
  gx1 -= sz1 * (step(0.0, gx1) - 0.5);
  gy1 -= sz1 * (step(0.0, gy1) - 0.5);

  vec3 g000 = vec3(gx0.x,gy0.x,gz0.x);
  vec3 g100 = vec3(gx0.y,gy0.y,gz0.y);
  vec3 g010 = vec3(gx0.z,gy0.z,gz0.z);
  vec3 g110 = vec3(gx0.w,gy0.w,gz0.w);
  vec3 g001 = vec3(gx1.x,gy1.x,gz1.x);
  vec3 g101 = vec3(gx1.y,gy1.y,gz1.y);
  vec3 g011 = vec3(gx1.z,gy1.z,gz1.z);
  vec3 g111 = vec3(gx1.w,gy1.w,gz1.w);

  vec4 norm0 = taylorInvSqrt(vec4(dot(g000, g000), dot(g010, g010), dot(g100, g100), dot(g110, g110)));
  g000 *= norm0.x;
  g010 *= norm0.y;
  g100 *= norm0.z;
  g110 *= norm0.w;
  vec4 norm1 = taylorInvSqrt(vec4(dot(g001, g001), dot(g011, g011), dot(g101, g101), dot(g111, g111)));
  g001 *= norm1.x;
  g011 *= norm1.y;
  g101 *= norm1.z;
  g111 *= norm1.w;

  float n000 = dot(g000, Pf0);
  float n100 = dot(g100, vec3(Pf1.x, Pf0.yz));
  float n010 = dot(g010, vec3(Pf0.x, Pf1.y, Pf0.z));
  float n110 = dot(g110, vec3(Pf1.xy, Pf0.z));
  float n001 = dot(g001, vec3(Pf0.xy, Pf1.z));
  float n101 = dot(g101, vec3(Pf1.x, Pf0.y, Pf1.z));
  float n011 = dot(g011, vec3(Pf0.x, Pf1.yz));
  float n111 = dot(g111, Pf1);

  vec3 fade_xyz = fade(Pf0);
  vec4 n_z = mix(vec4(n000, n100, n010, n110), vec4(n001, n101, n011, n111), fade_xyz.z);
  vec2 n_yz = mix(n_z.xy, n_z.zw, fade_xyz.y);
  float n_xyz = mix(n_yz.x, n_yz.y, fade_xyz.x); 
  return 2.2 * n_xyz;
}

//Taken from Continuum Shaders
float Get3DNoise(in vec3 pos)
{
	pos.z += 0.0f;
	vec3 p = floor(pos);
	vec3 f = fract(pos);
	//f = f * f * (3.0f - 2.0f * f);

	vec2 uv =  (p.xy + p.z * vec2(17.0f)) + f.xy;
	vec2 uv2 = (p.xy + (p.z + 1.0f) * vec2(17.0f)) + f.xy;
	vec2 coord =  (uv  + 0.5f) / noiseTextureResolution;
	vec2 coord2 = (uv2 + 0.5f) / noiseTextureResolution;
	float xy1 = texture2D(noisetex, coord).x;
	float xy2 = texture2D(noisetex, coord2).x;
	return mix(xy1, xy2, f.z);
}

// Simplex 2D noise
//
vec3 permute(vec3 x) { return mod(((x*34.0)+1.0)*x, 289.0); }

float snoise(vec2 v){
  const vec4 C = vec4(0.211324865405187, 0.366025403784439,
           -0.577350269189626, 0.024390243902439);
  vec2 i  = floor(v + dot(v, C.yy) );
  vec2 x0 = v -   i + dot(i, C.xx);
  vec2 i1;
  i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
  vec4 x12 = x0.xyxy + C.xxzz;
  x12.xy -= i1;
  i = mod(i, 289.0);
  vec3 p = permute( permute( i.y + vec3(0.0, i1.y, 1.0 ))
  + i.x + vec3(0.0, i1.x, 1.0 ));
  vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy),
    dot(x12.zw,x12.zw)), 0.0);
  m = m*m ;
  m = m*m ;
  vec3 x = 2.0 * fract(p * C.www) - 1.0;
  vec3 h = abs(x) - 0.5;
  vec3 ox = floor(x + 0.5);
  vec3 a0 = x - ox;
  m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );
  vec3 g;
  g.x  = a0.x  * x0.x  + h.x  * x0.y;
  g.yz = a0.yz * x12.xz + h.yz * x12.yw;
  return 130.0 * dot(m, g);
}

const float SunSpotSize = 0.997f;
#define MoonSpotSize SunSpotSize



vec3 CalculateSpot(in vec3 eyePos, in vec3 ray, in float size){
    /*vec3 SpotWorldRay = normalize((gbufferModelViewInverse * vec4(eyePos, 1.0f)).xyz);
    vec3 Spot = vec3(1.0f) * clamp(max(dot(SpotWorldRay, ray), 0.0f) - size, 0.0f, 1.0f - size) / size;
    Spot = clamp(pow(Spot, vec3(0.1f)), vec3(0.0f), vec3(1.0f));
    return Spot;*/
	vec3 SpotWorldRay = normalize((gbufferModelViewInverse * vec4(eyePos, 1.0f)).xyz);
	return vec3(step(size, dot(SpotWorldRay, ray)));
}

float Rayleigh(in float lambda, vec3 eyeray){ //Fill in this function later
	//Use that EA paper on realistic skies
    float ParticleDistance = 1000.0f;
    return 0.0f;//float 
}

const int NoiseResolution = 10000;

vec3 QuickBlend(in vec3 color0, in vec3 color1){
    vec3 QuickBlendMagic = clamp(pow(color0, vec3(0.1f)), vec3(0.0f), vec3(1.0f));
    return mix(color1, color0, QuickBlendMagic);
}

vec4 QuickBlend4(in vec4 color0, in vec4 color1){
    vec4 QuickBlendMagic = clamp(pow(color0, vec4(0.1f)), vec4(0.0f), vec4(1.0f));
    return mix(color1, color0, QuickBlendMagic);
}

const float CloudMaxRaySteps = 100;
const float CloudRayStep = 10.0f / CloudMaxRaySteps;

float CloudCoverage(in Ray SkyIntersectionRay){
	float Coverage = 0.0f;
	for(int StepCount = 0; StepCount < CloudMaxRaySteps; StepCount++) {
		Coverage += Get3DNoise(SkyIntersectionRay.Origin + SkyIntersectionRay.Direction * CloudRayStep * StepCount);
	}
	Coverage /= CloudMaxRaySteps;
	Coverage *= 0.1f;
	return Coverage;
}

vec3 DrawSky(in vec3 NWorldRay, in float CloudMaxDist){
    vec3 SunSpot = CalculateSpot(sunPosition, NWorldRay, SunSpotSize) * CalculateSunColor();
    vec3 MoonSpot = CalculateSpot(moonPosition, NWorldRay, MoonSpotSize) * CalculateMoonColor();
    vec3 LightColor = SunSpot + MoonSpot;
    vec4 CloudColor = vec4(0.0f);
    #if 0
    #ifndef BLOOM
    SkyColor *= 2.0f;
    #endif
    SkyColor = vec3(
        Rayleigh(700.0f / 1000000000.0f, NWorldRay),
        Rayleigh(550.0f / 1000000000.0f, NWorldRay),
        Rayleigh(400.0f / 1000000000.0f, NWorldRay)
    );
    #endif
    vec3 SkyColor = pow(skyColor, vec3(1.6f)); //Use optifine's uniform for now
    vec3 HorizonRay = NWorldRay;
    HorizonRay.y = 0.0f;
    HorizonRay = normalize(HorizonRay);
    Ray SkyRay;
    SkyRay.Direction = NWorldRay;
    SkyRay.Origin = cameraPosition;
    Plane SkyPlane;
    SkyPlane.Normal = vec3(0.0f, 1.0f, 0.0f);
    SkyPlane.Position = vec3(cameraPosition.x, CloudHeight, cameraPosition.z);
    float HorizonSky;
    float RayLength = RayPlaneIntersectionNegative(SkyRay, SkyPlane, HorizonSky);
    vec3 IntersectionPoint = SkyRay.Origin + SkyRay.Direction * RayLength;
    vec2 SkyCoords = IntersectionPoint.xz;
    vec2 SampleCoords = CloudSpeed * frameTimeCounter + SkyCoords * InverseCloudDesnity;
	SampleCoords /= 1000.0f;
	Ray SkyIntersection;
	SkyIntersection.Origin.y = IntersectionPoint.y;
	SkyIntersection.Origin.xz = SampleCoords;
	SkyIntersection.Direction = SkyRay.Direction;
    float CloudNoise = CloudCoverage(SkyIntersection); //Currently disabled until I can fix it
	#if 0
    #ifdef PERLIN_CLOUD_NOISE
    pNoise(SampleCoords, NoiseResolution);
    #else
    texture2D(noisetex, SampleCoords).r;
    #endif
	#endif
    //CloudNoise = pow(CloudNoise, CloudVisualDensity) * CloudFactor;
    CloudColor = vec4(CloudDiffuse * (1.0f - CloudNoise), CloudNoise);
    //CloudColor *= step(length(SkyCoords), CloudMaxDist) * HorizonSky;
    CloudColor.rgb *= 100000;
    CloudColor.rgb = CloudColor.rgb / (CloudColor.rgb + 1.0f);
    CloudColor.rgb *= HorizonSky;
    CloudColor.rgb = mix( SkyColor,CloudColor.rgb, HorizonSky);
   // vec4 CloudLightColor = CloudColor.rgba * CloudNoise + vec4(LightColor, 1.0f - (length(pow(LightColor, vec3(0.0001f))) / length(vec3(1.0f)))) * max(1.0f - CloudNoise * CloudThickness, 0.0f);
    //vec3 FinalSkyColor = mix(SkyColor, CloudLightColor.rgb, 1.0f - CloudLightColor.a);
    //vec3 FinalSkyColor = QuickBlend(LightColor, SkyColor);
    vec3 QuickBlendMagic = clamp(pow(LightColor, vec3(0.1f)), vec3(0.0f), vec3(1.0f));
    float ModifiedQuickBlendMagic = length(QuickBlendMagic) / length(vec3(1.0f));
    vec4 SkyData = mix(vec4(SkyColor, 0.15f), vec4(LightColor, 0.7f), ModifiedQuickBlendMagic);
    vec3 FinalSkyColor = CloudColor.rgb * CloudNoise * HorizonSky + SkyData.rgb * max(1.0f - (CloudNoise * CloudThickness * SkyData.a), 0.0f);
    return vec3(FinalSkyColor);
}

//Taken from https://github.com/CesiumGS/cesium/blob/master/Source/Shaders/Builtin/Functions/saturation.glsl
vec3 saturation(vec3 rgb, float adjustment)
{
    // Algorithm from Chapter 16 of OpenGL Shading Language
    const vec3 W = vec3(0.2125, 0.7154, 0.0721);
    vec3 intensity = vec3(dot(rgb, W));
    return mix(intensity, rgb, adjustment);
}

#define RAYLEIGH_BRIGHTNESS			3.3
#define MIE_BRIGHTNESS 				0.1
#define MIE_DISTRIBUTION 			0.63
#define STEP_COUNT 					15.0
#define SCATTER_STRENGTH			0.048
#define RAYLEIGH_STRENGTH			0.139
#define MIE_STRENGTH				0.0264
#define RAYLEIGH_COLLECTION_POWER	0.81
#define MIE_COLLECTION_POWER		0.39

#define SUNSPOT_BRIGHTNESS			500
#define MOONSPOT_BRIGHTNESS			25

#define SKY_SATURATION				1.5

#define SURFACE_HEIGHT				0.98

const float AtmosphereHeight = 256.0f;
const float SurfaceHeightIncrease = 0.02f;

vec4 viewspace_to_worldspace(in vec4 position_viewspace) {
	vec4 pos = gbufferModelViewInverse * position_viewspace;
	return pos;
}

vec3 get_eye_vector(in vec2 coord) {
	const vec2 coord_to_long_lat = vec2(2.0 * PI, PI);
	coord.y -= 0.5;
	vec2 long_lat = coord * coord_to_long_lat;
	float longitude = long_lat.x;
	float latitude = long_lat.y - (2.0 * PI);

	float cos_lat = cos(latitude);
	float cos_long = cos(longitude);
	float sin_lat = sin(latitude);
	float sin_long = sin(longitude);

	return normalize(vec3(cos_lat * cos_long, cos_lat * sin_long, sin_lat));
}

float atmospheric_depth(vec3 position, vec3 dir) {
	float a = dot(dir, dir);
    float b = 2.0 * dot(dir, position);
    float c = dot(position, position) - 1.0;
    float det = b * b - 4.0 * a * c;
    float detSqrt = sqrt(det);
    float q = (-b - detSqrt) / 2.0;
    float t1 = c / q;
    return t1;
}

float horizon_extinction(vec3 position, vec3 dir, float radius) {
	float u = dot(dir, -position);
    if(u < 0.0) {
        return 1.0;
    }

    vec3 near = position + u*dir;

    if(sqrt(dot(near, near)) < radius) {
        return 0.0;

    } else {
        vec3 v2 = normalize(near)*radius - position;
        float diff = acos(dot(normalize(v2), dir));
        return smoothstep(0.0, 1.0, pow(diff * 2.0, 3.0));
    }
}

float phase(float alpha, float g) {
	float a = 3.0 * (1.0 - g * g);
	float b = 2.0 * (2.0 + g * g);
    float c = 1.0 + alpha * alpha;
    float d = pow(1.0 + g * g - 2.0 * g * alpha, 1.5);
    return (a / b) * (c / d);
}


vec3 Kr = vec3(0.18867780436772762, 0.4978442963618773, 0.6616065586417131);	// Color of nitrogen

vec3 absorb(float dist, vec3 color, float factor) {
	return color - color * pow(Kr, vec3(factor / dist));
}

float rand2(vec2 c){
    return fract(sin(dot(c.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

//#define SKY_HEIGHT

vec3 get_sky_color(in vec3 eye_vector, in vec3 light_vector, in float light_intensity) {
	vec3 light_vector_worldspace = normalize(viewspace_to_worldspace(vec4(light_vector, 0.0)).xyz);

	float alpha = max(dot(eye_vector, light_vector_worldspace), 0.0);

	float rayleigh_factor = phase(alpha, -0.01) * RAYLEIGH_BRIGHTNESS;
	float mie_factor = phase(alpha, MIE_DISTRIBUTION) * MIE_BRIGHTNESS;
	float spot = smoothstep(0.0, 15.0, phase(alpha, 0.9995)) * light_intensity;

	#ifdef SKY_HEIGHT
	float HeightIncrease = (cameraPosition.y / AtmosphereHeight) * SurfaceHeightIncrease;
	HeightIncrease = min(HeightIncrease, 0.019f);
	#endif
	float EyeHeight = SURFACE_HEIGHT;
	#ifdef SKY_HEIGHT
	EyeHeight += HeightIncrease;
	#endif
	vec3 eye_position = vec3(0.0, EyeHeight, 0.0);
	float eye_depth = atmospheric_depth(eye_position, eye_vector);
	float step_length = eye_depth / STEP_COUNT;
	float SurfaceHeight = SURFACE_HEIGHT - 0.15;
	#ifdef SKY_HEIGHT
	SurfaceHeight += HeightIncrease;
	#endif
	float eye_extinction = horizon_extinction(eye_position, eye_vector, SurfaceHeight);
	

	vec3 rayleigh_collected = vec3(0);
	vec3 mie_collected = vec3(0);

	for(int i = 0; i < STEP_COUNT; i++) {
		float sample_distance = step_length * float(i);
		vec3 position = eye_position + eye_vector * sample_distance;
		float ExtinctionHeight = SURFACE_HEIGHT - 0.35;
		#ifdef SKY_HEIGHT
		ExtinctionHeight += HeightIncrease;
		#endif
		float extinction = horizon_extinction(position, light_vector_worldspace, ExtinctionHeight);
		float sample_depth = atmospheric_depth(position, light_vector_worldspace);

		vec3 influx = absorb(sample_depth, vec3(light_intensity), SCATTER_STRENGTH) * extinction;

		// rayleigh will make the nice blue band around the bottom of the sky
		rayleigh_collected += absorb(sample_distance, Kr * influx, RAYLEIGH_STRENGTH);
		mie_collected += absorb(sample_distance, influx, MIE_STRENGTH);
	}

	rayleigh_collected = (rayleigh_collected * eye_extinction * pow(eye_depth, RAYLEIGH_COLLECTION_POWER)) / STEP_COUNT;
	mie_collected = (mie_collected * eye_extinction * pow(eye_depth, MIE_COLLECTION_POWER)) / STEP_COUNT;

	vec3 color = (spot * mie_collected) + (mie_factor * mie_collected) + (rayleigh_factor * rayleigh_collected);

	return color * 7;
}

float luma(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

vec3 enhance(in vec3 color) {
	color *= vec3(0.85, 0.7, 1.2);

    vec3 intensity = vec3(luma(color));

    return mix(intensity, color, SKY_SATURATION);
}

const float AccuracyIncrease = 1024.0f;
//#define MOON_SCATTERING

vec3 AtmosphericScattering(in vec3 dir){
    vec3 AtmosphereColor;
    vec3 SunScatterColor = get_sky_color(dir, normalize(sunPosition), SUNSPOT_BRIGHTNESS / AccuracyIncrease) * AccuracyIncrease;
    vec3 MoonScatterColor = get_sky_color(dir, normalize(moonPosition), MOONSPOT_BRIGHTNESS / AccuracyIncrease) * AccuracyIncrease;
    AtmosphereColor = SunScatterColor;
	#ifdef MOON_SCATTERING
	AtmosphereColor+= MoonScatterColor;
	#endif
    AtmosphereColor = enhance(AtmosphereColor) / 1000.0f;
    return AtmosphereColor;
}

//#define SCREEN_SPACE_REFLECTIONS

#endif