// Implementation of some different raymarch approaches

////////////////////////////////////////////////////////////////////////
// Shared - code for each raymarch step

void RaymarchStep( in float3 pos, in float dt, in float wt, inout float4 sum )
{
	if( sum.a <= 0.99 )
	{
		float4 col = VolumeSampleColor( pos );

		// dt = sqrt(dt / 5) * 5; // hack to soften and brighten
		sum += wt * dt * col * (1.0 - sum.a);
	}
}

////////////////////////////////////////////////////////////////////////
// Standard raymarching

float4 RayMarchFixedZ( in float3 ro, in float3 rd, in float zbuf )
{
	float4 sum = (float4)0.;

	// setup sampling
	float dt = SAMPLE_PERIOD, t = dt;

	for( int i = 0; i < SAMPLE_COUNT; i++ )
	{
		float distToSurf = zbuf - t;
		if( distToSurf <= 0.001 ) break;

		float wt = (distToSurf >= dt) ? 1. : distToSurf / dt;

		RaymarchStep( ro + t * rd, dt, wt, sum );

		t += dt;
	}

	return saturate( sum );
}

////////////////////////////////////////////////////////////////////////
// Standard raymarching but pinned in Z - samples move to compensate forward motion

uniform float _ForwardMotionIntegrated;

float4 RayMarchFixedZPinned( in float3 ro, in float3 rd, in float zbuf )
{
	float4 sum = (float4)0.;

	// setup sampling
	float dt = SAMPLE_PERIOD;
	float t = dt - fmod( _ForwardMotionIntegrated, dt );

	// add invisible wall at sample extents as a tool to fade samples out at distance
	zbuf = min( zbuf, dt * SAMPLE_COUNT );

	for( int i = 0; i < SAMPLE_COUNT; i++ )
	{
		float distToSurf = zbuf - t;
		if( distToSurf <= 0.001 ) break;

		float wt = (distToSurf >= dt) ? 1. : distToSurf / dt;

		RaymarchStep( ro + t * rd, dt, wt, sum );

		t += dt;
	}

	return saturate( sum );
}

////////////////////////////////////////////////////////////////////////
// Structured volume sampling

void IntersectPlanes( in float3 n, in float3 ro, in float3 rd, out float t_0, out float dt )
{
	float ndotrd = dot( rd, n );

	// raymarch step size - accounts of angle of incidence between ray and planes.
	// hb abs could be removed if all plane normals were set to always face away from viewer
	dt = SAMPLE_PERIOD / abs( ndotrd );

	// raymarch start offset - skips leftover bit to get from ro to first strata plane
	t_0 = -fmod( dot( ro, n ), SAMPLE_PERIOD ) / ndotrd;

	// fmod gives different results depending on if the arg is negative or positive. this line makes it consistent,
	// and ensures the first sample is in front of the viewer
	if( t_0 < 0. ) t_0 += dt;
}

float4 RaymarchStructured( in float3 ro, in float3 rd, in float3 n0, in float3 n1, in float3 n2, in float3 wt, in float depth, in const int RAYS )
{
	float4 sum0, sum1, sum2;
	sum0 = sum1 = sum2 = (float4)0.;

	// setup sampling
	float3 t, dt;
					IntersectPlanes( n0, ro, rd, t[0], dt[0] );
	if( RAYS > 1 )  IntersectPlanes( n1, ro, rd, t[1], dt[1] );
	if( RAYS > 2 )  IntersectPlanes( n2, ro, rd, t[2], dt[2] );

	// pretend there is an invisible wall at the end of the ray - this serves to fade samples in/out at far extent
	float3 zbuf = min( depth, dt * SAMPLE_COUNT );

	// take first sample for each plane - this sample is weighted to blend in/out. normally this would be optional, but we
	// sometimes found disturbing pentagon-shaped artifacts originating from the dodec geometry if we didn't fade these carefully.
	float3 firstWt = t / dt;
					RaymarchStep( ro + t[0] * rd, dt[0], firstWt[0], sum0 );
	if( RAYS > 1 )  RaymarchStep( ro + t[1] * rd, dt[1], firstWt[1], sum1 );
	if( RAYS > 2 )  RaymarchStep( ro + t[2] * rd, dt[2], firstWt[2], sum2 );
	t += dt;

	// take interior samples for each plane
	for( int i = 1; i < SAMPLE_COUNT; i++ )
	{
		bool stillSampling = false;

		if( RAYS > 0 )
		{
			float dts0 = zbuf[0] - t[0];
			float swt = (dts0 >= dt[0]) ? 1. : dts0 / dt[0];
			if( swt > 0.001 )
			{
				RaymarchStep( ro + t[0] * rd, dt[0], swt, sum0 );
				stillSampling = true;
			}
		}

		if( RAYS > 1 )
		{
			float dts1 = zbuf[1] - t[1];
			float swt = (dts1 >= dt[1]) ? 1. : dts1 / dt[1];
			if( swt > 0.001 )
			{
				RaymarchStep( ro + t[1] * rd, dt[1], swt, sum1 );
				stillSampling = true;
			}
		}

		if( RAYS > 2 )
		{
			float dts2 = zbuf[2] - t[2];
			float swt = (dts2 >= dt[2]) ? 1. : dts2 / dt[2];
			if( swt > 0.001 )
			{
				RaymarchStep( ro + t[2] * rd, dt[2], swt, sum2 );
				stillSampling = true;
			}
		}

		if( !stillSampling )
			break;

		t += dt;
	}

	// blend rays
	float4 sum = wt[0] * sum0;
	if( RAYS > 1 ) sum += wt[1] * sum1;
	if( RAYS > 2 ) sum += wt[2] * sum2;


	#if DEBUG_WEIGHTS
	sum.rgb *= wt.x * abs( n0 ) + wt.y * abs( n1 ) + wt.z * abs( n2 );
	#elif DEBUG_BEVEL
	if( RAYS == 1 ) sum.rb *= 0.;
	else if( RAYS == 2 ) sum.b *= 0.;
	else sum.gb *= 0.;
	#endif

	return saturate( sum );
}
