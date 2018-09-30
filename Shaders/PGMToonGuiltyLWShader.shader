Shader "LightweightPipeline/Toon/PGMToonGuiltyLWShader"
{
    Properties
    {
		_LitOffset("Lit offset", Range(0,1)) = 0.3
		_HighLitOffset("HighLights Lit offset", Range(0,1)) = 0.3
        _Color("Color", Color) = (0.5,0.5,0.5,1)
        _MainTex("Albedo", 2D) = "white" {}
		_SSSTex("SSS Map", 2D) = "black" {}
		_SSSColor("SSS Color", Color) = (1,1,1,1)
		_CombMap("Comb Map", 2D) = "white" {}
		_SpecularPower("Specular Power", Range(0,100)) = 20.0
		_SpecularColor("Specular Color", Color) = (1,1,1,1)
		_SpecularScale("Specular Scale", Range(0,10)) = 1.0
		_OutlineColor("Outline Color", Color) = (0,0,0,1)
		_OutlineThickness("Outline Thickness", Range(0,1)) = 0.3
    }

    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "LightweightPipeline" "IgnoreProjector" = "True"}
        LOD 300

		//Outline pass
		Pass {
			Cull Front

			Name "OutlinePass"
            Tags{ "Outlines" = "ToonOutline"}


			HLSLPROGRAM
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

			#pragma vertex vert
			#pragma fragment frag

			#include "LWRP/ShaderLibrary/Core.hlsl"

			half4 _OutlineColor;
			half _OutlineThickness;

			struct VertexInput
            {
                float4 vertex       : POSITION;
                float3 normal       : NORMAL;
            };

			struct VertexOutput
            {
                float4 clipPos	: SV_POSITION;
            };

			            
            VertexOutput vert (VertexInput v)
            {
                VertexOutput o = (VertexOutput)0;
                float3 worldPos = TransformObjectToWorld(v.vertex.xyz + normalize(v.normal)*(_OutlineThickness/100));
				o.clipPos = TransformWorldToHClip(worldPos); 
                return o;
            }
            
            half4 frag (VertexOutput i) : SV_Target
            {
                return _OutlineColor;
            }
			ENDHLSL
		}

        Pass
        {
            Name "ToonLit"
            Tags{ "LightMode" = "LightweightForward" }

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard SRP library
            // All shaders must be compiled with HLSLcc and currently only gles is not using HLSLcc by default
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0
			
            // -------------------------------------
            // Lightweight Pipeline keywords
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _VERTEX_LIGHTS
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
            #pragma multi_compile _ _SHADOWS_ENABLED
            #pragma multi_compile _ _LOCAL_SHADOWS_ENABLED
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _SHADOWS_CASCADE			

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex ToonPassVertex
            #pragma fragment ToonPassFragment

			#include "LWRP/ShaderLibrary/Core.hlsl"
            #include "LWRP/ShaderLibrary/Lighting.hlsl"

            struct VertexInput
            {
                float4 vertex       : POSITION;
                float3 normal       : NORMAL;
                float2 texcoord     : TEXCOORD0;
				float4 vertColor    : COLOR;
            };

            struct VertexOutput
            {
                float2 uv                       : TEXCOORD0;
                float3 positionWS				: TEXCOORD2;
                half3  normal                   : TEXCOORD3;
				half3 vertexColor				: TEXCOORD4;
				#ifdef _SHADOWS_ENABLED
					float4 shadowCoord          : TEXCOORD6;
				#endif
                float4 clipPos                  : SV_POSITION;
            };			

            VertexOutput ToonPassVertex(VertexInput v)
            {
                VertexOutput o = (VertexOutput)0;

				o.vertexColor = v.vertColor.rgb;
				o.uv = v.texcoord.xy;
				
                o.positionWS = TransformObjectToWorld(v.vertex.xyz);
                o.clipPos = TransformWorldToHClip(o.positionWS); 

                o.normal = TransformObjectToWorldNormal(v.normal);

				#ifdef _SHADOWS_ENABLED
					#if SHADOWS_SCREEN
						o.shadowCoord = ComputeShadowCoord(o.clipPos);
					#else
						o.shadowCoord = TransformWorldToShadowCoord(o.positionWS);
					#endif
				#endif

				return o;
            }

			//our mapped properties
			sampler2D _MainTex;
			sampler2D _SSSTex;
			sampler2D _CombMap;
			half3 _Color;
			half3 _SSSColor;
			half _LitOffset;
			half _HighLitOffset;
			half _SpecularPower;
			half3 _SpecularColor;
			half _SpecularScale;

			//Compact struct to store all the relevant data to calc
			//our lighting
			struct ToonSurfaceData {
				float3 albedo;
				float3 sss;
				float Glossy;
				float Glossiness;
				float Shadow;
				float InnerLine;
				float Oc;
			};
			//Relevant information of the light calculations. In this case,
			//our diffuse and specular colors.
			struct ToonShadedData {
				float3 difColor;
				float3 specColor;
			};

			/*
				Calculates the diffuse and specular light of the fragment and add it to the difColor and specColor.
			*/
			ToonShadedData CalcToonLight(ToonShadedData o, Light light, ToonSurfaceData s, float3 normalWS, float3 viewDirectionWS)
			{
				//Diffuse light: normal dot lightDirection * the attenuation of light (spot angle, etc.) and our custom
				//vertex occlusion and shadow texture
				float diffuse = saturate(dot(normalWS, light.direction)) * light.attenuation * s.Shadow * s.Oc;

				//Discretization of the diffuse component
				diffuse = step(_LitOffset, diffuse);

				//add it to the difColor. Notice that in the shadows (diffuse = 0) we use s.albedo * s.sss to
				//avoid a total dark color.
				o.difColor += lerp( s.albedo * s.sss, s.albedo, diffuse) * light.color;

				//Specular light: (R dot normal)^SpecularPower * the attenuation of light (spot angle, etc.) and our custom
				//vertex occlusion and shadow texture
				float specular = pow(max(0, dot(reflect(-light.direction, normalWS), viewDirectionWS)), s.Glossiness * _SpecularPower) 
								* light.attenuation * s.Shadow * s.Oc; 

				//Discretization of the specular component
				specular = step(_HighLitOffset, specular);

				//add it to the specColor. Notice that we multiply the Glossy value from our texture along
				//a customizable tint and scale.
				o.specColor += specular * s.Glossy * _SpecularColor * light.color * _SpecularScale;

				//returns the updated colors
				return o;
			}

			//Creates and populates our surface with the props and textures
			ToonSurfaceData InitializeToonSurface(VertexOutput IN)
			{
				ToonSurfaceData s;

				half4 comb = tex2D(_CombMap, IN.uv);

				s.albedo = tex2D(_MainTex, IN.uv).rgb * _Color; 
				s.sss = tex2D(_SSSTex, IN.uv).rgb * _SSSColor;
				s.Glossy = comb.r;
				s.Glossiness = comb.b;
				s.Shadow = comb.g;
				s.InnerLine = comb.a;
				s.Oc = step(0.9, IN.vertexColor.r);

				return s;
			}

            half4 ToonPassFragment(VertexOutput IN) : SV_Target
            {				
				//get the surface data
                ToonSurfaceData s = InitializeToonSurface(IN);				
				//get the normal (renormalize to avoid interpolation issues)
                half3 normalWS = normalize(IN.normal);
				//get our view direction
                float3 positionWS = IN.positionWS;
                half3 viewDirectionWS = SafeNormalize(GetCameraPositionWS() - positionWS);

				//Initialize our colors. We start at black, then we'll accum the results of each
				//light
				ToonShadedData finalColors;
				finalColors.difColor = half3(0,0,0);
				finalColors.specColor = half3(0,0,0);

			   //Starts with the brighter directional light (MainLight)
			   /*
					Note: Light it's an useful struct with the position, direction, attenuation and color of the Light
			   */
               Light mainLight = GetMainLight();
			   //We let the builtin funcs to take care of the shadows
				#ifdef _SHADOWS_ENABLED
					mainLight.attenuation = MainLightRealtimeShadowAttenuation(IN.shadowCoord);
				#endif
				//Call our lighting function and store the updated colors
				finalColors = CalcToonLight(finalColors, mainLight, s, normalWS, viewDirectionWS);

				//Now for each other light, we repeat the exact same process
				#ifdef _ADDITIONAL_LIGHTS
					int pixelLightCount = GetPixelLightCount();
					for (int i = 0; i < pixelLightCount; ++i)
					{
						Light light = GetLight(i, positionWS);
						light.attenuation *= LocalLightRealtimeShadowAttenuation(light.index, positionWS);
						finalColors = CalcToonLight(finalColors, light, s, normalWS, viewDirectionWS);
					}
				#endif					

				//Now we get the pixel color as: (difColor + specColor) * our inner line mask
				return half4( (finalColors.difColor + finalColors.specColor) * s.InnerLine, 1);
            }
            ENDHLSL
        }

		//Passes used by the engine to bake lights/calc shadows...
        UsePass "LightweightPipeline/Standard (Physically Based)/ShadowCaster"
        UsePass "LightweightPipeline/Standard (Physically Based)/DepthOnly"
        UsePass "LightweightPipeline/Standard (Physically Based)/Meta"
    }

    FallBack "Hidden/InternalErrorShader"
}
