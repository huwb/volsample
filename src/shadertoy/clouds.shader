/*
The MIT License (MIT)

Copyright (c) 2016 Huw Bowles, Daniel Zimmermann, Beibei Wang

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

// Example to illustrate volume sampling research undertaken right here on
// shadertoy and published at siggraph 2015:
//
// http://advances.realtimerendering.com/s2015/index.html
//
// In particular this shader demonstrates Forward Pinning and Adaptive Sampling.
// The general advection requires state and is not implemented here, see the Unity
// implementation for this:
//
// https://github.com/huwb/volsample
//
// For a diagram shader illustrating the adaptive sampling:
//
// https://www.shadertoy.com/view/llXSD7
// 
//
// Credits - this scene is mostly mash up of these two amazing shaders:
//
// Clouds by iq: https://www.shadertoy.com/view/XslGRr
// Cloud Ten by nimitz: https://www.shadertoy.com/view/XtS3DD
// 

#define SAMPLE_COUNT 32
#define MOUSEY (3.*iMouse.y/iResolution.y)
#define PERIOD 1.

// mouse toggle
bool STRATIFIED = true;

// cam moving in a straight line
vec3 lookDir = vec3(cos(.53*iGlobalTime),0.,sin(iGlobalTime));
vec3 camVel = vec3(-20.,0.,0.);
float zoom = 1.2; // 1.5;

vec3 sundir = normalize(vec3(-1.0,0.0,-1.));

// LUT based 3d value noise
float noise( in vec3 x )
{
    vec3 p = floor(x);
    vec3 f = fract(x);
    f = f*f*(3.0-2.0*f);
    
    vec2 uv = (p.xy+vec2(37.0,17.0)*p.z) + f.xy;
    vec2 rg = texture2D( iChannel0, (uv+ 0.5)/256.0, -100.0 ).yx;
    return mix( rg.x, rg.y, f.z );
}


vec4 map( in vec3 p )
{
	float d = 0.1 + .8 * sin(0.6*p.z)*sin(0.5*p.x) - p.y;

    vec3 q = p;
    float f;
    
    f  = 0.5000*noise( q ); q = q*2.02;
    f += 0.2500*noise( q ); q = q*2.03;
    f += 0.1250*noise( q ); q = q*2.01;
    f += 0.0625*noise( q );
    d += 2.75 * f;

    d = clamp( d, 0.0, 1.0 );
    
    vec4 res = vec4( d );
    
    vec3 col = 1.15 * vec3(1.0,0.95,0.8);
    col += vec3(1.,0.,0.) * exp2(res.x*10.-10.);
    res.xyz = mix( col, vec3(0.7,0.7,0.7), res.x );
    
    return res;
}


// to share with unity hlsl
#define float2 vec2
#define float3 vec3
#define fmod mod
float mysign( float x ) { return x < 0. ? -1. : 1. ; }
float2 mysign( float2 x ) { return float2( x.x < 0. ? -1. : 1., x.y < 0. ? -1. : 1. ) ; }

// compute ray march start offset and ray march step delta and blend weight for the current ray
void SetupSampling( out float2 t, out float2 dt, out float2 wt, in float3 ro, in float3 rd )
{
    if( !STRATIFIED )
    {
        dt = float2(PERIOD,PERIOD);
        t = dt;
        wt = float2(0.5,0.5);
        return;
    }
    
    // structured sampling pattern line normals
    float3 n0 = (abs( rd.x ) > abs( rd.z )) ? float3(1., 0., 0.) : float3(0., 0., 1.); // non diagonal
    float3 n1 = float3(mysign( rd.x * rd.z ), 0., 1.); // diagonal

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

vec4 raymarch( in vec3 ro, in vec3 rd )
{
    vec4 sum = vec4(0, 0, 0, 0);
    
    // setup sampling
    float2 t, dt, wt;
	SetupSampling( t, dt, wt, ro, rd );
    //t.y=12000.;
    for(int i=0; i<SAMPLE_COUNT; i++)
    {
        if( sum.a > 0.99 ) continue;

        // data for next sample
        vec4 data = t.x < t.y ? vec4( t.x, wt.x, dt.x, 0. ) : vec4( t.y, wt.y, 0., dt.y );
        // somewhat similar to: https://www.shadertoy.com/view/4dX3zl
        //vec4 data = mix( vec4( t.x, wt.x, dt.x, 0. ), vec4( t.y, wt.y, 0., dt.y ), float(t.x > t.y) );
        vec3 pos = ro + data.x * rd;
        float w = data.y;
        t += data.zw;
        
        
        vec4 col = map( pos );
        
        // iqs goodness
        float dif = clamp((col.w - map(pos+0.6*sundir).w)/0.6, 0.0, 1.0 );
        vec3 lin = vec3(0.51, 0.53, 0.63)*1.35 + 0.55*vec3(0.85, 0.57, 0.3)*dif;
        col.xyz *= lin;
        
        col.xyz *= col.xyz;
        
        col.a *= 0.35;
        col.rgb *= col.a;

        // fade samples at far field
        float fadeout = 1.;// 1.-clamp((t/(DIST_MAX*.3)-.85)/.15,0.,1.); // .3 is an ugly fudge factor due to oversampling
            
        // integrate
        //thisDt = sqrt(thisDt/5. )*5.; // hack to soften and brighten
        sum += col * (1.0 - sum.a) * fadeout * w;
    }

    sum.xyz /= (0.001+sum.w);

    return clamp( sum, 0.0, 1.0 );
}

vec3 sky( vec3 rd )
{
    vec3 col = vec3(0.);
    
    float hort = 1. - clamp(abs(rd.y), 0., 1.);
    col += 0.5*vec3(.99,.5,.0)*exp2(hort*8.-8.);
    col += 0.1*vec3(.5,.9,1.)*exp2(hort*3.-3.);
    col += 0.55*vec3(.6,.6,.9);
    
    float sun = clamp( dot(sundir,rd), 0.0, 1.0 );
    col += .2*vec3(1.0,0.3,0.2)*pow( sun, 2.0 );
    col += .5*vec3(1.,.9,.9)*exp2(sun*650.-650.);
    col += .1*vec3(1.,1.,0.1)*exp2(sun*100.-100.);
    col += .3*vec3(1.,.7,0.)*exp2(sun*50.-50.);
    col += .5*vec3(1.,0.3,0.05)*exp2(sun*10.-10.); 
    
    float ax = atan(rd.y,length(rd.xz))/1.;
    float ay = atan(rd.z,rd.x)/2.;
    float st = texture2D( iChannel0, vec2(ax,ay) ).x;
    float st2 = texture2D( iChannel0, .25*vec2(ax,ay) ).x;
    st *= st2;
    st = smoothstep(0.65,.9,st);
    col = mix(col,col+1.8*st,clamp(1.-1.1*length(col),0.,1.));
    
    return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    if( iMouse.z > 0. )
        STRATIFIED = false;
    
    vec2 q = fragCoord.xy / iResolution.xy;
    vec2 p = -1.0 + 2.0*q;
    p.x *= iResolution.x/ iResolution.y;
    vec2 mo = -1.0 + 2.0*iMouse.xy / iResolution.xy;
   
    // camera
    vec3 ro = vec3(0.,1.9,0.) + iGlobalTime*camVel;
    vec3 ta = ro + lookDir; //vec3(ro.x, ro.y, ro.z-1.);
    vec3 ww = normalize( ta - ro);
    vec3 uu = normalize(cross( vec3(0.0,1.0,0.0), ww ));
    vec3 vv = normalize(cross(ww,uu));
    vec3 rd = normalize( p.x*uu + 1.2*p.y*vv + 1.5*ww );
    
    // sky
    vec3 col = sky(rd);
    
    // divide by forward component to get fixed z layout instead of fixed dist layout
    //vec3 rd_layout = rd/mix(dot(rd,ww),1.0,samplesCurvature);
    vec4 clouds = raymarch( ro, rd );
    
    col = mix( col, clouds.xyz, clouds.w );
    
	col = clamp(col, 0., 1.);
    col = smoothstep(0.,1.,col);
	col *= pow( 16.0*q.x*q.y*(1.0-q.x)*(1.0-q.y), 0.12 ); //Vign
        
    fragColor = vec4( col, 1.0 );
}
