
# volsample

Research on sampling methods for real-time volume rendering

![Teaser](https://raw.githubusercontent.com/huwb/volsample/master/img/teaser.jpg)

Contacts: Huw Bowles (huw dot bowles at studiogobo dot com), Daniel Zimmermann (daniel dot zimmermann at studiogobo dot com)


## Intro

This is the source code for the course titled *A Novel Sampling Algorithm for Fast and Stable Real-Time Volume Rendering*, in the *Advances in Real-Time Rendering in Games* course at SIGGRAPH 2015 [1]. The full presentation PPT is available for download from the course page [here][ADVANCES2015] - this is the best place to start for an introduction to this project.

This research introduces three main volume sampling techniques which are described below - Forward Pinning, General Pinning and Adaptive Sampling.

There are aspects of these that are far from perfect - see notes below. We'd love to get your help to improve the techniques and the implementation!


## Running

This is implemented as a Unity 5 project and should "just work" without requiring any set up steps. This is a very convenient framework for doing this research. It provides the tweaking UI for free and affords very fast iteration.

Since publishing the Advances course [1], there is now a new implementation that supports full 3D rotations (not constrained to the flatland case). This is in the scene *Clouds3DAdvection.unity*. For the published flatland version of the algorithm, see *CloudsFlatlandAdvection.unity*.

For both scenes, once you open them you should immediately be able to move the camera around in the editor and see the effect on the advection. If you play the project, the Animator component on the camera will play our test animation if it is enabled.

There are a few small gotchas that can arise - see the Troubleshooting section below.


## Algorithm

Most of the work is performed by scripts on the *Main Camera* game object.

### Forward Pinning

This is the first part of the presentation and involves shifting the samples to compensate for camera forward motion. The forward motion is integrated in the variable `m_distTravelledForward` in *CloudsBase.cs*. Note that since the rays are scaled, this has to be taken into account when offsetting the ray steps, so the integration code takes this into account.

This is then passed into the clouds shader by *CloudsRayScales.cs*, which then shifts the raymarch step position.

### General Pinning

The core of this is an advection process used to keep sample slices stationary. The general idea is that that both sample slices are kept as close to stationary as possible when the camera moves.


#### GPU-based advection

Instead of performing the advection manually using FPI, as published in the Advances talk, I found an easier path which is to simply render the sample slice into the current frame camera view, writing each pixel depth into the new scale texture, using the shader *RenderScales.shader*. This will maintain the sample slice position across frames and extends trivially to full 3D transforms. To extend the slices, the boundary is connected with the edges of the new camera viw. Depth buffering and backface culling ensure that the correct scales are written.

This is implemented in the scene *Clouds3DAdvection.unity*. The near and far sample slice geometry are drawn in the Scene view. Note that forward pinning is performed separately from the ray scaling, so the slices move in the forward direction.


#### Fixed Point Iteration Advection

The initial published algorithm used Fixed Point Iteration (FPI) to advect the scales - for a particular angle in the final camera position (depending on which ray scale we are updating), it will provide an angle to a point on the sample slice which can then be used to compute a new scale. See [2] for more information about FPI applied to related problems.

This is implemented in the scene *CloudsFlatlandAdvection.unity*.

The two sample slices are drawn in the Editor view if `AdvectedScalesSettings.debugDrawAdvection` is true, so you can verify that they are stationary. These debug draws do not use Forward Pinning, so they will only appear stationary if you rotate and strafe the camera only.

The sample slice is extended as follows. Linear extensions are added to the sample slice based on the camera motion, and this extended slice is the one that FPI iterates over.
This means that the solution from FPI is good to go without any further treatment.
To see this set `debugFreezeAdvection` to true and then rotate the camera, to see how the slice is extended.
This works nicely for 1D scales (flatland) but difficult to implement for 2D scales (full 3D rotations).

~~It seems Unity doesn't support uploading floats to FP32 textures, so the ray scales are written onto geometry which is then rendered into a floating point texture. See *UploadRayScales.cs*. I couldn't easily get it to work with a N x 1 texture, so I'm using a N x N texture instead.~~ **WRONG** - it is possible if the type is Float ARGB. It might be useful to go back and upload the ray scales directly.


### Adaptive Sampling

The sample layout overlay (white lines on top of render) is generated by *DiagramOverlay.cs*. Note this is currently only implemented for the flatland scene - *CloudsFlatlandAdvection.unity*, due to the scales being available on the CPU.
This script contains a C# implementation of our adaptive sampling algorithm, described in our publication and illustrated [here](https://www.shadertoy.com/view/llXSD7 "Adaptive Sampling Diagram").
If you have the *Draw* and *Adaptive* options selected on this script, you should see it in action in the overlay.

Unfortunately Unity doesn't support passing arrays into shaders. For now we just compute the adaptive sampling directly in shader. It would be more efficient to upload these to a texture and read them from there.


## Troubleshooting

You may run into the following:

* If you see just the standard sky box render in the camera view, re-enable the *CloudsRayScales3D* or *CloudsRayScalesFlatland* script on the camera. if it auto disables itself when you enable it, it is likely because the shader is not building. look in the console log for shader build errors. if you don't see any you may have already cleared them - perhaps try reopening Unity.
* You may notice the sample layout changes shape slightly when the camera moves forwards/backwards. This is actually by design and is happening in the advection code (if `advectionCompensatesForwardPin` is true), and compensates for the non-trivial motion of samples when we forward pin them. Look for comments around this variable and usages of the variable in the code.


## Bugs and improvement directions

There are many directions for improving this work..

**General**

* The render breaks down when the camera is raised above the clouds etc. It would be valuable to polish this and make it work for all camera angles.
  Or to add another scene where the volume completely envelops the camera.
* The ray scale clamping works well most of the time but when transitioning straight from a strafing layout to a rotating layout, some of the ray scales get clamped and is causing some aliasing.
  I'm not sure if this is a bug or a limitation of the current clamping scheme.
* The adaptive sampling distances and weights are currently dynamically computed in the render shaders.
  It would be more efficient to upload the raymarch sample distances and weights to a texture and read them from there.
* The two render shaders share a lot of code, this could be factored out


**3D Advection - Clouds3DAdvection.unity**

* Gradient relaxation - how best to implement this for the GPU advection?
* Script execution order is generally ad hoc. The code currently reads data from the scales texture before it is updated.
  This is causing frequent pipeline stalls (see the large times in the Profiler window).
  I believe that the code should call `Camera.Render()` to make sure the scale values are set before reading them.
* It would be handy to have the sampling layout visualisation for the 3D advection, similar to the flatland scene.
  This could either be some fancy 3D visualisation of the samples, or just a cut through the scales at *rd.y == 0*.
  This needs to be implemented in the render shader as the scales live on the GPU.


**Flatland Advection - CloudsFlatlandAdvection.unity**

* Gradient relaxation is a little complicated at the moment, doing multiple passes in different directions from different starting points. I believe with experimentation this could be simplified. Also, it currently doesn't always work well enough - you can sometimes still see pinching. We may want to define a maximum gradient that is never exceeded (a hard limit instead of the current soft process).
* By freezing the advection (`debugFreezeAdvection`) and strafing the camera a lot, it can be seen that the solution from FPI starts to break down. In general this happens when the absolute gradient of the iterate approaches one [2]. This could be computed analytically and could provide a robust teleport/clear condition (instead of the current ad hoc threshold).


## References

[ADVANCES2015]: http://advances.realtimerendering.com/s2015/index.html "Advances in Real-Time Rendering - SIGGRAPH 2015"

[1] Bowles H. and Zimmermann D., *A Novel Sampling Algorithm for Fast and Stable Real-Time Volume Rendering*, Advances in Real-Time Rendering in Games course, SIGGRAPH 2015. [Course page][ADVANCES2015].

[2] Bowles H., Mitchell K., Sumner R., Moore J., Gross M., *Iterative Image Warping*, EUROGRAPHICS 2012. [Project page](https://graphics.ethz.ch/publications/papers/paperBow12.php).

[3] ShaderToy: Volume renderer with forward pinning and adaptive sampling: [Sample Pinning](https://www.shadertoy.com/view/XdfXzn)

[4] ShaderToy: Illustration of adaptive sampling: [Adaptive Sampling Diagram](https://www.shadertoy.com/view/llXSD7)
