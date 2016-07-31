using UnityEngine;
using System.Collections.Generic;

[ExecuteInEditMode]
public class DDASampling : MonoBehaviour
{
    struct Sample
    {
        public Vector3 pos;
        public float alpha;
    }

	public int samplesPerSliceDir = 20;
	public float rayCount = 20f;
	public float fovMult = 0.2f;
	public bool l1Sampling = false;

	void Update()
	{
		for( float i = 0f; i < rayCount; i += 1f )
		{
			float x = (i-rayCount/2f)*fovMult;
			Vector3 rd = transform.forward + x * transform.right;
			SampleRay( transform.position, rd );
		}
		//DrawSample( transform.position + 3f * transform.forward );
	}

	void SampleRay( Vector3 ro, Vector3 rd )
	{
		List<Sample> samples = new List<Sample>();

		SampleSlices( ro, rd, Vector3.right, samples );
		SampleSlices( ro, rd, Vector3.forward, samples );

		foreach( var s in samples )
			DrawSample( s );
	}

	void SampleSlices( Vector3 ro, Vector3 rd, Vector3 n, List<Sample> samples )
	{
		float dpDir = Vector3.Dot( rd, n );
		if( Mathf.Abs( dpDir ) > Mathf.Epsilon )
		{
			float dpOri = Vector3.Dot( ro, n );
			float distPerX = Mathf.Abs( 1.0f / dpDir );
			float firstIntX = Mathf.Ceil( dpOri - 1f );
			Vector3 roX = ro + (dpOri-firstIntX) * distPerX * rd;
			float t = 1f * distPerX;
			for( int i = 0; i < samplesPerSliceDir; i++ )
			{
				bool takeIt = !l1Sampling || Mathf.Abs(dpDir) > 1f/Mathf.Sqrt(2f);

				if( takeIt )
                {
                    Sample smp;
                    smp.pos = roX + rd * t;
                    smp.alpha = Mathf.Abs( Vector3.Dot( rd, n ) );
                    float bp = 0.6f;
                    smp.alpha = Mathf.Clamp01( (smp.alpha - bp) / (1f - bp) );
                    //smp.alpha *= smp.alpha*smp.alpha;
                    samples.Add( smp );
                }

                t += distPerX;
			}
		}
	}

	void DrawSample( Sample smp )
	{
        Vector3 pos = smp.pos;
        Color c = new Color( 1f, 1f, 1f, smp.alpha );

		float s = 0.2f;
		Debug.DrawLine( pos - s*Vector3.forward, pos + s*Vector3.forward, c );
		Debug.DrawLine( pos - s*Vector3.right, pos + s*Vector3.right, c );
		Debug.DrawLine( pos - s*Vector3.up, pos + s*Vector3.up, c );
	}
}
