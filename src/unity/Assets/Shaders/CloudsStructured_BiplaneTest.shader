
Shader "Custom/Clouds 3D Strat Biplane" {
	Properties {
	}
	
	CGINCLUDE;
	
	#include "UnityCG.cginc"
	
	// the number of volume samples to take
	#define SAMPLE_COUNT 32

	// spacing between samples
	#define SAMPLE_PERIOD 1.
	
	// sun direction
	#define SUN_DIR normalize(float3(-0.40710678 * 2.5*sin(_Time.y),0.,.990710678))
	
	// show diagram
	//#define DIAGRAM_OVERLAY

	#define PI 3.141592653589
	#define EPS 0.001

	struct v2fd {
		float4 pos : SV_POSITION;
		float2 uv  : TEXCOORD0;
	};
	
	uniform sampler2D _NoiseTex;

	// passed in as this shader is run from a post proc camera
	uniform float3 _CamPos;
	uniform float3 _CamForward;
	uniform float3 _CamRight;

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
		// HACK - adjustment for plane modelling
		p.y += 1.5;
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

	// returns either -1 or 1, but not 0
	float mysign( float x ) { return x < 0. ? -1. : 1.; }
	float2 mysign( float2 x ) { return float2( x.x < 0. ? -1. : 1., x.y < 0. ? -1. : 1. ) ; }

	void SetupSampling( in float3 ro, in float3 rd, in float period, out float2 t, out float2 dt, out float2 wt, out float endFadeDist )
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
		float maxperiod = .9*sqrt( 2. )*period; // .9 reduces blend overlap between slices
		wt = smoothstep( maxperiod, minperiod, dt/ln );
		wt /= (wt.x + wt.y);

		// fade samples at far extent
		float f = .6; // magic number for now, derivation coming soon.
		endFadeDist = f*float( SAMPLE_COUNT )*period;
	}
	
	float4 Raymarch( in float3 ro, in float3 rd, in float z )
	{
	    float4 sum = float4(0, 0, 0, 0);
	    
	    // setup sampling
	    float2 wt;
		float2 t, dt;
		float endFadeDist;
		SetupSampling( ro, rd, SAMPLE_PERIOD, t, dt, wt, endFadeDist );

		for( int i=0; i<SAMPLE_COUNT; i++ )
	    {
	        if( sum.a > 0.99 ) continue;
			if( t.x > z && t.y > z ) continue;

			// data for next sample
			const float4 data = t.x < t.y ? float4(t.x, wt.x, dt.x, 0.0) : float4(t.y, wt.y, 0.0, dt.y); // ( t, wt, dt )
			const float3 pos = ro + data.x * rd;
			float w = data.y * smoothstep( endFadeDist, 0.95*endFadeDist, data.x );
			float thisdt = max( data.z, data.w );
			// "soft particle" style fade at hard geom
			w *= min( (z - t) / thisdt, 1. );
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

	float3 skyColor( float3 rd, float blur )
	{
	    float3 col = (float3)0.;

	    // horizon
	    float3 hor = (float3)0.;
	    float hort = 1. - clamp(abs(rd.y), 0., 1.);
		hort = pow( hort, lerp( 1., .02, blur ) );
	    hor += 0.5*float3(.99,.5,.0)*exp2(hort*8.-8.);
	    hor += 0.1*float3(.5,.9,1.)*exp2(hort*3.-3.);
	    hor += 0.55*float3(.6,.6,.9); //*exp2(hort*1.-1.);
	    col += hor;

		// no sun if blurry
		//if( blur == 1. )
		//	return col;

		// sun
		float sun = clamp( dot(SUN_DIR,rd), 0.0, 1.0 );
	    col += .2*float3(1.0,0.3,0.2)*pow( sun, 2.0 );
	    col += .5*float3(1.,.9,.9)*exp2(sun*650.-650.);
	    col += .1*float3(1.,1.,0.1)*exp2(sun*100.-100.);
	    col += .3*float3(1.,.7,0.)*exp2(sun*50.-50.);
	    col += .5*float3(1.,0.3,0.05)*exp2(sun*10.-10.); 
	    
		col *= col;
	    return col;
	}
	
	float3 skyColor( float3 rd )
	{
		return skyColor( rd, 0. );
	}

	#include "DiagramOverlay.cginc"

	#define ZFAR 10000.

	float udRoundBox( vec3 p, vec3 b, float r )
	{
		return length( max( abs( p ) - b, (float3)0.0 ) ) - r;
	}
	float sdHexPrism( vec3 p, vec2 h )
	{
		vec3 q = abs( p );
		return max( q.z - h.y, max( (q.x*0.866025 + q.y*0.5), q.y ) - h.x );
	}
	float sdCappedCylinder( vec3 p, vec2 h )
	{
		vec2 d = abs( vec2( length( p.xy ), p.z ) ) - h;
		return min( max( d.x, d.y ), 0.0 ) + length( max( d, 0.0 ) );
	}


	// exponential smooth min (k = 32);
	float smin( float a, float b, float k )
	{
		float res = exp( -k*a ) + exp( -k*b );
		return -log( res ) / k;
	}
	float smax( float a, float b, float k )
	{
		return -smin( -a, -b, k );
	}
	float sdPlane( float3 p, float3 n )
	{
		return dot( p, n );
	}
	float sdCylinder( vec3 p, vec3 c )
	{
		return length( p.xz - c.xy ) - c.z;
	}
	float sdCylinderAB( vec3 p, vec3 a, vec3 b, float r )
	{
		float3 ab = normalize( b - a );
		float3 p_ab = a + dot( p - a, ab )*ab;
		return length( p - p_ab ) - r;
	}
	float sdCylinderABCapped( vec3 p, vec3 a, vec3 b, float r )
	{
		float dab = length( b - a );
		float3 ab = ( b - a ) / dab;
		float dp = dot( p - a, ab );
		float3 p_ab = a + dp*ab;
		float dp_ab = length( p - p_ab ) - r;

		// caps handled by -dp, dp-dab
		return smax( max( -dp, dp - dab ), dp_ab, 48. );
	}

	#define VIEW_HEIGHT 1.3
	#define NOSE_Z 2.

	float enginesDE( float3 p )
	{
		//p.y += VIEW_HEIGHT;

		float d = ZFAR;

		// engines - quite a lot of messing around here to make them look ok (and circular) from the cockpit perspective
		float2 engOri = float2(0., .5);
		float engr = .65;
		float engz = NOSE_Z - .1;
		d = min( d, sdCylinderABCapped( p, float3(engOri, engz), float3(engOri + engr*normalize( float2(.5, 1.) ), engz), .12 ) );
		d = min( d, sdCylinderABCapped( p, float3(engOri, engz), float3(engOri + engr*normalize( float2(-.5, 1.) ), engz), .12 ) );
		d = min( d, sdCylinderABCapped( p, float3(engOri, engz), float3(engOri + 1.1*engr*normalize( float2(2.5, 1.) ), engz), .1 ) );
		d = min( d, sdCylinderABCapped( p, float3(engOri, engz), float3(engOri + 1.1*engr*normalize( float2(-2.5, 1.) ), engz), .1 ) );

		return d;
	}

	float beamsDE( float3 p )
	{
		float d = ZFAR;

		float barz = .7;
		float barr = .04;
		d = min( d, sdCylinderAB( p, float3(0., 0.5, barz), float3(1.9, 2., barz + .4), barr ) );
		d = min( d, sdCylinderAB( p, float3(0., 0.5, barz), float3(-1.9, 2., barz + .4), barr ) );

		d = min( d, sdCylinderAB( p, float3(0., .95, 1.35), float3(1.9, 2., barz + .4), .007 ) );
		d = min( d, sdCylinderAB( p, float3(0., .95, 1.35), float3(-1.9, 2., barz + .4), .007 ) );

		d = min( d, sdCylinderABCapped( p, float3(.45, .86, .75), float3(3.9, 2., barz + .4), .005 ) );
		d = min( d, sdCylinderABCapped( p, float3(-.45, .86, .75), float3(-3.9, 2., barz + .4), .005 ) );

		return d;
	}

	#define ANIM_PERIOD 1.
	void mixin( inout float curr, float target, float startTime, float dur )
	{
		float t = fmod( _Time.y, ANIM_PERIOD );
		curr = mix( curr, target, clamp( (t - startTime) / dur, 0., 1. ) );
	}
	void mixinSS( inout float curr, float target, float startTime, float dur )
	{
		float t = fmod( _Time.y, ANIM_PERIOD );
		curr += (target - curr) * smoothstep( startTime, startTime + dur, t );
		//// feeble attempt at bouncy/overshoot curves
		//float overshoot = .4;
		//float prop = .6;
		//float ss = (1. + overshoot)*smoothstep( startTime, startTime + dur*prop, t )
		//	- overshoot*smoothstep( startTime + dur*prop, startTime + dur, t );
		//curr += (target - curr) * ss;
	}

	float opaqueDE( float3 p )
	{
		// http://maxair2air.com/WEB%20MEDIA/PLANE%20PROFILES/STEARMAN/cockpit-field-view.jpg

		p.y += VIEW_HEIGHT;

		// now assume viewer local space
		//if( p.z > 3. ) return ZFAR;

		//float3 camUp = cross( _CamForward.xyz, _CamRight.xyz );
		//float3 planePos = _WorldSpaceCameraPos + _CamForward * 5. - camUp * 1.;

		float d;// = ZFAR;

		//d = min( d, dSph1 );

		//d = min( d, dSph2 );

		//d = udRoundBox( p-float3(0.,-1.,0.), float3(1.,1.,3.), .8 );
		/*
		float dHex = sdHexPrism( p*float3(1.9,1.9,1.), float2(1.,1.5) );
		float dCyl = sdCappedCylinder( p, float2(lerp(.7,.25,forwards),1.5) );

		d = lerp( dHex, dCyl, lerp(.6,.9,forwards) );

		float dSph2 = length( p - (float3(0.,1.,0.)) ) - .5;
		d = max( -dSph2, d );
		*/

		float forwards = clamp( p.z, 0., NOSE_Z ) / NOSE_Z;

		float xr = .35 - forwards*.1;
		float sideSlant = .5;
		float dPl1 = sdPlane( p - float3(0., 1., 0.), float3(0., 1., 0.) );
		float dPl2 = sdPlane( p - float3(xr, 1., 0.), normalize(float3(-sideSlant, -1., 0.)) );
		float dPl3 = sdPlane( p - float3(-xr, 1., 0.), normalize(float3(sideSlant, -1., 0.)) );

		float smth = mix( 76., 12., pow(forwards,.7) );

		float dur = .15;

		float t_body = 0.;

		// top of plane
		d = dPl1;
		// angled sides of plane
		mixinSS( d, smax( d, -dPl2, smth ), t_body, dur*.8 );
		mixinSS( d, smax( d, -dPl3, smth ), t_body, dur*.8 );
		//d = smax( d, -dPl2, smth );
		//d = mix( d, smax( d, -dPl2, smth ), clamp( _Time.y / .1, 0., 1. ) );
		//d = smax( d, -dPl3, smth );

		// vertical sides of plane
		//d = max( d, p.z - NOSE_Z );
		//d = smax( d, p.x - xr*1.7, 32. );
		//d = smax( d, -p.x - xr*1.7, 32. );
		mixinSS( d, smax( d, p.x - xr*1.7, 32. ), t_body+dur*.8, dur*.8 );
		mixinSS( d, smax( d, -p.x - xr*1.7, 32. ), t_body+dur*.8, dur*.8 );

		// cut off nose
		d = max( d, p.z - NOSE_Z );
		//mixinSS( d, max( d, p.z - NOSE_Z ), t_body + 1.25*dur, dur*.8 );

		// engines - would be nice if these blended in one by one
		//d = min( d, enginesDE( p ) );
		mixinSS( d, min( d, enginesDE( p ) ), t_body + 1.25*dur, .8*dur );

		// cockpit
		float dCP = length( p - (float3(0., 1., 0.25)) ) - .5;
		//d = max( -dCP, d );
		mixinSS( d, max( -dCP, d ), t_body + 2.5*dur, .7*dur );


		// dent on hood
		float dentz = .7*NOSE_Z;
		float dentw = .05;
		float denta = 0.005;
		//d += denta * smoothstep( dentz-dentw, dentz, p.z );
		//d -= denta * smoothstep( dentz, dentz+dentw, p.z );
		mixinSS( d, d + denta * smoothstep( dentz - dentw, dentz, p.z ) - denta * smoothstep( dentz, dentz + dentw, p.z ), t_body + 2.75*dur, .5*dur );

		
		float t_wing = 2.75*dur;

		// top wing
		//d = min( d, .4*(length( (p.yz - float2(2., .5))*float2(5.,1.)  ) - 1.) );
		mixinSS( d, min( d, .4*(length( (p.yz - float2(2., .5))*float2(5., 1.) ) - 1.) ), t_wing - 2.5*dur, dur );

		// beams - would be nice if these blended in thick then thin
		//d = min( d, beamsDE( p ) );
		mixinSS( d, min( d, beamsDE( p ) ), t_wing+.75*dur, dur*.6 );
	
		return d;
	}

	float3 norm( in vec3 pos )
	{
		vec3 eps = vec3( EPS, 0.0, 0.0 );

		return normalize( vec3(
			opaqueDE( pos + eps.xyy ).x - opaqueDE( pos - eps.xyy ).x,
			opaqueDE( pos + eps.yxy ).x - opaqueDE( pos - eps.yxy ).x,
			opaqueDE( pos + eps.yyx ).x - opaqueDE( pos - eps.yyx ).x ) );
	}

	// xyz - albedo colour, w - gloss
	float4 opaqueMat( float3 p )
	{
		p.y += VIEW_HEIGHT;

		if( abs( enginesDE( p ) ) < EPS*1.5 )
		{
			return float4((float3)0.07, .5);
		}
		else if( abs( beamsDE( p ) ) < EPS*1.5 )
		{
			// beams - blue paint
			float3 albedo = .35*float3(0.15,0.15,1.);
			float gloss = 1.;
			return float4(albedo, gloss);
		}

		// rest - yellow paint
		float3 albedo = (float3)1.2;
		albedo.b *= .3;
		albedo.g *= .75;
		float gloss = 1.;
		return float4(albedo, gloss);
	}

/*	float3 norm( float3 p )
	{
		float3 camUp = cross( _CamForward.xyz, _CamRight.xyz );
		float3 planePos = _WorldSpaceCameraPos + _CamForward * 5. - camUp * 1.;

		return normalize( p - planePos );
	}*/

	float opaque( float3 ro, float3 rd, out float3 n )
	{
		float t = 0.;
		for( int i = 0; i < 70; i++ )
		{
			float3 p = ro + t * rd;

			float d = opaqueDE( p );
			if( d == ZFAR ) break;

			t += d;
			if( abs(d) < EPS )
			{
				n = norm( p );

				return t;
			}
		}
		return ZFAR;
	}

	float seed = 100.;
	vec2 rand2()
	{
		return fract( sin( vec2( seed += 0.1, seed += 0.1 ) )*vec2( 43758.5453123, 22578.1459123 ) );
	}

	float3 hash3( float n )
	{
		return fract( sin( float3( n, n + 1.0, n + 2.0 ) )*float3( 13.5453123, 31.1459123, 37.3490423 ) );
	}

	vec3 squareToCosineHemisphere( in vec2 sample )
	{
		float r = sqrt( sample.x );
		vec2 disc = vec2( r * sin( 2.0 * PI * sample.y ), r * cos( 2.0 * PI * sample.y ) );

		return vec3( disc, sqrt( 1.0 - r * r ) );
	}

	float4 frag(v2fd i) : SV_Target
	{
		seed = i.uv.x*1024. + i.uv.y*1024. * 3.43121412313 + fract( 1.12345314312*float( _Time.w ) );

		float2 q = i.uv;
		float2 p = 2.0*(q - 0.5);
		
		// camera
    	float fovH = tan(_HalfFov);
    	float fovV = tan(_HalfFov * _ScreenParams.y/_ScreenParams.x);
		float3 camUp = cross( _CamForward.xyz, _CamRight.xyz );
		float3 rd = normalize(_CamForward.xyz + p.y * fovV * camUp + p.x * fovH * _CamRight.xyz);
		float3 ro = _WorldSpaceCameraPos;

		// march against opaque
		float3 n;
		float z = opaque( ro, rd, n );

		// march through volume
		float4 clouds = (float4)0.;// Raymarch( ro, rd, z );
		clouds.xyz *= clouds.xyz;
		//clouds = (float4)0.;

		// result color
		float3 col = clouds.xyz;

		// compute and blend stuff behind medium if it is visible
		if( clouds.a <= 0.99 )
		{
			// behind medium
			float3 backCol;

			if( z == ZFAR )
			{
				// sky
				backCol = skyColor( rd );
			}
			else
			{
				float3 inLight = (float3)0.;

				float3 pos = ro + z * rd;
				float volDens = map( pos ).w;

				float ambLightOcc = 1. - volDens*.2;


				float3 ri = float3(1., .9, .8)/sqrt(3.);
				ri = normalize( ri - dot( ri, n )*n );
				float3 ri2 = cross( ri, n );

				float3 spec = (float3)0.;

				const int COUNT = 4; // 64
				for( int i = 0; i<COUNT; i++ )
				{
					vec3 rray = squareToCosineHemisphere( rand2() );
					float pdf = rray.z / PI;

					//float3 hsh = -1.0 + 2.0*hash3( float( i )*123.5463 );
					//hsh.y = abs( hsh.y );
					//hsh.xz *= spread;
					float3 rr = normalize( rray.x * ri + rray.y * ri2 + rray.z * n );

					float3 skycol = .6*skyColor( rr );
					//vec3 rr = normalize(-1.0 + 2.0*texture2D( iChannel2, vec2((0.5+float(i)),0.5)/256.0,-100.0).xyz);
					//rr = normalize( rr );
					rr = rr * sign( dot( n, rr ) ); // mirror if pointing into geom
					//inLight += pow( textureCube( iChannel0, rr ).xyz, (float3)2.2 ) * dot( rr, n ) * ds;
					inLight += skycol * pow( dot( rr, n ), 1. ) / pdf;
					//lerp(1.,200.,gloss)

					//spec = skyColor( reflect( rd, n ) );
					//float3 refl = reflect( rd, n );
					//spec += pow( max(dot( refl, rr ),0.),20.) * skycol;
				}
				ambLightOcc = 1.;
				inLight *= ambLightOcc / float(COUNT);
				//inLight = 1.;

				/*
				float geomTerm = dot( n, SUN_DIR );
				if( geomTerm > 0. )
				{
					float3 sunlight = .4*skyColor( SUN_DIR );
					inLight += (1.-volDens*.7) * sunlight * geomTerm;
				}

				//if( geomTerm > 0. )
				{
					// just taking one direction for the sun light looks a bit
					// pants and doesnt really capture the orange glow. take a ring around the sun
					// n is normal dir
					// SUN_DIR is sun dir
					// want version of n, that is 0.9 along SUN_DIR
					// dot( newSun, SUN_DIR ) = 0.8
					float3 sdToN = n - SUN_DIR;
					sdToN -= dot( sdToN, SUN_DIR )*SUN_DIR;
					float3 sunRingDir = normalize( SUN_DIR + .5*normalize( sdToN ) );

					geomTerm = dot( n, sunRingDir );
					if( geomTerm > 0. )
					{
						float3 sunlight = .4*skyColor( normalize(lerp(sunRingDir,SUN_DIR,.85)) );
						//inLight += (1. - volDens*.7) * sunlight * geomTerm;
					}
				}

				float ambLightOcc = 1. - volDens*.1;

				float3 downLightDir = float3(0., 1., 0.);
				float3 dlToN = n - downLightDir;
				dlToN -= dot( dlToN, downLightDir )*downLightDir;
				downLightDir = normalize( downLightDir + .5*normalize( dlToN ) );
				float3 downLight = 1.8*skyColor( downLightDir );
				inLight += ambLightOcc * pow(max( dot( n, downLightDir ), 0. ),1.) * downLight;

				
				float3 horizLightDir = -SUN_DIR * float3(1., 0., 1.);
				horizLightDir = normalize( horizLightDir );
				float3 horizLight = skyColor( horizLightDir );
				inLight += 1.2* ambLightOcc * max( 0., dot( n, normalize( n*float3(1., 0., 1.) ) ) ) * horizLight;

				#if 0
				float3 directLightDir = n;
				directLightDir.y += .0; directLightDir = normalize( directLightDir );
				float3 directLight = 1.5*skyColor( directLightDir, 1. );
				directLight = lerp( directLight, 1.1*float3(1.1,.96,.98), clamp( (.1-n.y)*3., 0., .5 ) );
				inLight += ambLightOcc * directLight;
				#endif
				*/

				float4 mat = opaqueMat( pos );
				float3 albedo = mat.rgb;
				float gloss = mat.a;

				//float3 albedo = (float3)1.2;
				//albedo.b *= .3;
				//albedo.g *= .75;
				//float gloss = 1.;// .5 + .5*sin( 2.*_Time.y );

				backCol = albedo * inLight;

				float fresnel = 1.;
				float specLightOcc = 1. - volDens;
				specLightOcc = 1.;
				backCol += gloss*specLightOcc*.3*skyColor( reflect( rd, n ) ) * lerp( 1., (1. - pow(dot( -rd, n ),2.)), fresnel );
			}

			col = lerp( backCol, col, clouds.a );
		}
	    
	    // post process
		col = clamp( col, 0., 1.);
		col = smoothstep(0.,1., col ); // Contrast
		col *= pow( 16.0*q.x*q.y*(1.0-q.x)*(1.0-q.y), 0.12 ); // Vignette

		// diagram overlay
		#ifdef DIAGRAM_OVERLAY
		float diagramPeriod = 10.;
		float diagramT = fmod( _Time.y, diagramPeriod );
		float diagram_alpha = smoothstep( .5*diagramPeriod, .55*diagramPeriod, diagramT );
		diagram_alpha *= smoothstep( diagramPeriod, .95*diagramPeriod, diagramT );
		if( diagram_alpha > 0.01 )
		{
			float3 diagram = Diagram( _CamPos, _CamForward, _CamRight, i.uv );
			col = mix( col, col * 0.6 + 0.4 * diagram, diagram_alpha );
		}
		#endif

		col.xyz = pow( col.xyz, 1 / 2.2 );
		return float4(col, 1.0);
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
