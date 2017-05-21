
Shader "VolSample/EXPERIMENTAL VS Clouds 3D Strat Geometry" {
	Properties {
	}
	
	CGINCLUDE;
	
	#include "UnityCG.cginc"
	
	// the number of volume samples to take
	#define SAMPLE_COUNT 32

	// spacing between samples
	#define SAMPLE_PERIOD 1.
	
	// sun direction
	#define SUN_DIR float3(-0.70710678,0.,-.70710678)
	
	// show diagram
	//#define DIAGRAM_OVERLAY

	// debug bevel areas
	#define DEBUG_BEVEL 0

	// debug weights
	#define DEBUG_WEIGHTS 0

	struct v2fd {
		float4 pos : SV_POSITION;
		float4 screenPos : TEXCOORD1;
		float3 blendWeights : COLOR;
		float3 t : TEXCOORD5;
		float3 dt : TEXCOORD6;
	};
	
	uniform sampler2D _NoiseTex;

	// passed in as this shader is run from a post proc camera
	uniform float3 _CamPos;
	uniform float3 _CamForward;
	uniform float3 _CamRight;

	uniform float  _HalfFov;

	uniform sampler2D _CameraDepthTexture;


	float3 DecodeNormalFromUV(float2 uv)
	{
		float2 fEnc = uv * 4 - 2;
		float f = dot(fEnc, fEnc);
		float g = sqrt(1 - f / 4);
		return float3(fEnc * g, 1 - f / 2);
	}

	void computeCamera(in float2 screenPos, out float3 ro, out float3 rd)
	{
		float fovH = tan(_HalfFov);
		float fovV = tan(_HalfFov * _ScreenParams.y / _ScreenParams.x);
		float3 camUp = cross(_CamForward.xyz, _CamRight.xyz);
		ro = _WorldSpaceCameraPos;
		rd = normalize(_CamForward.xyz + screenPos.y * fovV * camUp + screenPos.x * fovH * _CamRight.xyz);
	}

	void IntersectPlanes(in float3 n, in float3 ro, in float3 rd, out float t_0, out float dt)
	{
		float ndotrd = dot(rd, n);
		dt = SAMPLE_PERIOD / abs(ndotrd);

		// raymarch start offset - skips leftover bit to get from ro to first strata plane
		t_0 = -fmod(dot(ro, n), SAMPLE_PERIOD) / ndotrd;
		// the ifs seem to only be required on shadertoy, not sure why...
		/* if( ndotrd > 0. )*/ t_0 += dt;
	}
	
	v2fd vert(appdata_full v )
	{
		v2fd o;

		// place the mesh camera-centered.
		o.pos = mul( UNITY_MATRIX_VP, float4(100.0 * v.vertex.xyz + _WorldSpaceCameraPos, v.vertex.w) );

		o.screenPos = ComputeScreenPos(o.pos);

		// decode sampling plane normals from the UV channels
		float3 normal0 = DecodeNormalFromUV(v.texcoord.xy);
		float3 normal1 = DecodeNormalFromUV(v.texcoord1.xy);
		float3 normal2 = DecodeNormalFromUV(v.texcoord2.xy);

		// pass on the blend weights from the color channel
		o.blendWeights = v.color.rgb;

		// Compute camera origin and ray direction
		float3 ro = _WorldSpaceCameraPos;
		float3 rd = normalize(v.vertex.xyz);

		// Compute raymarch start offset and step
		IntersectPlanes( normal0, ro, rd, o.t.x, o.dt.x );
		IntersectPlanes( normal1, ro, rd, o.t.y, o.dt.y );
		IntersectPlanes( normal2, ro, rd, o.t.z, o.dt.z );

		return o;
	}

	float noise( in float3 x )
	{
	    float3 p = floor(x);
	    float3 f = frac(x);
	    f = f*f*(3.0-2.0*f);
	    
	    float2 uv2 = (p.xy+float2(37.0,17.0)*p.z) + f.xy;
	    float2 rg = tex2Dlod( _NoiseTex, float4( (uv2 + 0.5)/256.0, 0.0, 0.0 ) ).yx;
	    return lerp( rg.x, rg.y, f.z );
	}
	
	float4 map( in float3 p )
	{
		float d = .1 + .8 * sin(0.6*p.z)*sin(0.5*p.x) - p.y; // was 0.1

	    float3 q = p;
	    float f;
	    f  = 0.5000*noise( q ); q = q*2.02;
	    f += 0.2500*noise( q ); q = q*2.03;
	    f += 0.1250*noise( q ); q = q*2.01;
	    f += 0.0625*noise( q );
	    d += 2.75 * f;

	    d = clamp( d, 0.0, 1.0 );
	    
	    float4 res = (float4)d;

	    float3 col = 1.15 * float3(1.0,0.95,0.8);
	    col += float3(1.,0.,0.) * exp2(res.x*10.-10.);
	    res.xyz = lerp( col, float3(0.7,0.7,0.7), res.x );
	    
	    return res;
	}

	float4 VolumeSampleColor(in float3 pos)
	{
		// color
		float4 col = map(pos);

		// iqs goodness
		float dif = clamp((col.w - map(pos + 0.6*SUN_DIR).w) / 0.6, 0.0, 1.0);
		float3 lin = float3(0.51, 0.53, 0.63)*1.35 + 0.55*float3(0.85, 0.57, 0.3)*dif;
		col.xyz *= col.xyz;
		col.xyz *= lin;
		col.a *= 0.35;
		col.rgb *= col.a;

		return col;
	}

	void IntegrateColor(in float4 col, in float dt, inout float4 sum)
	{
		// dt = sqrt(dt / 5) * 5; // hack to soften and brighten
		sum += dt * col * (1.0 - sum.a);
	}

	float4 Raymarch_1Weight( in float3 ro, in float3 rd, in float t, in float dt )
	{
		float4 sum = float4(0, 0, 0, 0);

		for (int i = 0; i<SAMPLE_COUNT; i++)
		{
			if (sum.a > 0.99) continue;

			// Get the sampling position and move on
			float3 pos = ro + t * rd;
			t += dt;

			// color
			float4 col = VolumeSampleColor(pos);
			IntegrateColor(col, dt, sum);
		}

		sum.xyz /= (0.001 + sum.w);

#if DEBUG_WEIGHTS
		sum.rgb *= abs(n0);
#elif DEBUG_BEVEL
		sum *= float4(0, 1, 0, 1);
#endif

		return saturate(sum);
	}

	float4 Raymarch_2Weights( in float3 ro, in float3 rd, in float2 t, in float2 dt, in float2 wt )
	{
		float4 sum0 = float4(0, 0, 0, 0);
		float4 sum1 = float4(0, 0, 0, 0);

		for (int i = 0; i<SAMPLE_COUNT; i++)
		{
			// get the sampling positions and move on
			float3 pos0 = ro + t.x * rd;
			float3 pos1 = ro + t.y * rd;
			t += dt;

			if( sum0.a <= 0.99 )
			{
				float4 col = VolumeSampleColor( pos0 );
				IntegrateColor( col, dt.x, sum0 );
			}

			if( sum1.a <= 0.99 )
			{
				float4 col = VolumeSampleColor( pos1 );
				IntegrateColor( col, dt.y, sum1 );
			}
		}

		// finally, blend the results from the rays.
		float4 sum = wt.x * sum0 + wt.y * sum1;
		sum.xyz /= (0.001 + sum.w);


#if DEBUG_WEIGHTS
		sum.rgb *= wt.x * abs(n0) + wt.y * abs(n1);
#elif DEBUG_BEVEL
		sum *= float4(0, 0, 1, 1);
#endif

		return saturate(sum);
	}
	
	float4 Raymarch_3Weights( in float3 ro, in float3 rd, in float3 t, in float3 dt, in float3 wt )
	{
		float4 sum0 = float4(0, 0, 0, 0);
		float4 sum1 = float4(0, 0, 0, 0);
		float4 sum2 = float4(0, 0, 0, 0);
	    
		for( int i=0; i<SAMPLE_COUNT; i++ )
	    {
			// get the sampling positions and move on
			float3 pos0 = ro + t.x * rd;
			float3 pos1 = ro + t.y * rd;
			float3 pos2 = ro + t.z * rd;
			t += dt;

			if (sum0.a <= 0.99)
			{
				float4 col = VolumeSampleColor(pos0);
				IntegrateColor(col, dt.x, sum0);
			}

			if (sum1.a <= 0.99)
			{
				float4 col = VolumeSampleColor(pos1);
				IntegrateColor(col, dt.y, sum1);
			}

			if (sum2.a <= 0.99)
			{
				float4 col = VolumeSampleColor(pos2);
				IntegrateColor(col, dt.z, sum2);
			}
	    }

		// finally, blend the results from the rays.
		float4 sum = wt.x * sum0 + wt.y * sum1 + wt.z * sum2;
		sum.xyz /= (0.001 + sum.w);

#if DEBUG_WEIGHTS
		sum.rgb *= wt.x * abs(n0) + wt.y * abs(n1) + wt.z * abs(n2);
#elif DEBUG_BEVEL
		sum *= float4(1, 0, 0, 1);
#endif

	    return saturate( sum );
	}

	float3 skyColor(float3 rd)
	{
	    float3 col = (float3)0.;

	    // horizon
	    float3 hor = (float3)0.;
	    float hort = 1. - clamp(abs(rd.y), 0., 1.);
	    hor += 0.5*float3(.99,.5,.0)*exp2(hort*8.-8.);
	    hor += 0.1*float3(.5,.9,1.)*exp2(hort*3.-3.);
	    hor += 0.55*float3(.6,.6,.9); //*exp2(hort*1.-1.);
	    col += hor;

	    // sun
	    float sun = clamp( dot(SUN_DIR,rd), 0.0, 1.0 );
	    col += .2*float3(1.0,0.3,0.2)*pow( sun, 2.0 );
	    col += .5*float3(1.,.9,.9)*exp2(sun*650.-650.);
	    col += .1*float3(1.,1.,0.1)*exp2(sun*100.-100.);
	    col += .3*float3(1.,.7,0.)*exp2(sun*50.-50.);
	    col += .5*float3(1.,0.3,0.05)*exp2(sun*10.-10.); 
	    
	    return col;
	}

	float3 combineColors(in float4 clouds, in float3 rd)
	{
		float3 col = clouds.rgb;
		if (clouds.a < 0.99)
			col = lerp(skyColor(rd), col, clouds.a);

		return col;
	}

	float4 postProcessing(in float3 col, in float2 screenPosNorm)
	{
		col = saturate(col);
		col = smoothstep(0., 1., col); // Contrast

		float2 q = screenPosNorm;
		col *= pow(16.0*q.x*q.y*(1.0 - q.x)*(1.0 - q.y), 0.12); // Vignette

		return float4(col, 1);
	}
	
	//#include "DiagramOverlay.cginc"

	float4 frag_1Weight(v2fd i) : SV_Target
	{
		float2 q = i.screenPos.xy / i.screenPos.w;
		float2 p = 2.0*(q - 0.5);

		// camera
		float3 ro, rd;
		computeCamera(p, ro, rd);

		// setup sampling
		float t = i.t.x;
		float dt = i.dt.x;

		// march through volume
		float4 clouds = Raymarch_1Weight(ro, rd, t, dt);

		// combine with background
		float3 col = combineColors(clouds, rd);

		// post processing
		return postProcessing(col, q);
	}

	float4 frag_2Weights(v2fd i) : SV_Target
	{
		float2 q = i.screenPos.xy / i.screenPos.w;
		float2 p = 2.0*(q - 0.5);

		// camera
		float3 ro, rd;
		computeCamera(p, ro, rd);

		// setup sampling
		float2 t = i.t.xy;
		float2 dt = i.dt.xy;

		// march through volume
		float4 clouds = Raymarch_2Weights(ro, rd, t, dt, i.blendWeights.xy);

		// combine with background
		float3 col = combineColors(clouds, rd);

		// post processing
		return postProcessing(col, q);
	}

	float4 frag_3Weights(v2fd i) : SV_Target 
	{
		float2 q = i.screenPos.xy / i.screenPos.w;
		float2 p = 2.0*(q - 0.5);

		// camera
		float3 ro, rd;
		computeCamera(p, ro, rd);

		// setup sampling
		float3 t = i.t.xyz;
		float3 dt = i.dt.xyz;
		
		// march through volume
		float4 clouds = Raymarch_3Weights(ro, rd, t, dt, i.blendWeights);

		// combine with background
		float3 col = combineColors(clouds, rd);

		// post processing
		return postProcessing(col, q);
	}
	
	ENDCG 
	
Subshader {
	Tags { "Queue" = "Transparent-1" }

	// Pass 0: One blend weight
	Pass {
		ZTest Always Cull Off ZWrite Off

		CGPROGRAM
		#pragma target 3.0   
		#pragma vertex vert
		#pragma fragment frag_1Weight
		ENDCG
	}

	// Pass 1: Two blend weights
	Pass {
		ZTest Always Cull Off ZWrite Off

		CGPROGRAM
		#pragma target 3.0   
		#pragma vertex vert
		#pragma fragment frag_2Weights
		ENDCG
	}

	// Pass 2: Three blend weights
	Pass {
		ZTest Always Cull Off ZWrite Off

		CGPROGRAM
		#pragma target 3.0   
		#pragma vertex vert
		#pragma fragment frag_3Weights
		ENDCG
	}
}

Fallback off
	
} // shader
