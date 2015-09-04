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

[RequireComponent(typeof(Camera))]
public class AdvectedScales3D : AdvectedScales
{
	public RenderTexture m_scalesTex0;
	public RenderTexture m_scalesTex1;

	[HideInInspector]
	public RenderTexture m_currentTarget;

	Material m_material = null;

	Vector3 m_lastPos;
	Vector3 m_lastForward;
	Vector3 m_lastRight;
	Vector3 m_lastUp;

	bool m_firstUpdate = true;

	void Start()
	{
		MeshRenderer mr = GetComponent<MeshRenderer>();
		if( mr )
			m_material = mr.material;

		m_lastPos = transform.position;
		m_lastForward = transform.forward;
		m_lastUp = transform.up;
		m_lastRight = transform.right;

		m_currentTarget = m_scalesTex1;
	}
	
	void LateUpdate()
	{
		SetVector( "_PrevCamPos", m_lastPos );
		SetVector( "_PrevCamForward", m_lastForward );
		SetVector( "_PrevCamUp", m_lastUp );
		SetVector( "_PrevCamRight", m_lastRight );

		SetVector( "_CamPos", transform.position );
		SetVector( "_CamForward", transform.forward );
		SetVector( "_CamUp", transform.up );
		SetVector( "_CamRight", transform.right );

		Camera cam = GetComponent<Camera>();
		float halfFovVert = 0.5f * cam.fieldOfView * Mathf.Deg2Rad;

		float radAngle = cam.fieldOfView * Mathf.Deg2Rad;
		float halfFovHorz = Mathf.Atan(Mathf.Tan(radAngle / 2) * cam.aspect);
		m_material.SetVector( "_HalfFov", new Vector4( halfFovHorz, halfFovVert, 0f, 0f ) );

		cam.targetTexture = m_currentTarget;
		RenderTexture sourceScalesTex = (m_currentTarget == m_scalesTex0) ? m_scalesTex1 : m_scalesTex0;
		if( m_currentTarget.width != sourceScalesTex.width )
			Debug.LogWarning("Two scales textures have different dimensions. Not necessarily fatal but seems odd?");

		m_material.SetTexture( "_PrevScalesTex", sourceScalesTex );
		m_material.SetFloat( "_ScalesTexSideDim", sourceScalesTex.width );

		m_material.SetFloat( "_CannonicalScale", m_radius );
		m_material.SetFloat( "_ScaleReturnAlpha", AdvectedScalesSettings.instance.alphaScaleReturnPerMeter );

		// i dont think the first update logic works because the first update happens before rendering starts or something like that?
		m_material.SetFloat( "_ClearScalesToValue", (AdvectedScalesSettings.instance.reInitScales || m_firstUpdate) ? AdvectedScalesSettings.instance.initScaleVal : -1f );
		m_firstUpdate = false;

		float pullInCam = Vector3.Dot(transform.position-m_lastPos, transform.forward);
		m_material.SetFloat( "_ForwardPinShift", pullInCam );

		// update the last cam position
		if( !AdvectedScalesSettings.instance.debugFreezeAdvection )
		{
			m_lastPos = transform.position;
			m_lastForward = transform.forward;
			m_lastUp = transform.up;
			m_lastRight = transform.right;
			
			// switch target and source
			m_currentTarget = sourceScalesTex;
		}
	}

	void SetVector( string name, Vector3 v )
	{
		m_material.SetVector( name, new Vector4( v.x, v.y, v.z, 1f ) );
	}

	public override float MiddleScaleValue {
		get {
			if( m_currentTarget == null )
				return m_radius;

			int w = m_currentTarget.width, h = m_currentTarget.height;

			// new temporary texture to read pixels
			Texture2D tex = new Texture2D( w, h, TextureFormat.RGBAFloat, false );

			// copy render target contents
			RenderTexture.active = m_currentTarget;
			tex.ReadPixels( new Rect( 0, 0, w, h ), 0, 0 );
			RenderTexture.active = null;

			// readback on cpu
			Color result = tex.GetPixelBilinear( 0.5f, 0.5f );

			// finished with texture
			DestroyImmediate( tex );

			// if scale is outside 10% to 200% of default value, return default
			float scale = result.r;
			if( scale < 0.1f * m_radius || scale > 2f * m_radius )
				scale = m_radius;

			return scale;
		}
	}
}
