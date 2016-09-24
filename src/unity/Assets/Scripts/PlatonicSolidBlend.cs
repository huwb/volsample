using UnityEngine;
using System.Collections;
using System.Collections.Generic;

[ExecuteInEditMode]
public class PlatonicSolidBlend : MonoBehaviour
{
    public bool updateGeometry = false;

    [Range(0,1)]
    public float bevel = 0f;

    private float oldBevel = 0f;

    [HideInInspector]
    public Mesh mesh;
	
	void Update ()
    {
        if (updateGeometry || bevel != oldBevel)
        {
            updateGeometry = false;
            oldBevel = bevel;

            mesh = new Mesh();
            mesh.name = "PlatonicSolid";
            
            // Vertex positions
            Vector3[] rawVerts = new Vector3[]
            {
                new Vector3(0.607f, 0.000f, 0.795f),    // 0
                new Vector3(0.188f, 0.577f, 0.795f),    // 1
                new Vector3(-0.491f, 0.357f, 0.795f),   // 2
                new Vector3(-0.491f, -0.357f, 0.795f),  // 3
                new Vector3(0.188f, -0.577f, 0.795f),   // 4
                new Vector3(0.982f, 0.000f, 0.188f),    // 5
                new Vector3(0.304f, 0.934f, 0.188f),    // 6
                new Vector3(-0.795f, 0.577f, 0.188f),   // 7
                new Vector3(-0.795f, -0.577f, 0.188f),  // 8
                new Vector3(0.304f, -0.934f, 0.188f),   // 9
                new Vector3(0.795f, 0.577f, -0.188f),   // 10
                new Vector3(-0.304f, 0.934f, -0.188f),  // 11
                new Vector3(-0.982f, 0.000f, -0.188f),  // 12 
                new Vector3(-0.304f, -0.934f, -0.188f), // 13
                new Vector3(0.795f, -0.577f, -0.188f),  // 14
                new Vector3(0.491f, 0.357f, -0.795f),   // 15
                new Vector3(-0.188f, 0.577f, -0.795f),  // 16
                new Vector3(-0.607f, 0.000f, -0.795f),  // 17
                new Vector3(-0.188f, -0.577f, -0.795f), // 18
                new Vector3(0.491f, -0.357f, -0.795f)   // 19
            };

            // (faceIndex, vertIndex) => index into rawVerts
            int[,] faceVertIndices = new int[,]
            {
                { 0, 1, 2, 3, 4 },      // 0
                { 0, 5, 10, 6, 1 },     // 1
                { 1, 6, 11, 7, 2 },     // 2
                { 2, 7, 12, 8, 3 },     // 3
                { 3, 8, 13, 9, 4 },     // 4
                { 4, 9, 14, 5, 0 },     // 5
                { 10, 15, 16, 11, 6 },  // 6
                { 11, 16, 17, 12, 7 },  // 7
                { 12, 17, 18, 13, 8 },  // 8
                { 13, 18, 19, 14, 9 },  // 9
                { 5, 14, 19, 15, 10 },  // 10
                { 15, 19, 18, 17, 16 }, // 11
            };

            // For each vert, shows which three faces it's a part of
            int[,] vertFaceIndices = new int[20, 3];
            for (int i=0; i<20; i++)
            {
                int idx = 0;
                for (int j=0; j<12; j++)
                {
                    for (int k=0; k<5; k++)
                    {
                        if (faceVertIndices[j,k] == i)
                        {
                            vertFaceIndices[i, idx++] = j;
                        }
                    }
                }
            }

            // Edges: (tri0, tri1, vert0, vert1)
            int[,] edges = new int[,]
            {
                { 0, 1, 0, 1 },
                { 0, 2, 1, 2 },
                { 0, 3, 2, 3 },
                { 0, 4, 3, 4 },
                { 0, 5, 4, 0 },
                { 1, 10, 5, 10 },
                { 1, 6, 10, 6 },
                { 1, 2, 1, 6 },
                { 2, 6, 6, 11 },
                { 2, 7, 11, 7 },
                { 2, 3, 7, 2 },
                { 3, 7, 7, 12 },
                { 3, 8, 12, 8 },
                { 3, 4, 8, 3 },
                { 4, 8, 8, 13 },
                { 4, 9, 13, 9 },
                { 4, 5, 9, 4 },
                { 5, 9, 9, 14 },
                { 5, 10, 14, 5 },
                { 5, 1, 5, 0 },
                { 6, 11, 15, 16 },
                { 6, 7, 16, 11 },
                { 7, 11, 16, 17 },
                { 7, 8, 17, 12 },
                { 8, 11, 17, 18 },
                { 8, 9, 18, 13 },
                { 9, 11, 18, 19 },
                { 9, 10, 19, 14 },
                { 10, 11, 19, 15 },
                { 10, 6, 15, 10 }
            };

            // Mid-point for each face
            Vector3[] faceMidPoints = new Vector3[12];
            for (int i=0; i<12; i++)
            {
                Vector3 midPoint = Vector3.zero;
                for (int j=0; j<5; j++)
                {
                    midPoint += rawVerts[faceVertIndices[i, j]];
                }

                faceMidPoints[i] = midPoint / 5f;
            }


            int nVertsTotal = 12 * 5 + 20 * 4 + 20 * 3;
            // All vertex positions
            List<Vector3> verts = new List<Vector3>(nVertsTotal);
            // All normals
            List<Vector3> normals = new List<Vector3>(nVertsTotal);
            // Three sets of uvs encode the three normals needed to blend
            List<Vector2> uvNormal0 = new List<Vector2>(nVertsTotal);
            List<Vector2> uvNormal1 = new List<Vector2>(nVertsTotal);
            List<Vector2> uvNormal2 = new List<Vector2>(nVertsTotal);
            // The vertex colors contain the blend weights in rgb
            List<Color> colors = new List<Color>(nVertsTotal);


            // The triangle indices for the faces
            List<int> faceTris = new List<int>(12 * 9);

            // Compute the faces.
            // Those have only one blend weight.
            for (int i=0; i<12; i++)
            {
                Vector3 faceMidPoint = faceMidPoints[i];
                Vector3 faceNormal = faceMidPoint.normalized;
                Vector2 uv0 = encodeNormalToUV(faceNormal);
                for (int j = 0; j < 5; j++)
                {
                    Vector3 beveledVertexPosition = faceMidPoint + (1f - bevel) * (rawVerts[faceVertIndices[i, j]] - faceMidPoint);
                    verts.Add(beveledVertexPosition);

                    normals.Add(faceNormal);

                    uvNormal0.Add(uv0);
                    uvNormal1.Add(Vector2.zero);
                    uvNormal2.Add(Vector2.zero);

                    colors.Add(new Color(1f, 0f, 0f));
                }

                faceTris.AddRange(new int[]
                {
                    5 * i + 0,
                    5 * i + 1,
                    5 * i + 2,
                    5 * i + 0,
                    5 * i + 2,
                    5 * i + 3,
                    5 * i + 0,
                    5 * i + 3,
                    5 * i + 4
                });
            }

            // Compute the bevelled edges.
            // Those have two blend weights.
            List<int> edgeTris = new List<int>(20 * 6);
            
            for (int i=0; i<edges.GetLength(0); i++)
            {
                int f0 = edges[i, 0];
                int f1 = edges[i, 1];
                int v0 = edges[i, 2];
                int v1 = edges[i, 3];

                Vector3 midPoint0 = faceMidPoints[f0];
                Vector3 midPoint1 = faceMidPoints[f1];

                Vector3 vert0 = rawVerts[v0];
                Vector3 vert1 = rawVerts[v1];

                // Build a quad with beveled vertex positions
                verts.Add(midPoint0 + (1f - bevel) * (vert0 - midPoint0));
                verts.Add(midPoint1 + (1f - bevel) * (vert0 - midPoint1));
                verts.Add(midPoint1 + (1f - bevel) * (vert1 - midPoint1));
                verts.Add(midPoint0 + (1f - bevel) * (vert1 - midPoint0));

                int i0 = verts.Count - 4;
                int i1 = verts.Count - 3;
                int i2 = verts.Count - 2;
                int i3 = verts.Count - 1;

                // Ensure ordering
                if (Vector3.Dot(Vector3.Cross(verts[i1] - verts[i0], verts[i2] - verts[i0]), vert0) < 0f)
                {
                    int tmp = i1;
                    i1 = i3;
                    i3 = tmp;
                }

                edgeTris.AddRange(new int[] { i0, i1, i2, i0, i2, i3 });
                
                // Normal
                Vector3 normal = 0.5f * (vert0 + vert1);
                normal.Normalize();
                normals.AddRange(new Vector3[] { normal, normal, normal, normal });

                // The UVs encode the sampling plane normals.
                Vector2 uv0 = encodeNormalToUV(midPoint0.normalized);
                Vector2 uv1 = encodeNormalToUV(midPoint1.normalized);

                uvNormal0.AddRange(new Vector2[] { uv0, uv0, uv0, uv0 });
                uvNormal1.AddRange(new Vector2[] { uv1, uv1, uv1, uv1 });
                uvNormal2.AddRange(new Vector2[] { Vector2.zero, Vector2.zero, Vector2.zero, Vector2.zero });

                // Blend weights are stored in the color channel
                Color c0 = new Color(1f, 0f, 0f);
                Color c1 = new Color(0f, 1f, 0f);
                colors.AddRange(new Color[] { c0, c1, c1, c0 });
            }

            // Compute the bevelled vertices.
            // Those have three blend weights.
            List<int> vertTris = new List<int>(20 * 3);
            
            for (int i=0; i<20; i++)
            {
                Vector3 normal = rawVerts[i].normalized;

                // The UVs encode the sampling plane normals.
                Vector2 uv0 = encodeNormalToUV(faceMidPoints[vertFaceIndices[i, 0]].normalized);
                Vector2 uv1 = encodeNormalToUV(faceMidPoints[vertFaceIndices[i, 1]].normalized);
                Vector2 uv2 = encodeNormalToUV(faceMidPoints[vertFaceIndices[i, 2]].normalized);

                for (int j=0; j<3; j++)
                {
                    int faceIdx = vertFaceIndices[i, j];
                    Vector3 faceMidPoint = faceMidPoints[faceIdx];

                    Vector3 beveledVertexPosition = faceMidPoint + (1f - bevel) * (rawVerts[i] - faceMidPoint);
                    verts.Add(beveledVertexPosition);

                    normals.Add(normal);

                    uvNormal0.Add(uv0);
                    uvNormal1.Add(uv1);
                    uvNormal2.Add(uv2);
                }

                // Blend weights are stored in the color channel.
                colors.Add(new Color(1f, 0f, 0f));
                colors.Add(new Color(0f, 1f, 0f));
                colors.Add(new Color(0f, 0f, 1f));

                // Indices
                int i0 = verts.Count - 3;
                int i1 = verts.Count - 2;
                int i2 = verts.Count - 1;

                // Ensure ordering
                if (Vector3.Dot (Vector3.Cross(verts[i1] - verts[i0], verts[i2] - verts[i0]), rawVerts[i]) < 0)
                {
                    int tmp = i1;
                    i1 = i2;
                    i2 = tmp;
                }

                vertTris.AddRange(new int[] { i0, i1, i2 });
            }

            // Finish setting up the mesh.
            mesh.SetVertices(verts);
            mesh.SetNormals(normals);
            mesh.SetColors(colors);
            mesh.SetUVs(0, uvNormal0);
            mesh.SetUVs(1, uvNormal1);
            mesh.SetUVs(2, uvNormal2);

            // There are three sub-meshes: Face faces, edge faces, and vertex faces.
            mesh.subMeshCount = 3;

            mesh.SetTriangles(faceTris, 0);
            mesh.SetTriangles(edgeTris, 1);
            mesh.SetTriangles(vertTris, 2);

            // If there is a mesh filter component, apply the mesh.
            var meshFilter = GetComponent<MeshFilter>();
            if (meshFilter)
                meshFilter.sharedMesh = mesh;
        }
	}

    private Vector2 encodeNormalToUV(Vector3 normal)
    {
        // "Spheremap Transform", http://aras-p.info/texts/CompactNormalStorage.html
        float f = Mathf.Sqrt(Mathf.Max(8f * normal.z + 8f, 0.001f));
        return new Vector2(normal.x, normal.y) / f + new Vector2(0.5f, 0.5f);
    }

    private Vector3 decodeNormalFromUV(Vector2 uv)
    {
        Vector2 fEnc = uv * 4f - new Vector2(2f, 2f);
        float f = Vector2.Dot(fEnc, fEnc);
        float g = Mathf.Sqrt(1f - f / 4f);

        return new Vector3(fEnc.x * g, fEnc.y * g, 1f - f / 2f);
    }
}
