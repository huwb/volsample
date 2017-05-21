using UnityEngine;

public class CloudsStructured3D : CloudsBase
{
	protected override void RenderSetupInternal()
	{
        if( !cloudsMaterial )
            return;

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
        if( platonicSolid && cloudsMaterial )
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
