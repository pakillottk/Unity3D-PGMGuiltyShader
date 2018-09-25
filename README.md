# Unity3D-PGMGuiltyShader
Toon Shader for Unity3D based on the method used by Arc System Works (Guilty Gear, DB FigtherZ...)

# How to use
The shader requires three textures to work properly:
## Diffuse/Albedo Map
Regular RGB color of the surface.
## SSS Map
Defines the RGB color of the surface when it's shadowed. Acts as a translucency map.
## Combined Map
This map basically controls the light interaction.
### R channel:
Maps the per pixel Specular size.
### G channel:
Maps the per pixel Shadowing (an extra shadow light independent).
### B channel:
Maps per pixel what it's specular and what doesn't.
### A channel:
All 0 alpha pixels would be shaded as an Inner line pixel.
## EXTRA:
The R channel of the Vertex Color acts as an Ambient Occlusion adjustment. Notice that in the original technique from System Arc Works the vertex color G and B channels are used to control the LitOffset and LineThickness. In this shader, that it's not implemented yet.

All other props are self-explanatory.

# Considerations
You'll need to tweak some things in the model in order to acheive the best results:
## Normal adjustment
Transfer the normals of a low poly version of the model to your high poly to improve the shading. Some area (like character faces) could require manual adjustment of the normals to get optimal results.
## UV Mapping
For optimal inner lines consider making the line texture with totally straight lines (making all rectangles). Then get the line thickness just by adjusting the UV map of the vertex.
