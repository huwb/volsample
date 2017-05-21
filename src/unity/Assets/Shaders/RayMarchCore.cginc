
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

void RaymarchStep( in float3 pos, in float dt, in float wt, inout float4 sum )
{
	if( sum.a <= 0.99 )
	{
		float4 col = VolumeSampleColor( pos );

		// dt = sqrt(dt / 5) * 5; // hack to soften and brighten
		sum += wt * dt * col * (1.0 - sum.a);
	}
}

float4 RaymarchStructured( in float3 ro, in float3 rd, in float3 n0, in float3 n1, in float3 n2, in float3 wt, in const int RAYS )
{
	float4 sum0, sum1, sum2;
	sum0 = sum1 = sum2 = (float4)0.;

	// setup sampling
	float3 t, dt;
					IntersectPlanes( n0, ro, rd, t[0], dt[0] );
	if( RAYS > 1 )  IntersectPlanes( n1, ro, rd, t[1], dt[1] );
	if( RAYS > 2 )  IntersectPlanes( n2, ro, rd, t[2], dt[2] );


	// this blends samples in / out at near/far extents
	float3 firstWt = t / dt;


	// take first sample for each plane
					RaymarchStep( ro + t[0] * rd, dt[0], firstWt[0], sum0 );
	if( RAYS > 1 )  RaymarchStep( ro + t[1] * rd, dt[1], firstWt[1], sum1 );
	if( RAYS > 2 )  RaymarchStep( ro + t[2] * rd, dt[2], firstWt[2], sum2 );
	t += dt;
	

	// take interior samples for each plane
	for( int i = 1; i < SAMPLE_COUNT-1; i++ )
	{
						RaymarchStep( ro + t[0] * rd, dt[0], 1., sum0 );
		if( RAYS > 1 )  RaymarchStep( ro + t[1] * rd, dt[1], 1., sum1 );
		if( RAYS > 2 )  RaymarchStep( ro + t[2] * rd, dt[2], 1., sum2 );
		t += dt;
	}


	// take last sample for each plane
					RaymarchStep( ro + t[0] * rd, dt[0], 1.-firstWt[0], sum0 );
	if( RAYS > 1 )  RaymarchStep( ro + t[1] * rd, dt[1], 1.-firstWt[1], sum1 );
	if( RAYS > 2 )  RaymarchStep( ro + t[2] * rd, dt[2], 1.-firstWt[2], sum2 );
	t += dt;



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

float4 RayMarchFixedZ( in float3 ro, in float3 rd )
{
	float4 sum = (float4)0.;

	// setup sampling
	float dt = SAMPLE_PERIOD, t = dt;

	for( int i = 1; i < SAMPLE_COUNT - 1; i++ )
	{
		RaymarchStep( ro + t * rd, dt, 1., sum );
		t += dt;
	}

	return saturate( sum );
}
