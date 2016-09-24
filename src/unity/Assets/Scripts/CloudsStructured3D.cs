/*
The MIT License (MIT)

Copyright (c) 2016 Huw Bowles, Daniel Zimmermann, Beibei Wang

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

public class CloudsStructured3D : CloudsBase
{
	protected override void RenderSetupInternal()
	{
        // we can't just read these from the matrices because the clouds are rendered with a post proc camera
		cloudsMaterial.SetVector( "_CamPos", transform.position );
		cloudsMaterial.SetVector( "_CamForward", transform.forward );
		cloudsMaterial.SetVector( "_CamRight", transform.right );
		
        // noise texture
		cloudsMaterial.SetTexture( "_NoiseTex", noiseTexture );
		
        // for generating rays
		cloudsMaterial.SetFloat( "_HalfFov", halfFov_horiz_rad );
	}

    [ImageEffectOpaque]
    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (CheckResources() == false)
        {
            Debug.LogError("Check resources failed");

            Graphics.Blit(source, destination);
            return;
        }

        RenderSetupInternal();

        // Grab the geometry from the PlatonicSolidBlend component.
        var platonicSolid = GetComponent<PlatonicSolidBlend>();
        if (platonicSolid)
        {
            var platonicMesh = platonicSolid.mesh;

            if (platonicMesh)
            {
                Graphics.SetRenderTarget(destination);

                // Pass 0: One blend weight.
                // Draw the faces of the beveled dodecahedron.
                cloudsMaterial.SetPass(0);
                Graphics.DrawMeshNow(platonicMesh, Matrix4x4.identity, 0);

                // Pass 1: Two blend weights.
                // Draw the edges of the beveled dodecahedron.
                cloudsMaterial.SetPass(1);
                Graphics.DrawMeshNow(platonicMesh, Matrix4x4.identity, 1);

                // Pass 2: Three blend weights.
                // Draw the vertices of the beveled dodecahedron.
                cloudsMaterial.SetPass(2);
                Graphics.DrawMeshNow(platonicMesh, Matrix4x4.identity, 2);
            }
        }
    }
}
