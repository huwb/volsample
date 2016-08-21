using UnityEngine;

public class CloudsStructured : CloudsBase
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
	void OnRenderImage( RenderTexture source, RenderTexture destination )
	{
		if( CheckResources() == false )
		{
			Debug.LogError("Check resources failed");

			Graphics.Blit( source, destination );
			return;
		}

		RenderSetupInternal();

		// render!
		Graphics.Blit( source, destination, cloudsMaterial, 0 );
	}
}
