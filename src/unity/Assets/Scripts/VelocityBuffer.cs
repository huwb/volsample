// Copyright (c) <2015> <Playdead>
// This file is subject to the MIT License as seen in the root of this folder structure (LICENSE.TXT)
// AUTHOR: Lasse Jon Fuglsang Pedersen <lasse@playdead.com>

#if UNITY_5_5_OR_NEWER
#define SUPPORT_STEREO
#endif

using UnityEngine;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera), typeof(FrustumJitter))]
[AddComponentMenu("Playdead/VelocityBuffer")]
public class VelocityBuffer : EffectBase
{
#if UNITY_PS4
    private const RenderTextureFormat velocityFormat = RenderTextureFormat.RGHalf;
#else
    private const RenderTextureFormat velocityFormat = RenderTextureFormat.RGFloat;
#endif

    private Camera _camera;
    private FrustumJitter _frustumJitter;

    public Shader velocityShader;
    private Material velocityMaterial;
    private RenderTexture[] velocityBuffer;
    private RenderTexture[] velocityNeighborMax;

    private bool[] paramInitialized;
    private Vector4[] paramProjectionExtents;
    private Matrix4x4[] paramCurrV;
    private Matrix4x4[] paramCurrVP;
    private Matrix4x4[] paramPrevVP;
    private Matrix4x4[] paramPrevVP_NoFlip;

    private int activeEyeIndex = -1;
    public RenderTexture activeVelocityBuffer { get { return (activeEyeIndex != -1) ? velocityBuffer[activeEyeIndex] : null; } }
    public RenderTexture activeVelocityNeighborMax { get { return (activeEyeIndex != -1) ? velocityNeighborMax[activeEyeIndex] : null; } }

    public enum NeighborMaxSupport
    {
        TileSize10,
        TileSize20,
        TileSize40,
    };

    public bool neighborMaxGen = false;
    public NeighborMaxSupport neighborMaxSupport = NeighborMaxSupport.TileSize20;

    private float timeScaleNextFrame;
    public float timeScale { get; private set; }

#if UNITY_EDITOR
    [Header("Stats")]
    public int numResident = 0;
    public int numRendered = 0;
    public int numDrawCalls = 0;
#endif

    void Reset()
    {
        _camera = GetComponent<Camera>();
        _frustumJitter = GetComponent<FrustumJitter>();
    }

    void Clear()
    {
        EnsureArray(ref paramInitialized, 2);
        paramInitialized[0] = false;
        paramInitialized[1] = false;
    }

    void Awake()
    {
        Reset();
        Clear();
    }

    void Start()
    {
        timeScaleNextFrame = Time.timeScale;
    }

    void OnPreRender()
    {
        EnsureDepthTexture(_camera);
    }

    void OnPostRender()
    {
        EnsureArray(ref velocityBuffer, 2);
        EnsureArray(ref velocityNeighborMax, 2);

        EnsureArray(ref paramInitialized, 2, initialValue: false);
        EnsureArray(ref paramProjectionExtents, 2);
        EnsureArray(ref paramCurrV, 2);
        EnsureArray(ref paramCurrVP, 2);
        EnsureArray(ref paramPrevVP, 2);
        EnsureArray(ref paramPrevVP_NoFlip, 2);

        EnsureMaterial(ref velocityMaterial, velocityShader);
        if (velocityMaterial == null)
            return;

        timeScale = timeScaleNextFrame;
        timeScaleNextFrame = (Time.timeScale == 0.0f) ? timeScaleNextFrame : Time.timeScale;

#if SUPPORT_STEREO
        int eyeIndex = (_camera.stereoActiveEye == Camera.MonoOrStereoscopicEye.Right) ? 1 : 0;
#else
        int eyeIndex = 0;
#endif
        int bufferW = _camera.pixelWidth;
        int bufferH = _camera.pixelHeight;

        if (EnsureRenderTarget(ref velocityBuffer[eyeIndex], bufferW, bufferH, velocityFormat, FilterMode.Point, depthBits: 16))
            Clear();

        EnsureKeyword(velocityMaterial, "CAMERA_PERSPECTIVE", !_camera.orthographic);
        EnsureKeyword(velocityMaterial, "CAMERA_ORTHOGRAPHIC", _camera.orthographic);

        EnsureKeyword(velocityMaterial, "TILESIZE_10", neighborMaxSupport == NeighborMaxSupport.TileSize10);
        EnsureKeyword(velocityMaterial, "TILESIZE_20", neighborMaxSupport == NeighborMaxSupport.TileSize20);
        EnsureKeyword(velocityMaterial, "TILESIZE_40", neighborMaxSupport == NeighborMaxSupport.TileSize40);

#if SUPPORT_STEREO
        if (_camera.stereoEnabled)
        {
            for (int i = 0; i != 2; i++)
            {
                Camera.StereoscopicEye eye = (Camera.StereoscopicEye)i;

                Matrix4x4 currV = _camera.GetStereoViewMatrix(eye);
                Matrix4x4 currP = GL.GetGPUProjectionMatrix(_camera.GetStereoProjectionMatrix(eye), true);
                Matrix4x4 currP_NoFlip = GL.GetGPUProjectionMatrix(_camera.GetStereoProjectionMatrix(eye), false);
                Matrix4x4 prevV = paramInitialized[i] ? paramCurrV[i] : currV;

                paramInitialized[i] = true;
                paramProjectionExtents[i] = _camera.GetProjectionExtents(eye);
                paramCurrV[i] = currV;
                paramCurrVP[i] = currP * currV;
                paramPrevVP[i] = currP * prevV;
                paramPrevVP_NoFlip[i] = currP_NoFlip * prevV;
            }
        }
        else
#endif
        {
            Matrix4x4 currV = _camera.worldToCameraMatrix;
            Matrix4x4 currP = GL.GetGPUProjectionMatrix(_camera.projectionMatrix, true);
            Matrix4x4 currP_NoFlip = GL.GetGPUProjectionMatrix(_camera.projectionMatrix, false);
            Matrix4x4 prevV = paramInitialized[0] ? paramCurrV[0] : currV;

            paramInitialized[0] = true;
            paramProjectionExtents[0] = _frustumJitter.enabled ? _camera.GetProjectionExtents(_frustumJitter.activeSample.x, _frustumJitter.activeSample.y) : _camera.GetProjectionExtents();
            paramCurrV[0] = currV;
            paramCurrVP[0] = currP * currV;
            paramPrevVP[0] = currP * prevV;
            paramPrevVP_NoFlip[0] = currP_NoFlip * prevV;
        }

        RenderTexture activeRT = RenderTexture.active;
        RenderTexture.active = velocityBuffer[eyeIndex];
        {
            GL.Clear(true, true, Color.black);

            const int kPrepass = 0;
            const int kVertices = 1;
            const int kVerticesSkinned = 2;
            const int kTileMax = 3;
            const int kNeighborMax = 4;

            // 0: prepass
#if SUPPORT_STEREO
            velocityMaterial.SetVectorArray("_ProjectionExtents", paramProjectionExtents);
            velocityMaterial.SetMatrixArray("_CurrV", paramCurrV);
            velocityMaterial.SetMatrixArray("_CurrVP", paramCurrVP);
            velocityMaterial.SetMatrixArray("_PrevVP", paramPrevVP);
            velocityMaterial.SetMatrixArray("_PrevVP_NoFlip", paramPrevVP_NoFlip);
#else
            velocityMaterial.SetVector("_ProjectionExtents", paramProjectionExtents[0]);
            velocityMaterial.SetMatrix("_CurrV", paramCurrV[0]);
            velocityMaterial.SetMatrix("_CurrVP", paramCurrVP[0]);
            velocityMaterial.SetMatrix("_PrevVP", paramPrevVP[0]);
            velocityMaterial.SetMatrix("_PrevVP_NoFlip", paramPrevVP_NoFlip[0]);
#endif
            velocityMaterial.SetPass(kPrepass);
            DrawFullscreenQuad();

            // 1 + 2: vertices + vertices skinned
            var obs = VelocityBufferTag.activeObjects;
#if UNITY_EDITOR
            numResident = obs.Count;
            numRendered = 0;
            numDrawCalls = 0;
#endif
            for (int i = 0, n = obs.Count; i != n; i++)
            {
                var ob = obs[i];
                if (ob != null && ob.rendering && ob.mesh != null)
                {
                    velocityMaterial.SetMatrix("_CurrM", ob.localToWorldCurr);
                    velocityMaterial.SetMatrix("_PrevM", ob.localToWorldPrev);
                    velocityMaterial.SetPass(ob.meshSmrActive ? kVerticesSkinned : kVertices);

                    for (int j = 0; j != ob.mesh.subMeshCount; j++)
                    {
                        Graphics.DrawMeshNow(ob.mesh, Matrix4x4.identity, j);
#if UNITY_EDITOR
                        numDrawCalls++;
#endif
                    }
#if UNITY_EDITOR
                    numRendered++;
#endif
                }
            }

            // 3 + 4: tilemax + neighbormax
            if (neighborMaxGen)
            {
                int tileSize = 1;

                switch (neighborMaxSupport)
                {
                    case NeighborMaxSupport.TileSize10: tileSize = 10; break;
                    case NeighborMaxSupport.TileSize20: tileSize = 20; break;
                    case NeighborMaxSupport.TileSize40: tileSize = 40; break;
                }

                int neighborMaxW = bufferW / tileSize;
                int neighborMaxH = bufferH / tileSize;

                EnsureRenderTarget(ref velocityNeighborMax[eyeIndex], neighborMaxW, neighborMaxH, velocityFormat, FilterMode.Bilinear);

                // tilemax
                RenderTexture tileMax = RenderTexture.GetTemporary(neighborMaxW, neighborMaxH, 0, velocityFormat);
                RenderTexture.active = tileMax;
                {
                    velocityMaterial.SetTexture("_VelocityTex", velocityBuffer[eyeIndex]);
                    velocityMaterial.SetVector("_VelocityTex_TexelSize", new Vector4(1.0f / bufferW, 1.0f / bufferH, 0.0f, 0.0f));
                    velocityMaterial.SetPass(kTileMax);
                    DrawFullscreenQuad();
                }

                // neighbormax
                RenderTexture.active = velocityNeighborMax[eyeIndex];
                {
                    velocityMaterial.SetTexture("_VelocityTex", tileMax);
                    velocityMaterial.SetVector("_VelocityTex_TexelSize", new Vector4(1.0f / neighborMaxW, 1.0f / neighborMaxH, 0.0f, 0.0f));
                    velocityMaterial.SetPass(kNeighborMax);
                    DrawFullscreenQuad();
                }

                RenderTexture.ReleaseTemporary(tileMax);
            }
            else
            {
                ReleaseRenderTarget(ref velocityNeighborMax[0]);
                ReleaseRenderTarget(ref velocityNeighborMax[1]);
            }
        }
        RenderTexture.active = activeRT;

        activeEyeIndex = eyeIndex;
    }

    void OnApplicationQuit()
    {
        if (velocityBuffer != null)
        {
            ReleaseRenderTarget(ref velocityBuffer[0]);
            ReleaseRenderTarget(ref velocityBuffer[1]);
        }
        if (velocityNeighborMax != null)
        {
            ReleaseRenderTarget(ref velocityNeighborMax[0]);
            ReleaseRenderTarget(ref velocityNeighborMax[1]);
        }
    }
}