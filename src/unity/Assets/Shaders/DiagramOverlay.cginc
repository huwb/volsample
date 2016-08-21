#define DIAGRAM_SCALE 0.015
#define DIAGRAM_PERIOD 10.

float DiagramDot( float2 pos, float2 uv )
{
	pos *= DIAGRAM_SCALE;

	float rad = 0.014;
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

float DiagramLine( vec2 p, vec2 n )
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
	uv.y += 0.2;

	// move uvs to origin, correct for aspect
	uv = 2. * uv - 1.;
	uv.x *= _ScreenParams.x / _ScreenParams.y;

	float fov = .15;

	float res = 0.;

	for( int j = -4; j <= 4; j++ )
	{
		float3 rd = fo + fov * float( j ) * ri;
		rd = normalize( rd );

		float2 t, dt, wt; float endFadeDist;
		SetupSampling( ro, rd, DIAGRAM_PERIOD, t, dt, wt, endFadeDist );
		endFadeDist = 0.6 * 14. * DIAGRAM_PERIOD;
		for( int i = 0; i < 14; i++ )
		{
			// data for next sample
			const float4 data = t.x < t.y ? float4(t.x, wt.x, dt.x, 0.0) : float4(t.y, wt.y, 0.0, dt.y); // ( t, wt, dt )
			const float w = data.y * smoothstep( endFadeDist, 0.95*endFadeDist, data.x );
			t += data.zw;

			const float2 x = float2(0., -5.)*0. + data.x * normalize( float2(fov * float( j ), 1.) );

			res = max( res, w*DiagramDot( x, uv ) );
		}
	}

	float2 lp = uv / DIAGRAM_SCALE;
	lp = lp.x * _CamRight.xz + lp.y * _CamForward.xz;
	lp += _WorldSpaceCameraPos.xz;

	float lines = 0.;
	lines = max( lines, DiagramLine( lp, float2(1., 0.) ) );
	lines = max( lines, DiagramLine( lp, float2(0., 1.) ) );
	lines = max( lines, DiagramLine( lp, float2(1., 1.) ) );
	lines = max( lines, DiagramLine( lp, float2(1., -1.) ) );

	return (float3)(res + 0.2*lines);
}
