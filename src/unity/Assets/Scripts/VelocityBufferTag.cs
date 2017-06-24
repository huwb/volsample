// Copyright (c) <2015> <Playdead>
// This file is subject to the MIT License as seen in the root of this folder structure (LICENSE.TXT)
// AUTHOR: Lasse Jon Fuglsang Pedersen <lasse@playdead.com>

using System;
using System.Collections.Generic;
using UnityEngine;

[AddComponentMenu("Playdead/VelocityBufferTag")]
public class VelocityBufferTag : MonoBehaviour
{
#if UNITY_5_6_OR_NEWER
    private static List<Vector3> temporaryVertexStorage = new List<Vector3>(512);
#endif
    public static List<VelocityBufferTag> activeObjects = new List<VelocityBufferTag>(128);

    private Transform _transform;

    [NonSerialized, HideInInspector] public SkinnedMeshRenderer meshSmr;
    [NonSerialized, HideInInspector] public bool meshSmrActive;
    [NonSerialized, HideInInspector] public Mesh mesh;
    [NonSerialized, HideInInspector] public Matrix4x4 localToWorldPrev;
    [NonSerialized, HideInInspector] public Matrix4x4 localToWorldCurr;

    private const int framesNotRenderedSleepThreshold = 60;
    private int framesNotRendered = framesNotRenderedSleepThreshold;
    public bool rendering { get { return (framesNotRendered < framesNotRenderedSleepThreshold); } }

    void Reset()
    {
        _transform = this.transform;

        var smr = GetComponent<SkinnedMeshRenderer>();
        if (smr != null)
        {
            if (mesh == null || meshSmrActive == false)
            {
                mesh = new Mesh();
                mesh.hideFlags = HideFlags.HideAndDontSave;
            }

            meshSmrActive = true;
            meshSmr = smr;
        }
        else
        {
            var mf = GetComponent<MeshFilter>();
            if (mf != null)
                mesh = mf.sharedMesh;
            else
                mesh = null;

            meshSmrActive = false;
            meshSmr = null;
        }

        // force restart
        framesNotRendered = framesNotRenderedSleepThreshold;
    }

    void Awake()
    {
        Reset();
    }

    void TagUpdate(bool restart)
    {
        if (meshSmrActive && meshSmr == null)
        {
            Reset();
        }

        if (meshSmrActive)
        {
            if (restart)
            {
                meshSmr.BakeMesh(mesh);
#if UNITY_5_6_OR_NEWER
                mesh.GetVertices(temporaryVertexStorage);
                mesh.SetNormals(temporaryVertexStorage);
#else
                mesh.normals = mesh.vertices;// garbage ahoy
#endif
            }
            else
            {
#if UNITY_5_6_OR_NEWER
                mesh.GetVertices(temporaryVertexStorage);
                meshSmr.BakeMesh(mesh);
                mesh.SetNormals(temporaryVertexStorage);
#else
                Vector3[] vs = mesh.vertices;// garbage ahoy
                meshSmr.BakeMesh(mesh);
                mesh.normals = vs;
#endif
            }
        }

        if (restart)
        {
            localToWorldCurr = _transform.localToWorldMatrix;
            localToWorldPrev = localToWorldCurr;
        }
        else
        {
            localToWorldPrev = localToWorldCurr;
            localToWorldCurr = _transform.localToWorldMatrix;
        }
    }

    void LateUpdate()
    {
        if (framesNotRendered < framesNotRenderedSleepThreshold)
        {
            framesNotRendered++;
            TagUpdate(restart: false);
        }
    }

    void OnWillRenderObject()
    {
        if (Camera.current != Camera.main)
            return;// ignore anything but main cam

        if (framesNotRendered >= framesNotRenderedSleepThreshold)
            TagUpdate(restart: true);

        framesNotRendered = 0;
    }

    void OnEnable()
    {
        activeObjects.Add(this);
    }

    void OnDisable()
    {
        activeObjects.Remove(this);

        // force restart
        framesNotRendered = framesNotRenderedSleepThreshold;
    }
}
