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

[RequireComponent(typeof(MeshFilter))]
public class ScaleRasterMeshBuilder : MonoBehaviour
{
	MeshFilter m_mf;

	void Start()
	{
		m_mf = GetComponent<MeshFilter>();

		BuildMesh();
	}

	int meshN {
		get {
			return AdvectedScalesSettings.instance.scaleCount+2;
		}
	}

	int toArr_v( int i, int j )
	{
		return j*meshN + i;
	}

	int toArr_i( int i, int j, int tri, int vert )
	{
		return (j*(meshN-1) + i)*6 + tri*3 + vert;
	}

	void BuildMesh()
	{
		m_mf.mesh = Mesh.Instantiate(m_mf.mesh);

		float fN = (float)(AdvectedScalesSettings.instance.scaleCount);
		float fMN = (float)(meshN);
		float eps = 0.001f;

		Vector3[] verts = new Vector3[meshN*meshN];
		int[] indices = new int[ (meshN-1)*(meshN-1) * 2 * 3 ]; // ((N+2)-1)^2 quads, 2 tris, 3 indices per tri
		Vector2[] uvs = new Vector2[meshN*meshN];

		for( int j = 0; j < meshN; j++ )
		{
			float y = ((float)j+0.5f) - fMN/2f;
			//y *= (fN - 1f)/fN;
			y += Mathf.Sign( y ) * eps;
			float uvy = (0.5f+(float)(j-1))/fN;

			if( j == 0 || j == meshN-1 )
			{
				y *= 4f;
				uvy = (j == 0) ? 0f : 1f;
			}

			for( int i = 0; i < meshN; i++ )
			{
				float x = ((float)i+0.5f) - fMN/2f;
				//x *= (fN - 1f)/fN;
				x += Mathf.Sign( x ) * eps;

				float uvx = (0.5f+(float)(i-1))/fN;
				if( i == 0 || i == meshN-1 )
				{
					x *= 4f;
					uvx = (i == 0) ? 0f : 1f;
				}

				// important to have this > 0. when this is 0, mesh bounds means that the mesh won't render when the geometry
				// is on the same game object as the camera
				float z = 3f;

				int ind = toArr_v( i, j );

				verts[ind].x = x;
				verts[ind].y = y;
				verts[ind].z = z;

				// sorry for the hack here. im sure there's a good explanation for this!
				uvs[ind].x = 1f - uvx;
				uvs[ind].y = uvy;

				if( i < meshN-1 && j < meshN-1 )
				{
					indices[ toArr_i(i,j,1,2) ] = toArr_v(i+1,j+1);
					indices[ toArr_i(i,j,1,1) ] = toArr_v(i+1,j);
					indices[ toArr_i(i,j,1,0) ] = toArr_v(i  ,j+1);

					indices[ toArr_i(i,j,0,2) ] = toArr_v(i  ,j);
					indices[ toArr_i(i,j,0,0) ] = toArr_v(i+1,j);
					indices[ toArr_i(i,j,0,1) ] = toArr_v(i  ,j+1);
				}
			}
		}

		m_mf.mesh.vertices = verts;
		m_mf.mesh.SetIndices( indices, MeshTopology.Triangles, 0 );
		m_mf.mesh.uv = uvs;

		m_mf.mesh.RecalculateNormals();

		// necessary?
		//m_mf.mesh.RecalculateBounds();
	}

	void Update () {
		
	}
}
