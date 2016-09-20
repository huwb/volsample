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

//
// For volume render shader:
//
// https://www.shadertoy.com/view/Mt3GWs
//
// We are in the process of writing up this technique. The following github repos
// is the home of this research.
//
// https://github.com/huwb/volsample
//

#define PERIOD (30.)
#define SAMPLE_CNT 12
#define RESOLUTIONS 1
#define GRID_CONTRAST 1.5
#define PI 3.141592654

bool STRATIFIED = fract(iGlobalTime/(4.*PI))<0.5;
bool ACCUMULATE = false;

// doubles the step size, and then moves to the next line if at an 'odd' position
// TODO could this be posed as skipping the leftover to get to the next line, and therefore
// remove the code to compute ts?
void halveDensity( inout vec2 t, inout vec2 dt, vec3 ro, vec3 rd, vec3 n0, vec3 n1, vec2 dotd )
{
    dt *= 2.;
    
    vec2 doto; // normal dot ro
    doto.x = dot( n0, ro + t.x*rd );
    doto.y = dot( n1, ro + t.y*rd );
    vec2 dist = abs(doto/dotd);
    vec2 fr = fract( dist/dt );
    if( fr.x > .01 && fr.x < .99 ) t.x += .5 * dt.x;
    if( fr.y > .01 && fr.y < .99 ) t.y += .5 * dt.y;
}
float smoothbump( float r, float x )
{
    return smoothstep( r-2., r, x ) - smoothstep( r, r+2., x );
}

// to share with unity hlsl
#define float2 vec2
#define float3 vec3
#define fmod mod

void IntersectPlanes( float3 n, float3 rd, float3 ro, out float t_0, out float dt, out float wt )
{
    // step size
    float ndotrd = dot( rd, n );
    dt = PERIOD / abs( ndotrd );

    // raymarch start offset - skips leftover bit to get from ro to first strata lines
    t_0 = -fmod( dot( ro, n ), PERIOD ) / ndotrd;
    if( ndotrd > 0. ) t_0 += dt;

    // ray weight
    float minperiod = PERIOD;
    float maxperiod = .8*sqrt( 2. )*PERIOD;
    wt = smoothstep( maxperiod, minperiod, dt );
}

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
    
    // the following code computes intersections between the current ray, and a set
    // of (possibly) stationary sample planes.
    
    // this would be better computed on the VS
        
    // intersect ray with planes
    float3 n;
    
    n = abs( rd.x ) > abs( rd.z ) ? float3(1., 0., 0.) : float3(0., 0., 1.); // non diagonal
    IntersectPlanes( n, rd, ro, t.x, dt.x, wt.x );
    
    n = float3( rd.x * rd.z > 0. ? 1. : -1., 0., 1.) / sqrt(2.); // diagonal
    IntersectPlanes( n, rd, ro, t.y, dt.y, wt.y );

    wt /= (wt.x + wt.y);
}

float MarchAgainstPlanes( float t0, float dt, float wt, vec3 ro, vec3 rd, vec2 p )
{
    float t = t0;
    float res = 0.;
    
    for( int i = 0; i < SAMPLE_CNT; i++ )
    {
        vec3 pos = ro + t * rd;
        
        // render - in this case draw dots at each sample
        res = max( res, wt*smoothstep( 4., 2., length( pos.xz - p ) ) );
        
        t += dt;
    }
    
    return res;
}

vec3 Raymarch( vec3 ro, vec3 rd, vec2 p )
{
    vec3 fragColor = vec3(0.);
    
    // this intersects the ray with a set of planes (shown as lines in the diagram).
    // these calculations could be moved outside the pixel shader in normal scenarios.
    vec2 t, dt, wt;
    SetupSampling( t, dt, wt, ro, rd );
    
    if( wt.x >= 0.01 )
    {
        float march = MarchAgainstPlanes( t.x, dt.x, wt.x, ro, rd, p );
        fragColor = max( fragColor, march * .6*vec3(1.2,.2,.2) );
    }
    if( wt.y >= 0.01 )
    {
        float march = MarchAgainstPlanes( t.y, dt.y, wt.y, ro, rd, p );
        fragColor = max( fragColor, march * .6*vec3(.2,1.2,.2) );
    }
    
    return fragColor;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 p = fragCoord.xy - iResolution.xy / 2.;
    
    fragColor = vec4(0.);
    
    vec2 ro2 = 82.*vec3(cos(.5*iGlobalTime)-.01,0.,sin(.7*iGlobalTime)).xz;
    if( iMouse.z > 0. )
        ro2 = iMouse.xy - iResolution.xy/2.;
    vec3 ro = vec3(ro2.x,0.,ro2.y);
    vec3 center = 80.*vec3(cos(iGlobalTime),0.,sin(iGlobalTime));
    vec3 rd = normalize(center-ro);
    vec2 mn = vec2( -rd.z, rd.x );
    
    // cast a bunch of rays to emulate a frustum.
    float fov = 0.015;
    for( float of = -20.; of <= 20.; of += 5. )
    {
        fragColor.rgb += Raymarch( ro, rd + fov*of*float3(mn.x,0.,mn.y), p );
    }
    
    if( ACCUMULATE )
        fragColor = max( fragColor.rgba, texture2D(iChannel0,fragCoord/iResolution.xy)*.95);
    
    float maxextent = float(SAMPLE_CNT) * PERIOD;
    
    fragColor.r += .6*smoothbump( maxextent, length(p-ro.xz) );
    fragColor.b += .6*smoothbump( maxextent, length(p-ro.xz) );
    
    // viewer pos
    fragColor.g += smoothstep(4.,2.,length(ro.xz+iResolution.xy/2.-fragCoord));
    // look target
    fragColor.b += smoothstep(4.,2.,length(center.xz+iResolution.xy/2.-fragCoord));
}
