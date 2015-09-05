using UnityEngine;
using System.Collections.Generic;

[ExecuteInEditMode]
public class DDASampling : MonoBehaviour
{
	public int samplesPerSliceDir = 20;
	public float rayCount = 20f;
	public float fovMult = 0.2f;
	public bool l1Sampling = false;

	void Start () {
	
	}
	
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
		List< Vector3 > samples = new List<Vector3>();

		SampleSlices( ro, rd, Vector3.right, samples );
		SampleSlices( ro, rd, Vector3.forward, samples );

		foreach( Vector3 s in samples )
			DrawSample( s );
	}

	void SampleSlices( Vector3 ro, Vector3 rd, Vector3 n, List< Vector3 > samples )
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
					samples.Add( roX + rd * t );

				t += distPerX;
			}
		}
	}
	void DrawSample( Vector3 pos )
	{
		float s = 0.2f;
		Debug.DrawLine( pos - s*Vector3.forward, pos + s*Vector3.forward );
		Debug.DrawLine( pos - s*Vector3.right, pos + s*Vector3.right );
		Debug.DrawLine( pos - s*Vector3.up, pos + s*Vector3.up );
	}
}
