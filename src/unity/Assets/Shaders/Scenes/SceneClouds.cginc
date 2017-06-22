// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// Originated from two Shadertoy masterpieces:
//		Clouds by iq: https://www.shadertoy.com/view/XslGRr
//		Cloud Ten by nimitz: https://www.shadertoy.com/view/XtS3DD

// the number of volume samples to take
#define SAMPLE_COUNT 32

// spacing between samples
#define SAMPLE_PERIOD 1.

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

float4 map( in float3 p )
{
	float d = .1 + .8 * sin( 0.6*p.z )*sin( 0.5*p.x ) - p.y; // was 0.1

	float3 q = p;
	float f;
	f = 0.5000*noise( q ); q = q*2.02;
	f += 0.2500*noise( q ); q = q*2.03;
	f += 0.1250*noise( q ); q = q*2.01;
	f += 0.0625*noise( q );
	d += 2.75 * f;

	d = clamp( d, 0.0, 1.0 );

	float4 res = (float4)d;

	float3 col = 1.15 * float3(1.0, 0.95, 0.8);
	col += float3(1., 0., 0.) * exp2( res.x*10. - 10. );
	res.xyz = lerp( col, float3(0.7, 0.7, 0.7), res.x );

	return res;
}

float4 VolumeSampleColor( in float3 pos )
{
	// color
	float4 col = map( pos );

	// iqs goodness
	float dif = clamp( (col.w - map( pos + 0.6*SUN_DIR ).w) / 0.6, 0.0, 1.0 );
	float3 lin = float3(0.51, 0.53, 0.63)*1.35 + 0.55*float3(0.85, 0.57, 0.3)*dif;
	col.xyz *= col.xyz;
	col.xyz *= lin;
	col.a *= 0.35;
	col.rgb *= col.a;

	return col;
}

float3 skyColor( in float3 ro, in float3 rd )
{
	float3 col = (float3)0.;

	// horizon
	float3 hor = (float3)0.;
	float hort = 1. - clamp( abs( rd.y ), 0., 1. );
	hor += 0.5*float3(.99, .5, .0)*exp2( hort*8. - 8. );
	hor += 0.1*float3(.5, .9, 1.)*exp2( hort*3. - 3. );
	hor += 0.55*float3(.6, .6, .9); //*exp2(hort*1.-1.);
	col += hor;

	// sun
	float sun = clamp( dot( SUN_DIR, rd ), 0.0, 1.0 );
	col += .2*float3(1.0, 0.3, 0.2)*pow( sun, 2.0 );
	col += .5*float3(1., .9, .9)*exp2( sun*650. - 650. );
	col += .1*float3(1., 1., 0.1)*exp2( sun*100. - 100. );
	col += .3*float3(1., .7, 0.)*exp2( sun*50. - 50. );
	col += .5*float3(1., 0.3, 0.05)*exp2( sun*10. - 10. );

	return col;
}

float4 postProcessing( in float3 col, in float2 screenPosNorm )
{
	col = saturate( col );
	col = smoothstep( 0., 1., col ); // Contrast

	float2 q = screenPosNorm;
	col *= pow( 16.0*q.x*q.y*(1.0 - q.x)*(1.0 - q.y), 0.12 ); // Vignette

	return float4(col, 1);
}
