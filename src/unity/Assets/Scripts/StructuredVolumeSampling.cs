using UnityEngine;

/// <summary>
/// Drives the volume render.
/// </summary>
[ExecuteInEditMode]
[RequireComponent( typeof( Camera ), typeof( PlatonicSolidBlend ) )]
public class StructuredVolumeSampling : UnityStandardAssets.ImageEffects.PostEffectsBase
{
    public Texture2D _textureNoise;

    public Shader _activeVolShader;
    Material _volMaterial = null;

    public Shader[] _volShaders;

    void OnEnable()
    {
        GetComponent<Camera>().depthTextureMode |= DepthTextureMode.Depth;
    }

    void OnGUI()
    {
        Color guiCol = GUI.color;
        bool guiEn = GUI.enabled;

#if UNITY_EDITOR
        // gui gets weird if you click it outside of play mode
        if( !UnityEditor.EditorApplication.isPlaying )
            GUI.enabled = false;
#endif

        float b = 5f, h = 25f;
        var rect = new Rect( b, b, 200f, h );
        for( int si = 0; si < _volShaders.Length; si++ )
        {
            var name = _volShaders[si].name;
            name = name.Substring( 1 + name.LastIndexOf( '/' ) );

            if( _volShaders[si] != _activeVolShader )
                GUI.color = Color.gray;

            if( GUI.Button( rect, name ) )
            {
                _activeVolShader = _volShaders[si];
            }

            rect.y += h + b;

            GUI.color = guiCol;
        }

        GUI.enabled = guiEn;
    }

    [ImageEffectOpaque]
    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        // if no vol shader selected, select first one
        if( _activeVolShader == null && _volShaders.Length > 0 )
        {
            _activeVolShader = _volShaders[0];
        }

        _volMaterial = CheckShaderAndCreateMaterial( _activeVolShader, _volMaterial );

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

        if( !_activeVolShader.name.ToLower().Contains( "structured" ) )
        {
            Graphics.Blit( source, destination, _volMaterial );
        }
        else
        {
            // Grab the geometry from the PlatonicSolidBlend component.
            var platonicSolid = GetComponent<PlatonicSolidBlend>();
            if( platonicSolid )
            {
                var platonicMesh = platonicSolid.mesh;

                if( platonicMesh )
                {
                    _volMaterial.SetTexture( "_MainTex", source );

                    Graphics.SetRenderTarget( destination );

                    // Pass 0: One blend weight.
                    // Draw the faces of the beveled dodecahedron.
                    _volMaterial.SetPass( 0 );
                    Graphics.DrawMeshNow( platonicMesh, Matrix4x4.identity, 0 );

                    // Pass 1: Two blend weights.
                    // Draw the edges of the beveled dodecahedron.
                    _volMaterial.SetPass( 1 );
                    Graphics.DrawMeshNow( platonicMesh, Matrix4x4.identity, 1 );

                    // Pass 2: Three blend weights.
                    // Draw the vertices of the beveled dodecahedron.
                    _volMaterial.SetPass( 2 );
                    Graphics.DrawMeshNow( platonicMesh, Matrix4x4.identity, 2 );
                }
            }
        }
    }

    static float halfFov_vert_rad  { get { return Camera.main.fieldOfView * Mathf.Deg2Rad / 2.0f; } }
    static float halfFov_horiz_rad { get { return halfFov_vert_rad * Camera.main.aspect; } }

    // Not using this.
    public override bool CheckResources() { return true; }
}
