using UnityEngine;

public class CloudsStructured : CloudsBase
{
	protected override void RenderSetupInternal()
	{
		Vector4 camPos = new Vector4( transform.position.x, transform.position.y, transform.position.z, 0.0f );
		cloudsMaterial.SetVector( "_CamPos", camPos );
		
		Vector4 camForward = new Vector4( transform.forward.x, transform.forward.y, transform.forward.z, 0.0f );
		cloudsMaterial.SetVector( "_CamForward", camForward );
		Vector4 camRight = new Vector4( transform.right.x, transform.right.y, transform.right.z, 0.0f );
		cloudsMaterial.SetVector( "_CamRight", camRight );
		
		cloudsMaterial.SetTexture( "_NoiseTex", noiseTexture );
		
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
