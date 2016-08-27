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
// Diagram shader to accompany volume rendering research:
//
// Shader: https://www.shadertoy.com/view/Mt3GWs
// Github: https://github.com/huwb/volsample
//
//

#define PERIOD (20.)
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
    float3 n0 = abs( rd.x ) > abs( rd.z ) ? float3(1., 0., 0.) : float3(0., 0., 1.); // non diagonal
    n0 *= sqrt(2.);
    //n0 *= 2.;
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
    float maxperiod = .8*sqrt( 2. )*PERIOD;
    wt = smoothstep( maxperiod, minperiod, dt/ln );
    wt /= (wt.x + wt.y);
}

vec3 Raymarch( vec3 ro, vec3 rd, vec2 p )
{
    //rd = normalize(rd);
    
    vec3 fragColor = vec3(0.);
    
    vec2 t, dt, wt;
    SetupSampling( t, dt, wt, ro, rd );
    // if wt < eps, don't sample ray
    if( wt.x < 0.01 ) t.x = 10000.;
    if( wt.y < 0.01 ) t.y = 10000.;
    
    // interpolate between diags/nondiags based on weight
    //t.x = t.y = dot( wt, t );
    //dt.x = dt.y = dot( wt, dt );
    
    //0.5 because i call halveDensity at beginning of loop
    //dt *= 0.5;
    
    // fade samples at far extent
    float f = .6; // magic number - TODO justify this
    float endFade = f*float(SAMPLE_CNT)*PERIOD;
    float startFade = .9*endFade;

    for( int j = 0; j < RESOLUTIONS; j ++ )
    {
        //halveDensity( t, dt, ro, rd, n0, n1, dotd );
        
        for( int i = 0; i < SAMPLE_CNT; i++ )
        {
            // next sample data
            vec4 data = t.x < t.y ? vec4( t.x, wt.x, dt.x, 0. ) : vec4( t.y, wt.y, 0., dt.y );
            
            vec3 pos = ro + data.x * rd;
            float w = data.y;
            t += data.zw;
            
            // fade samples at far extent
            //w *= smoothstep( endFade, startFade, data.x );
            
            // render - in this case draw dots at each sample
            vec3 col = vec3(1.,1.,0.);
            col.xy = .8*sign(data.zw);
            //col = mix(vec3(0.,1.,0.),vec3(1.,0.,0.), float(i)/float(SAMPLE_CNT-1));
            //col /= max(col.r,col.g); // brighten up
            fragColor = max(fragColor, w*smoothstep( 4., 2., length( pos.xz - p ) ) * col);
        }
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
    
    float maxextent = float(SAMPLE_CNT) * sqrt(2.) * PERIOD;
    
    fragColor.r += .6*smoothbump( maxextent, length(p-ro.xz) );
    fragColor.b += .6*smoothbump( maxextent, length(p-ro.xz) );
    
    // viewer pos
    fragColor.g += smoothstep(4.,2.,length(ro.xz+iResolution.xy/2.-fragCoord));
    // look target
    fragColor.b += smoothstep(4.,2.,length(center.xz+iResolution.xy/2.-fragCoord));
}
