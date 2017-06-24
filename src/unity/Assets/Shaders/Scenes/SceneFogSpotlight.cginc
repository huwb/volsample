
// the number of volume samples to take
#define SAMPLE_COUNT 32

// spacing between samples
#define SAMPLE_PERIOD .6

#include "Spotlight.cginc"

uniform sampler2D _NoiseTex;
float noise( in float3 x )
{
	float3 p = floor( x );
	float3 f = frac( x );
	f = f*f*(3.0 - 2.0*f);

	float2 uv2 = (p.xy + float2(37.0, 17.0)*p.z) + f.xy;
	float2 rg = tex2Dlod( _NoiseTex, float4((uv2 + 0.5) / 256.0, 0.0, 0.0) ).yx;
	return lerp( rg.x, rg.y, f.z );
}

float4 VolumeSampleColor( in float3 pos )
{
	float dens = 2.5 * noise( pos - float3(.1,.5,.1)* _Time.w );

	float light = Spotlight( pos );

	float col = lerp( 0.05, .15, light ) * dens;
	float a = dens * .1;

	return float4((float3)col, a);
}

float3 skyColor( float3 ro, float3 rd )
{
	return (float3)0.;
}

float4 postProcessing( in float3 col, in float2 screenPosNorm )
{
	col = saturate( col );

	float2 q = screenPosNorm;
	col *= pow( 16.0*q.x*q.y*(1.0 - q.x)*(1.0 - q.y), 0.12 ); // Vignette

	//screenPosNorm.x *= _ScreenParams.x / _ScreenParams.y;
	//screenPosNorm *= _ScreenParams.y / 256.;
	//col *= lerp( tex2Dlod( _NoiseTex, 2. * float4(screenPosNorm, 0.0, 0.0) ).x, 1., .7 );

	return float4(col, 1.0);
}
