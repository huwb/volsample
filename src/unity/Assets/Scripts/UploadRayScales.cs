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

// it doesnt seem to be possible to upload data from the CPU to a FP32 texture (?).
// so we're forced instead to write the values onto geometry which is then drawn
// to the texture. this setup is fiddly and brittle and would ideally just push
// values into the texture.

// also note it doesnt seem to work for non-square textures, which is why the scales
// texture is 32x32 when it would ideally be 32x1

[ExecuteInEditMode]
public class UploadRayScales : MonoBehaviour
{
	public Transform viewer;

	Mesh[] meshInstances = null;

	void LateUpdate()
	{
		AdvectedScales[] ars = viewer.GetComponents<AdvectedScales> ();
		if( ars.Length == 0 )
			return;

		// insertion sort
		for( int i = 1; i < ars.Length; i++ )
		{
			for( int j = i - 1; j >= 0; j-- )
			{
				if( ars[j].radiusIndex <= ars[j+1].radiusIndex )
					break;

				AdvectedScales temp = ars[j+1];
				ars[j+1] = ars[j];
				ars[j] = temp;
			}
		}

		MeshFilter[] meshes = GetComponentsInChildren<MeshFilter>();

		if( meshInstances == null || meshInstances.Length != meshes.Length )
		{
			meshInstances = new Mesh[meshes.Length];

			int i = 0;
			foreach( MeshFilter mf in meshes )
			{
				// this is to avoid the error about causing the mesh to instantiate in the editor - manually
				// instance the mesh in this case.
				#if UNITY_EDITOR
				if( !UnityEditor.EditorApplication.isPlaying )
					meshInstances[i++] = mf.mesh = Mesh.Instantiate(mf.sharedMesh) as Mesh;
				else
				#endif
					meshInstances[i++] = mf.mesh;
			}
		}

		int k = 0;
		foreach( Mesh mesh in meshInstances )
		{
			Vector3[] verts = mesh.vertices;
			Vector2[] uv = mesh.uv;

			for( int i = 0; i < uv.Length; i++ )
			{
				float r0 = -1;

				Vector3 pos = meshes[k].transform.TransformPoint( verts[i] );
				float theta = -CloudsBase.halfFov_horiz_rad * pos.x/5.0f + Mathf.PI/2.0f;

				r0 = ars[0].sampleR( theta ) / ars[0].radius;

				float r1;

				if( ars.Length > 1 && AdvectedScalesSettings.instance.twoRSolution )
					r1 = ars[1].sampleR( theta ) / ars[1].radius;
				else
					r1 = r0;

				uv[i] = new Vector2(r0, r1);
			}
			
			mesh.uv = uv;
			k++;
		}
	}
}
