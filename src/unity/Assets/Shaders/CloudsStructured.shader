
Shader "Custom/Clouds 3D Strat" {
	Properties {
	}
	
	CGINCLUDE;
	
	#include "UnityCG.cginc"
	
	// the number of volume samples to take
	#define SAMPLE_COUNT 32
	#define PERIOD 1.
	
	// sun direction
	#define SUN_DIR float3(-0.70710678,0.,-.70710678)
	
	//#define DIAGRAM_OVERLAY

	struct v2fd {
		float4 pos : SV_POSITION;
		float2 uv  : TEXCOORD0;
	};
	
	sampler2D _MainTex;

	sampler2D _NoiseTex;
	
	uniform float4 _CamPos;
	uniform float4 _CamForward;
	uniform float4 _CamRight;
	uniform float  _HalfFov;
	
	v2fd vert( appdata_img v )
	{
		v2fd o;
		o.pos = mul( UNITY_MATRIX_MVP, v.vertex );
		
		o.uv = v.texcoord.xy;
		o.uv.y = 1.0 - o.uv.y;
		
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

	float mysign( float x ) { return x < 0. ? -1. : 1.; }
	float2 mysign( float2 x ) { return float2( x.x < 0. ? -1. : 1., x.y < 0. ? -1. : 1. ) ; }

	void SetupSampling( out float2 t, out float2 dt, out float2 wt, in float3 ro, in float3 rd, float period )
	{
		// strata line normals
		float3 n0 = abs( rd.x ) > abs( rd.z ) ? float3(1., 0., 0.) : float3(0., 0., 1.); // non diagonal
		float3 n1 = float3(mysign( rd.x * rd.z ), 0., 1.); // diagonal

		// normal lengths (used later)
		float2 ln = float2(length( n0 ), length( n1 ));
		n0 /= ln.x;
		n1 /= ln.y;

		// some useful DPs
		float2 ndotro = float2(dot( ro, n0 ), dot( ro, n1 ));
		float2 ndotrd = float2(dot( rd, n0 ), dot( rd, n1 ));

		// step size
		float2 periods = ln * period;
		dt = periods / abs( ndotrd );

		// dist to line through origin
		float2 dist = abs( ndotro / ndotrd );

		// raymarch start offset - skips leftover bit to get from ro to first strata lines
		t = -mysign( ndotrd ) * fmod( ndotro, periods ) / abs( ndotrd );
		// the ifs seem to only be required on shadertoy, not sure why..
		/*if( ndotrd.x > 0. )*/ t.x += dt.x;
		/*if( ndotrd.y > 0. )*/ t.y += dt.y;

		// sample weights
		float minperiod = period;
		float maxperiod = sqrt( 2. )*period;
		wt = smoothstep( maxperiod, minperiod, dt/ln );
		wt /= (wt.x + wt.y);
	}
	
	float4 Raymarch( in float3 ro, in float3 rd )
	{
	    float4 sum = float4(0, 0, 0, 0);
	    
	    // setup sampling
	    float2 wt;
		float2 t, dt;
		SetupSampling( t, dt, wt, ro, rd, PERIOD );

	    for( int i=0; i<SAMPLE_COUNT; i++ )
	    {
	        if( sum.a > 0.99 ) continue;


			// data for next sample
			const float4 data = t.x < t.y ? float4(t.x, wt.x, dt.x, 0.0) : float4(t.y, wt.y, 0.0, dt.y); // ( t, wt, dt )
			const float3 pos = ro + data.x * rd;
			const float w = data.y;
			t += data.zw;

			
			float4 col = map( pos );
	        
	        // iqs goodness
     	   	float dif = clamp((col.w - map(pos+0.6*SUN_DIR).w)/0.6, 0.0, 1.0 );
	        float3 lin = float3(0.51, 0.53, 0.63)*1.35 + 0.55*float3(0.85, 0.57, 0.3)*dif;
	        col.xyz *= col.xyz;
	        col.xyz *= lin;
	        col.a *= 0.35;
	        col.rgb *= col.a;

	        // integrate

	        float thisDt = dt;
	        //thisDt = sqrt(thisDt/5. )*5.; // hack to soften and brighten

		    sum += thisDt * col * (1.0 - sum.a) * w;
	    }

	    sum.xyz /= (0.001+sum.w);

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
	
	#define DIAGRAM_SCALE 0.015
	#define DIAGRAM_PERIOD 10.

	float DiagramDot( float2 pos, float2 uv )
	{
		pos *= DIAGRAM_SCALE;

		float rad = 0.009;
		float feath = 0.005;
		float l = length( uv - pos );
		float res = smoothstep( rad + feath, rad, l );
		float m1 = 1.6, m2 = 2.4;
		res += .5*smoothstep( rad * m1, rad * m1 + feath, l );
		res -= .5*smoothstep( rad * m2, rad * m2 + feath, l );
		return 2.*res;
	}

	#define vec2 float2
	#define vec3 float3
	#define fract frac
	#define mix lerp

	float DiagramLine(vec2 p, vec2 n)
	{
		n /= dot( n, n );

		float d = abs( dot( p, n ) );
		float fr = abs( fract( d / DIAGRAM_PERIOD ) );
		// fix fract boundary
		fr = min( fr, 1. - fr );

		return smoothstep( .03, 0., fr );
	}

	float3 Diagram( float3 ro, float3 fo, float3 ri, float2 uv )
	{
		uv.y += 0.1;

		// move uvs to origin, correct for aspect
		uv = 2. * uv - 1.;
		uv.x *= _ScreenParams.x / _ScreenParams.y;

		float res = 0.;

		for( int j = -5; j <= 5; j++ )
		{
			float3 rd = fo + 0.1 * float(j) * ri;
			rd = normalize( rd );

			float2 t, dt, wt;
			SetupSampling( t, dt, wt, ro, rd, DIAGRAM_PERIOD );
			for( int i = 0; i < 15; i++ )
			{
				// data for next sample
				const float4 data = t.x < t.y ? float4(t.x, wt.x, dt.x, 0.0) : float4(t.y, wt.y, 0.0, dt.y); // ( t, wt, dt )
				const float w = data.y;
				t += data.zw;

				const float2 x = float2(0.,-5.)*0. + data.x * normalize( float2( 0.1 * float(j), 1. ) );

				res = max( res, w*DiagramDot( x, uv ) );
			}
		}

		float2 lp = uv / DIAGRAM_SCALE;
		lp = lp.x * _CamRight.xz + lp.y * _CamForward.xz;
		lp += _CamPos.xz;

		float lines = 0.;
		lines = max( lines, DiagramLine( lp, float2(1., 0.) ) );
		lines = max( lines, DiagramLine( lp, float2(0., 1.) ) );
		lines = max( lines, DiagramLine( lp, float2(1., 1.) ) );
		lines = max( lines, DiagramLine( lp, float2(1., -1.) ) );

		return (float3)(res+0.2*lines);
	}

	float4 frag(v2fd i) : SV_Target 
	{	
		float3 camUp = cross( _CamForward.xyz, _CamRight.xyz );
		
		float2 q = i.uv;
		float2 p = 2.0*(q - 0.5);
		
    	float fovH = tan(_HalfFov);
    	float fovV = tan(_HalfFov * _ScreenParams.y/_ScreenParams.x);
		float3 rd = normalize(_CamForward.xyz + p.y * fovV * camUp + p.x * fovH * _CamRight.xyz);
		
		// march away
    	float4 res = Raymarch( _CamPos, rd );
    	
		// blend in sky if it is visible
		if( res.a <= 0.99 )
			res.xyz = lerp( skyColor( rd ), res.xyz, res.w );
	    
	    // post process
		res.xyz = clamp( res.xyz, 0., 1.);
		res.xyz = smoothstep(0.,1., res.xyz ); // Contrast
		res.xyz *= pow( 16.0*q.x*q.y*(1.0-q.x)*(1.0-q.y), 0.12 ); // Vignette

		// diagram overlay
		#ifdef DIAGRAM_OVERLAY
		res.xyz *= .6;
		res.xyz += 0.4 * Diagram( _CamPos, _CamForward, _CamRight, i.uv );
		#endif

		return float4(res.xyz, 1.0);
	}
	
	ENDCG 
	
Subshader {
 Pass {
	  ZTest Always Cull Off ZWrite Off

      CGPROGRAM
	  #pragma target 3.0   
      #pragma vertex vert
      #pragma fragment frag
      ENDCG
  }
}

Fallback off
	
} // shader
