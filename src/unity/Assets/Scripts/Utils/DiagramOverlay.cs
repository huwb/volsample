/*
The MIT License (MIT)

Copyright (c) 2015 Huw Bowles & Daniel Zimmermann

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

using UnityEngine;
using System.Collections;

[ExecuteInEditMode]
public class DiagramOverlay : MonoBehaviour {

	public bool draw = false;

	public int nSlices = 5;

	public float figureRadius = 26;

	public bool adaptive = true;

	[Tooltip("Change curve for adaptive sampling (in depth), big values concentrate samples near viewer")]
	public float samplesAdaptivity = 0.75f;
	
	AdvectedScalesSettings settings;
	
	static Material lineMaterial;
	static void CreateLineMaterial ()
	{
		if (!lineMaterial)
		{
			// Unity has a built-in shader that is useful for drawing
			// simple colored things.
			var shader = Shader.Find ("Particles/Additive");
			lineMaterial = new Material (shader);
			lineMaterial.hideFlags = HideFlags.HideAndDontSave;
			// Turn on alpha blending
			lineMaterial.SetInt ("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
			lineMaterial.SetInt ("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
			// Turn backface culling off
			lineMaterial.SetInt ("_Cull", (int)UnityEngine.Rendering.CullMode.Off);
			// Turn off depth writes
			lineMaterial.SetInt ("_ZWrite", 0);
		}
	}
	
	void Start()
	{
		settings = GetComponent<AdvectedScalesSettings> ();
	}
	
	float pdf_max( float xstart, float xend )
	{
		xstart = Mathf.Max( xstart, 0f );
		
		float sa = samplesAdaptivity;
		//sa = (Mathf.Exp(sa) - 1.0f)/Mathf.Exp(1.0f);
		sa *= sa;
		float pdfNorm = (sa/Mathf.Log(1.0f + sa*figureRadius));
		if( sa <= Mathf.Epsilon )
			pdfNorm = 1.0f / figureRadius; // singularity when adaptivity == 0 (integral is invalid)

		// we choose to use a 1/z sample distribution
		float pdf = 1f / (1f + xstart*samplesAdaptivity);
		// norm pdf
		pdf *= pdfNorm;
		
		return pdf;
	}
	
	float dens_max( float x, float dx )
	{
		return pdf_max(x,x+dx) * (float)nSlices;
	}
	
	float mod_mov( float x, float y )
	{
		CloudsRayScales crs = GetComponent<CloudsRayScales>();
		float distTravelledForward = crs ? crs.m_distTravelledForward : 0.0f;
		return Mathf.Repeat( x + distTravelledForward, y );
	}
	
	bool onBoundary( float x, float y )
	{
		// the +0.25 solves numerical issues without changing the result
		float numericalFixOffset = y*0.25f;
		return mod_mov( x + numericalFixOffset, y ) < y*0.5f;
	}

	void FirstT( out float t, out float dt, out float wt, out bool even )
	{
		if (adaptive)
		{
			t = 0f;
			float dens = dens_max( t, 0f );
			dt = Mathf.Pow ( 2f, Mathf.Floor( Mathf.Log (1f / dens) / Mathf.Log (2f) ) );
			t = 2f*dt - mod_mov(t,2f*dt);
			float fadeSpeed = 1f;
			wt = Mathf.Clamp01( fadeSpeed*(2f * dens * dt - 1f) );
			even = true;
		}
		else
		{
			dt = figureRadius / Mathf.Max ((float)nSlices, 1); // this.dt;
			float distTravelledForward = GetComponent<CloudsRayScales>().m_distTravelledForward;
			t = dt - Mathf.Repeat (distTravelledForward, dt);
			wt = 1f; // not used
			even = true; // not used
		}
	}
	void NextT( ref float t, ref float dt, ref float wt, ref bool even )
	{
		if (adaptive)
		{
			// sample at x, give weight wt
			if( even )
			{
				float dens = dens_max( t, dt * 2f );
				float nextDt, nextDens; bool nextEven;
				
				nextDt = 2f * dt;
				nextEven = onBoundary( t, nextDt*2f );
				if( nextEven )
				{
					nextDens = dens_max( t, nextDt*2f );
					if( nextDens < 0.5f / dt )
					{
						// lower sampling rate
						dt = nextDt;
						// commit to this density
						dens = nextDens;
						
						// can repeat to step down sampling rates faster
					}
				}
				
				float fadeSpeed = 1f;
				wt = Mathf.Clamp01( fadeSpeed * (2f * dens * dt - 1f) );
			}
			
			even = !even;
		}
		
		t += dt;
	}

	void OnPostRender()
	{
		if( !settings )
			return;

		if (draw)
		{
			CreateLineMaterial ();
			lineMaterial.SetPass (0);

			AdvectedScalesFlatland[] ars = GetComponents<AdvectedScalesFlatland>();
			if( ars.Length == 0 )
				return;
			
			// insertion sort
			for( int i = 1; i < ars.Length; i++ )
			{
				for( int j = i - 1; j >= 0; j-- )
				{
					if( ars[j].m_radiusIndex <= ars[j+1].m_radiusIndex )
						break;
					
					AdvectedScalesFlatland temp = ars[j+1];
					ars[j+1] = ars[j];
					ars[j] = temp;
				}
			}
			
			Quaternion q;
			
			GL.PushMatrix ();
			GL.LoadProjectionMatrix (GetComponent<Camera> ().projectionMatrix);
			
			float depth = 10f + 5f / GetComponent<Camera> ().aspect;
			float height = -5f;

			Vector3 p1 = transform.position;
			p1 = transform.TransformPoint (Quaternion.Euler (-90f, 0f, 0f) * (transform.InverseTransformPoint (p1) * 0.4f)) + depth * transform.forward + height * transform.up;

			Vector3 p2 = transform.position + Quaternion.AngleAxis (getTheta (0) * Mathf.Rad2Deg, -Vector3.up) * transform.right * (figureRadius+2f) * ars[1].scales_norm[0] * settings.debugDrawScale;
			p2 = transform.TransformPoint (Quaternion.Euler (-90f, 0f, 0f) * (transform.InverseTransformPoint (p2) * 0.4f)) + depth * transform.forward + height * transform.up;
			
			Vector3 p3 = transform.position + Quaternion.AngleAxis (getTheta (settings.scaleCount - 1) * Mathf.Rad2Deg, -Vector3.up) * transform.right * (figureRadius+2f) * ars[1].scales_norm[settings.scaleCount - 1] * settings.debugDrawScale;
			p3 = transform.TransformPoint (Quaternion.Euler (-90f, 0f, 0f) * (transform.InverseTransformPoint (p3) * 0.4f)) + depth * transform.forward + height * transform.up;
			
			
			GL.Begin (GL.LINES);
			GL.Color (Color.white);
			GL.Vertex (p1);
			GL.Vertex (p2);
			GL.Vertex (p1);
			GL.Vertex (p3);
			
			for( int i = 1; i < settings.scaleCount; i++ )
			{
				float prevTheta = getTheta(i-1);
				float thisTheta = getTheta(i);
				
				q = Quaternion.AngleAxis( prevTheta * Mathf.Rad2Deg, -Vector3.up );
				Vector3 prevRd = q * transform.right;
				
				q = Quaternion.AngleAxis( thisTheta * Mathf.Rad2Deg, -Vector3.up );
				Vector3 thisRd = q * transform.right;
				
				float scale = settings.debugDrawScale * 1.0f;

				// ray march
				float t;
				float Dt;
				float wt;
				bool even;
				FirstT (out t, out Dt, out wt, out even);

				float fadeDistance = 6f;

				for( ; t <= figureRadius + fadeDistance; )
				{
					// get current ray scale
					float prevRayScale = Mathf.Lerp( ars[0].scales_norm[i-1], ars[1].scales_norm[i-1], t/figureRadius );
					float curRayScale = Mathf.Lerp( ars[0].scales_norm[i], ars[1].scales_norm[i], t/figureRadius );

					// get scaled position
					p1 = transform.position + prevRd * t * prevRayScale * scale;
					p2 = transform.position + thisRd * t * curRayScale * scale;
					
					p1 = transform.TransformPoint (Quaternion.Euler (-90f, 0f, 0f) * (transform.InverseTransformPoint (p1) * 0.4f)) + depth * transform.forward + height * transform.up;
					p2 = transform.TransformPoint (Quaternion.Euler (-90f, 0f, 0f) * (transform.InverseTransformPoint (p2) * 0.4f)) + depth * transform.forward + height * transform.up;
					
					Color col = Color.white;
					if (adaptive)
						col.a = Mathf.Clamp01( even ? (2.0f-wt) : wt );

					if (t > fadeDistance)
						col.a *= 1f - (t - figureRadius) / fadeDistance;

					GL.Color (col);
					GL.Vertex (p1);
					GL.Vertex (p2);

					NextT (ref t, ref Dt, ref wt, ref even);
				}
			}
			GL.End ();
			GL.PopMatrix ();
		}
	}
	
	float getTheta( int i ) { return 2.0f * CloudsBase.halfFov_horiz_rad * (float)i/(float)(settings.scaleCount-1) - CloudsBase.halfFov_horiz_rad + Mathf.PI/2.0f; }
}
