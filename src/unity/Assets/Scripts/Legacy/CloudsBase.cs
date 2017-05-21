using UnityEngine;

[ExecuteInEditMode]
[RequireComponent (typeof (Camera))]
public abstract class CloudsBase : UnityStandardAssets.ImageEffects.PostEffectsBase
{
	public Shader cloudsShader;
	protected Material cloudsMaterial = null;
	public Texture2D noiseTexture;

	public override bool CheckResources()
	{
		cloudsMaterial = CheckShaderAndCreateMaterial( cloudsShader, cloudsMaterial );

        return true;
	}
	
	void OnEnable()
	{
		SetCameraFlag();
	}
	
	void SetCameraFlag()
	{
		GetComponent<Camera>().depthTextureMode |= DepthTextureMode.Depth;
	}
	
	public static float halfFov_horiz_rad
	{
		get
		{
			return Camera.main.aspect * Camera.main.fieldOfView * Mathf.Deg2Rad / 2.0f;
		}
	}

	public static float halfFov_vert_rad
	{
		get
		{
			return Camera.main.fieldOfView * Mathf.Deg2Rad / 2.0f;
		}
	}

    protected virtual void RenderSetupInternal()
    {
    }
}
