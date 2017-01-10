
void IntersectPlanes( in float3 n, in float3 ro, in float3 rd, out float t_0, out float dt )
{
	float ndotrd = dot( rd, n );

	// raymarch step size - accounts of angle of incidence between ray and planes.
	// hb i tried to remove the abs but it appears some normals are uploaded the wrong way.
	dt = SAMPLE_PERIOD / abs( ndotrd );

	// raymarch start offset - skips leftover bit to get from ro to first strata plane
	t_0 = dt - fmod( dot( ro, n ), SAMPLE_PERIOD ) / ndotrd;

	//float2 result = float2( SAMPLE_PERIOD, SAMPLE_PERIOD - fmod( dot( ro, n ), SAMPLE_PERIOD ) );
	//result /= dot( rd, n );
	//dt = result.x; t_0 = result.y;
}

void IntegrateColor( in float4 col, in float dt, inout float4 sum )
{
	// dt = sqrt(dt / 5) * 5; // hack to soften and brighten
	sum += dt * col * (1.0 - sum.a);
}

float4 DoRaymarch( in float3 ro, in float3 rd, in float3 n0, in float3 n1, in float3 n2, in float3 wt, in const int RAYS )
{
	float4 sum = (float4)0.;
	float4 sum1 = sum;
	float4 sum2 = sum;

	// setup sampling
	float3 t, dt;
	IntersectPlanes( n0, ro, rd, t.x, dt.x );
	if( RAYS > 1 ) IntersectPlanes( n1, ro, rd, t.y, dt.y );
	if( RAYS > 2 ) IntersectPlanes( n2, ro, rd, t.z, dt.z );

	for( int i = 0; i<SAMPLE_COUNT; i++ )
	{
		// get the sampling positions and move on
		float3 pos0 = ro + t.x * rd;

		if( sum.a <= 0.99 )
		{
			float4 col = VolumeSampleColor( pos0 );
			IntegrateColor( col, dt.x, sum );
		}

		if( RAYS > 1 )
		{
			float3 pos1 = ro + t.y * rd;
			if( sum1.a <= 0.99 )
			{
				float4 col = VolumeSampleColor( pos1 );
				IntegrateColor( col, dt.y, sum1 );
			}
		}

		if( RAYS > 2 )
		{
			float3 pos2 = ro + t.z * rd;
			if( sum2.a <= 0.99 )
			{
				float4 col = VolumeSampleColor( pos2 );
				IntegrateColor( col, dt.z, sum2 );
			}
		}

		t += dt;
	}

	// blend rays
	sum = wt.x * sum;
	if( RAYS > 1 ) sum += wt.y * sum1;
	if( RAYS > 2 ) sum += wt.z * sum2;


	#if DEBUG_WEIGHTS
	sum.rgb *= wt.x * abs( n0 ) + wt.y * abs( n1 ) + wt.z * abs( n2 );
	#elif DEBUG_BEVEL
	sum *= float4(1, 0, 0, 1);
	#endif

	return saturate( sum );
}
