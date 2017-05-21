using UnityEngine;

[ExecuteInEditMode]
[RequireComponent( typeof( Camera ), typeof( PlatonicSolidBlend ) )]
public class StructuredVolumeSampling : UnityStandardAssets.ImageEffects.PostEffectsBase
{
    public Texture2D _textureNoise;

    public Shader _volShader;
    Material _volMaterial = null;

    void OnEnable()
    {
        GetComponent<Camera>().depthTextureMode |= DepthTextureMode.Depth;
    }

    [ImageEffectOpaque]
    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        _volMaterial = CheckShaderAndCreateMaterial( _volShader, _volMaterial );

        // check for no shader / shader compile error
        if( _volMaterial == null )
        {
            Graphics.Blit(source, destination);
            return;
        }

        // we can't just read these from the matrices because the clouds are rendered with a post proc camera
        _volMaterial.SetVector( "_CamPos", transform.position );
        _volMaterial.SetVector( "_CamForward", transform.forward );
        _volMaterial.SetVector( "_CamRight", transform.right );

        // noise texture
        _volMaterial.SetTexture( "_NoiseTex", _textureNoise );

        // for generating rays
        _volMaterial.SetFloat( "_HalfFov", halfFov_horiz_rad );

        // Grab the geometry from the PlatonicSolidBlend component.
        var platonicSolid = GetComponent<PlatonicSolidBlend>();
        if( platonicSolid )
        {
            var platonicMesh = platonicSolid.mesh;

            if (platonicMesh)
            {
                Graphics.SetRenderTarget(destination);

                // Pass 0: One blend weight.
                // Draw the faces of the beveled dodecahedron.
                _volMaterial.SetPass(0);
                Graphics.DrawMeshNow(platonicMesh, Matrix4x4.identity, 0);

                // Pass 1: Two blend weights.
                // Draw the edges of the beveled dodecahedron.
                _volMaterial.SetPass(1);
                Graphics.DrawMeshNow(platonicMesh, Matrix4x4.identity, 1);

                // Pass 2: Three blend weights.
                // Draw the vertices of the beveled dodecahedron.
                _volMaterial.SetPass(2);
                Graphics.DrawMeshNow(platonicMesh, Matrix4x4.identity, 2);
            }
        }
    }

    static float halfFov_vert_rad  { get { return Camera.main.fieldOfView * Mathf.Deg2Rad / 2.0f; } }
    static float halfFov_horiz_rad { get { return halfFov_vert_rad * Camera.main.aspect; } }

    // Not using this.
    public override bool CheckResources() { return true; }
}
