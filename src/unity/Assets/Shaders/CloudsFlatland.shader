/*
The MIT License (MIT)

Copyright (c) 2015 Huw Bowles & Daniel Zimmermann

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

// this renders the clouds, with a number of sample pinning methods (forward pinning, advection) and adaptive
// sampling in depth

// it doesn't seem to be possible to pass an array to a shader, so we just compute the sampling directly
// in the shader. see this for an example: 

Shader "Custom/Clouds Flatland" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "" {}
		_RValueTex ("R Values (Float)", 2D) = "" {}
	}
	
	CGINCLUDE
	
	#include "UnityCG.cginc"
	
	// the number of volume samples to take
	#define SAMPLE_COUNT 32
	// use this to turn adaptive sampling on/off
	#define ADAPTIVE_SAMPLING
	// sun direction
	#define SUN_DIR float3(-0.70710678,0.,-.70710678)
	
	struct v2fd {
		float4 pos : SV_POSITION;
		float2 uv[2] : TEXCOORD0;
	};
	
	sampler2D _MainTex;
	uniform float4 _MainTex_TexelSize;

	sampler2D _RValuesTex;
	uniform float2 _ScalesTexTexelCenters = float2(0.5/32.0, 31.5/32.0);

	sampler2D _CameraDepthNormalsTexture;
	sampler2D_float _CameraDepthTexture;
	
	sampler2D _NoiseTex;
	
	uniform float _ForwardIntegrator = 0.0;
	uniform float4 _CamPos;
	uniform float4 _CamForward;
	uniform float4 _CamRight;
	uniform float _HalfFov = 30.0;
	
	uniform float _DistMax = 128.0;
	
	// x is near dist
	// y is 1/(far dist - near dist)
	uniform float2 _ScaleRadii = float2(10.,0.);
	
	uniform float _ForwardPinScale = 1.0;
	
	#ifdef ADAPTIVE_SAMPLING
	uniform float _SamplesAdaptivity = 0.1f;
	uniform float _PdfNorm = 1.0f;
	uniform float _FadeSpeed = 1.0f;
	#endif
	
	float2 rValues;
	
	v2fd vert( appdata_img v )
	{
		v2fd o;
		o.pos = mul( UNITY_MATRIX_MVP, v.vertex );
		
		float2 uv = v.texcoord.xy;
		o.uv[0] = uv;
		
		#if UNITY_UV_STARTS_AT_TOP
		if (_MainTex_TexelSize.y < 0)
			uv.y = 1-uv.y;
		#endif
		
		o.uv[1] = uv;
		
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
		float d = 0.1 + .8 * sin(0.6*p.z)*sin(0.5*p.x) - p.y;

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

	#ifdef ADAPTIVE_SAMPLING
	float pdf_max( float xstart, float xend )
	{
	    xstart = max( xstart, 0. );
	    
	    //float linpdf = (1.-xstart/_DistMax)/_DistMax;
	    
	    // we choose to use a 1/z sample distribution
	    float pdf = 1./(1. + xstart*_SamplesAdaptivity);
	    // norm pdf
	    pdf *= _PdfNorm;
	    
	    return pdf;
	}
	
	float dens_max( float x, float dx )
	{
	    return pdf_max(x,x+dx) * (float)SAMPLE_COUNT;
	}
	#endif

	float mod_mov( float x, float y )
	{
		return fmod( x + _ForwardIntegrator, y );
	}
	
	bool onBoundary( float x, float y )
	{
	    // the +0.25 solves numerical issues without changing the result
	    float numericalFixOffset = y*0.25;
		return mod_mov( x + numericalFixOffset, y ) < y*0.5;
	}
	
	void FirstT( out float t, out float dt, out float wt, out bool even )
	{
		#ifdef ADAPTIVE_SAMPLING
		t = 0.;
		float dens = dens_max(t,0.);
		dt = exp2(floor(log2(1./dens)));
	    t = 2.*dt - mod_mov(t,2.*dt);
		wt = clamp( _FadeSpeed*(2.0 * dens * dt - 1.0), 0., 1. );
	    even = true;
	    #else
		dt = 1.0;
	    t = dt - mod_mov(0.,dt);
	    wt = 1.; // not used
	    even = true; // not used
	    #endif
	}
	void NextT( inout float t, inout float dt, inout float wt, inout bool even )
	{
		#ifdef ADAPTIVE_SAMPLING
        // sample at x, give weight wt
        if( even )
        {
			float dens = dens_max( t, dt * 2.0 );
            float nextDt, nextDens; bool nextEven;
            
            nextDt = 2.*dt;
            nextEven = onBoundary( t, nextDt*2. );
            if( nextEven )
            {
                nextDens = dens_max( t, nextDt*2. );
                if( nextDens < .5 / dt )
                {
                    // lower sampling rate
					dt = nextDt;
					// commit to this density
					dens = nextDens;
					
	                // can repeat to step down sampling rates faster
                }
            }
            
			wt = clamp( _FadeSpeed*(2.0 * dens * dt - 1.0), 0., 1. );
        }
        
	    even = !even;
	    #endif
	    
        t += dt;
	}
	
	float4 raymarch( in float3 ro, in float3 rd )
	{
	    float4 sum = float4(0, 0, 0, 0);
	    
	    // setup sampling
	    float t, dt, wt; bool even;
	    FirstT( t, dt, wt, even );
	    
	    for( int i=0; i<SAMPLE_COUNT; i++ )
	    {
	        if( sum.a > 0.99 ) continue;

			float scaleAlpha = clamp( (t*_ForwardPinScale - _ScaleRadii.x)*_ScaleRadii.y, 0.0, 1.0 );
			float r = lerp( rValues.x, rValues.y, scaleAlpha );
			
	        float3 pos = ro + t*rd*r;
	        float4 col = map( pos );
	        
	        // iqs goodness
     	   	float dif = clamp((col.w - map(pos+0.6*SUN_DIR).w)/0.6, 0.0, 1.0 );
	        float3 lin = float3(0.51, 0.53, 0.63)*1.35 + 0.55*float3(0.85, 0.57, 0.3)*dif;
	        col.xyz *= col.xyz;
	        col.xyz *= lin;
	        col.a *= 0.35;
	        col.rgb *= col.a;

	        // fade samples at far field
	        float fadeout = 1.-clamp((t/(_DistMax*.6)-.85)/.15,0.,1.); // .2 is an ugly fudge factor due to oversampling. TODO is this really working?
	        
	        // integrate
	        
	        float thisDt = dt;
	        
	        #ifdef ADAPTIVE_SAMPLING
	        thisDt *= (even ? (2.-wt) : wt); // blend in dts
	        #endif
	        
	        thisDt = sqrt(thisDt/5. )*5.; // hack to soften and brighten
	        
	        sum += r * thisDt * col * (1.0 - sum.a) * fadeout;

	        // next sample
	       	NextT( t, dt, wt, even );
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
		//float centerDepth = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv[1]));
		//float2 uvDist = _SampleDistance * _MainTex_TexelSize.xy;
		
		float3 camUp = cross( _CamForward.xyz, _CamRight.xyz );
		
		float2 q = i.uv[1];
		
		float2 p = 2.0*(q - 0.5);
		
    	float fovH = tan(_HalfFov);
    	float fovV = tan(_HalfFov * _ScreenParams.y/_ScreenParams.x);
		float3 rd = normalize(_CamForward.xyz + p.y * fovV * camUp + p.x * fovH * _CamRight.xyz);
		
		float rLookUp = ( 1. - (atan2(dot(rd,_CamForward),dot(rd,_CamRight))-acos(0.))/_HalfFov )/2.;
		// texel values. going to the texture boundary is wrong for both clamp and wrap, the range lies over the texel centers
		rLookUp = lerp( _ScalesTexTexelCenters.x, _ScalesTexTexelCenters.y, rLookUp );
		rValues = tex2Dlod( _RValuesTex, float4( rLookUp, 0.5, 0.0, 0.0 ) ).xy;
		
    	float4 res = raymarch( _CamPos, rd );
    	
		float3 col = skyColor(rd);
		
		col = lerp( col, res.xyz, res.w );
	    
	    
	    
	    // post process
		col = clamp(col, 0., 1.);
		col = smoothstep(0.,1.,col);
		//   col = col*0.5 + 0.5*col*col*(3.0-2.0*col); //saturation
		//  col = pow(col, vec3(0.416667))*1.055 - 0.055; //sRGB
		
		col *= pow( 16.0*q.x*q.y*(1.0-q.x)*(1.0-q.y), 0.12 ); //Vign
	    
	    return float4( col, 1.0 );
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
