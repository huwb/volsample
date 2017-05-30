using UnityEngine;

[ExecuteInEditMode]
public class SaveOutCamDepths : MonoBehaviour
{
    public Material mat;

    void Start()
    {
        GetComponent<Camera>().depthTextureMode = DepthTextureMode.Depth;
    }

    void OnRenderImage( RenderTexture source, RenderTexture destination )
    {
        if( mat != null )
        {
            Graphics.Blit( source, destination, mat );
        }
        else
        {
            Graphics.Blit( source, destination );
        }
    }
}
