/*
The MIT License (MIT)

Copyright (c) 2016 Huw Bowles & Daniel Zimmermann

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

Shader "Custom/Clouds 3D Strat" {
	Properties {
	}
	
	CGINCLUDE
	
	#include "UnityCG.cginc"
	
	// the number of volume samples to take
	#define SAMPLE_COUNT 32
	#define PERIOD 1.
	
	// sun direction
	#define SUN_DIR float3(-0.70710678,0.,-.70710678)
	
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

	void SetupSampling( out float2 t, out float2 dt, out float2 wt, in float3 ro, in float3 rd )
	{
		// strata line normals
		float3 n0 = abs( rd.x ) > abs( rd.z ) ? float3(1., 0., 0.) : float3(0., 0., 1.); // non diagonal
		float3 n1 = float3(mysign( rd.x * rd.z ), 0., 1.); // diagonal
		//n0 = float3(1., 0., 0.);
		//n1 = float3(0., 0., 1.);

		// normal lengths (used later)
		float2 ln = float2(length( n0 ), length( n1 ));
		n0 /= ln.x;
		n1 /= ln.y;

		// some useful DPs
		float2 ndotro = float2(dot( ro, n0 ), dot( ro, n1 ));
		float2 ndotrd = float2(dot( rd, n0 ), dot( rd, n1 ));

		// step size
		float2 period = ln * PERIOD;
		dt = period / abs( ndotrd );

		// dist to line through origin
		float2 dist = abs( ndotro / ndotrd );

		// raymarch start offset - skips leftover bit to get from ro to first strata lines
		t = -mysign( ndotrd ) * fmod( ndotro, period ) / abs( ndotrd );
		if( ndotrd.x > 0. ) t.x += dt.x;
		if( ndotrd.y > 0. ) t.y += dt.y;

		// sample weights
		float minperiod = PERIOD;
		float maxperiod = sqrt( 2. )*PERIOD;
		wt = smoothstep( maxperiod, minperiod, dt/ln );
		wt /= (wt.x + wt.y);
	}
	
	float4 Raymarch( in float3 ro, in float3 rd )
	{
	    float4 sum = float4(0, 0, 0, 0);
	    
	    // setup sampling
	    float2 wt;
		float2 t, dt;
		SetupSampling( t, dt, wt, ro, rd );

		//t.y = 1000.;

	    for( int i=0; i<SAMPLE_COUNT; i++ )
	    {
	        if( sum.a > 0.99 ) continue;

			// dda-style thing - can do this (more) branchless?
			//const float4 sampleState = t.x < t.y ? float4(dt.x, 0., t.x, wt.x) : float4(0., dt.y, t.y, wt.y); // ( dt, current t, wt )
			//t += sampleState.xy;
			//const float3 pos = ro + sampleState.z * rd;
			//const float w = sampleState.w;


			// dda style thing - can do this branchless?
			float3 pos; float w;
			if( (t.x < t.y /*|| straightOnly*/) /*&& !diagOnly*/ )
			{
				pos = ro + t.x * rd;
				w = wt.x;
				w *= dt.x;
				if( t.x < 0. ) w *= 0.;
				t.x += dt.x;
			}
			else
			{
				pos = ro + t.y * rd;
				w = wt.y;
				w *= dt.y;
				if( t.y < 0. ) w *= 0.;
				t.y += dt.y;
			}
		
			
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
