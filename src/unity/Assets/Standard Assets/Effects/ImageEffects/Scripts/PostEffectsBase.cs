using UnityEngine;

namespace UnityStandardAssets.ImageEffects
{
    [ExecuteInEditMode]
    [RequireComponent (typeof(Camera))]
    public class PostEffectsBase : MonoBehaviour
	{
        protected bool  supportHDRTextures = true;
        protected bool  supportDX11 = false;
        protected bool  isSupported = true;

        protected Material CheckShaderAndCreateMaterial ( Shader s, Material m2Create)
		{
            if (!s)
			{
                Debug.Log("Missing shader in " + ToString ());
                enabled = false;
                return null;
            }

            if (s.isSupported && m2Create && m2Create.shader == s)
                return m2Create;

            if (!s.isSupported)
			{
                NotSupported ();
                Debug.Log("The shader " + s.ToString() + " on effect "+ToString()+" is not supported on this platform!");
                return null;
            }
            else
			{
                m2Create = new Material (s);
                m2Create.hideFlags = HideFlags.DontSave;
                if (m2Create)
                    return m2Create;
                else return null;
            }
        }


        protected Material CreateMaterial (Shader s, Material m2Create)
		{
            if (!s)
			{
                Debug.Log ("Missing shader in " + ToString ());
                return null;
            }

            if (m2Create && (m2Create.shader == s) && (s.isSupported))
                return m2Create;

            if (!s.isSupported)
			{
                return null;
            }
            else
			{
                m2Create = new Material (s);
                m2Create.hideFlags = HideFlags.DontSave;
                if (m2Create)
                    return m2Create;
                else return null;
            }
        }

        void OnEnable ()
		{
            isSupported = true;
        }

        protected bool CheckSupport ()
		{
            return CheckSupport (false);
        }


        public virtual bool CheckResources ()
		{
            Debug.LogWarning ("CheckResources () for " + ToString() + " should be overwritten.");
            return isSupported;
        }


        protected void Start ()
		{
            CheckResources ();
        }

        protected bool CheckSupport (bool needDepth)
		{
            isSupported = true;
            supportHDRTextures = SystemInfo.SupportsRenderTextureFormat(RenderTextureFormat.ARGBHalf);
            supportDX11 = SystemInfo.graphicsShaderLevel >= 50 && SystemInfo.supportsComputeShaders;

            if (!SystemInfo.supportsImageEffects )
			{
                NotSupported ();
                return false;
            }

            if (needDepth && !SystemInfo.SupportsRenderTextureFormat (RenderTextureFormat.Depth))
			{
                NotSupported ();
                return false;
            }

            if (needDepth)
                GetComponent<Camera>().depthTextureMode |= DepthTextureMode.Depth;

            return true;
        }

        protected bool CheckSupport (bool needDepth,  bool needHdr)
		{
            if (!CheckSupport(needDepth))
                return false;

            if (needHdr && !supportHDRTextures)
			{
                NotSupported ();
                return false;
            }

            return true;
        }


        public bool Dx11Support ()
		{
            return supportDX11;
        }


        protected void ReportAutoDisable ()
		{
            Debug.LogWarning ("The image effect " + ToString() + " has been disabled as it's not supported on the current platform.");
        }

        // deprecated but needed for old effects to survive upgrading
        bool CheckShader (Shader s)
		{
            Debug.Log("The shader " + s.ToString () + " on effect "+ ToString () + " is not part of the Unity 3.2+ effects suite anymore. For best performance and quality, please ensure you are using the latest Standard Assets Image Effects (Pro only) package.");
            if (!s.isSupported)
			{
                NotSupported ();
                return false;
            }
            else
			{
                return false;
            }
        }


        protected void NotSupported ()
		{
            enabled = false;
            isSupported = false;
            return;
        }
    }
}
