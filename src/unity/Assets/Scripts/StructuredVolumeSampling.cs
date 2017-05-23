using UnityEngine;

/// <summary>
/// Drives the volume render.
/// </summary>
[ExecuteInEditMode]
[RequireComponent( typeof( Camera ), typeof( PlatonicSolidBlend ) )]
public class StructuredVolumeSampling : UnityStandardAssets.ImageEffects.PostEffectsBase
{
    public Texture2D _textureNoise;

    public Shader _volShader;
    Material _volMaterial = null;

    [Tooltip("Optional - shadow rendering camera to read shadows from.")]
    public Camera _shadowCamera;

    float _forwardMotionIntegrated = 0f;
    Vector3 _lastPos;

    public bool _structuredSampling = true;
    public bool _fixedZPinned = true;

    public enum Scene
    {
        SCENE_CLOUDS = 0,
        SCENE_SPONZA,
        SCENE_OTHER,
        SCENE_COUNT,
    }
    public Scene _scene;

    void OnEnable()
    {
        GetComponent<Camera>().depthTextureMode |= DepthTextureMode.Depth;
        _lastPos = transform.position;
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

        // TODO - put display render options

        GUI.enabled = guiEn;
    }

    void LateUpdate()
    {
        _forwardMotionIntegrated += Vector3.Dot( transform.position - _lastPos, transform.forward );
        _lastPos = transform.position;
    }

    void SetKeyword( string keyword, bool en )
    {
        if( _volMaterial == null )
            return;

        if( en )
            _volMaterial.EnableKeyword( keyword );
        else
            _volMaterial.DisableKeyword( keyword );
    }

    [ImageEffectOpaque]
    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        _volMaterial = CheckShaderAndCreateMaterial( _volShader, _volMaterial );
        SetKeyword( "STRUCTURED_SAMPLING", _structuredSampling );
        SetKeyword( "FIXEDZ_PINSAMPLES", _fixedZPinned );
        for( int i = 0; i < (int)Scene.SCENE_COUNT; i++ )
        {
            Scene scenei = (Scene)i;
            SetKeyword( scenei.ToString(), scenei == _scene );
        }

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

        // for pinned sampling
        _volMaterial.SetFloat( "_ForwardMotionIntegrated", _forwardMotionIntegrated );

        if( _shadowCamera )
        {
            _shadowCamera.ResetWorldToCameraMatrix();
            _shadowCamera.ResetProjectionMatrix();
            _volMaterial.SetMatrix( "_ShadowCameraViewMatrix", _shadowCamera.worldToCameraMatrix );
            _volMaterial.SetMatrix( "_ShadowCameraProjMatrix", _shadowCamera.projectionMatrix );
            _volMaterial.SetTexture( "_ShadowCameraDepths", _shadowCamera.targetTexture );
        }

        if( !_structuredSampling )
        {
            Graphics.Blit( source, destination, _volMaterial, 0 );
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
