Shader "Toon/PGMGuiltyShader" {
	Properties {
		_LitOffset ("Lit Offset", Range(0,1)) = 0.25
		_HighLitOffset ("Lit Offset", Range(0,1)) = 0.25
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_SSSTex("SSS Map", 2D) = "black" {}
		_SSSColor("SSS Tint", Color) = (1,1,1,1)
		_CombMap("Comb Map", 2D) = "white" {}
		_SpecTint("Specular Color", Color) = (1,1,1,1)
		_SpecPower("Specular Power", Range(0,100)) = 20.0
		_SpecScale("Specular Scale", Range(0,10)) = 1.0
		_OutlineColor("Outline Color", Color) = (0,0,0,1)
		_OutlineThickness("Outline Thickness", Range(0,1)) = 0.3
	}
	SubShader {
		
		Tags { "RenderType"="Opaque" }
		LOD 200

		//Outline pass
		Pass {
			Cull Front

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			half4 _OutlineColor;
			half _OutlineThickness;

			struct appdata
            {
                float4 vertex : POSITION;
				float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
            };
			            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex+normalize(v.normal)*(_OutlineThickness/100));
                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                return _OutlineColor;
            }
			ENDCG
		}

		//Toon shading
		CGPROGRAM
		#pragma surface surf ToonLighting 

		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0

		sampler2D _MainTex;
		sampler2D _SSSTex;
		sampler2D _CombMap;
		half4 _Color;
		half4 _SSSColor;
		half3 _SpecTint;
		half _LitOffset;
		half _HighLitOffset;
		half _SpecPower;
		half _SpecScale;

		struct CustomSurfaceOutput {
			half3 Albedo;
			half3 Normal;
			half3 Emission;
			half Alpha;
			half3 SSS;
			half vertexOc;
			half Glossy;
			half Glossiness;
			half Shadow;
			half InnerLine;
		};

		half4 LightingToonLighting( CustomSurfaceOutput s, half3 lightDir, half3 viewDir, half atten )
		{
			float oc = step(0.9, s.vertexOc);
			float NdotL = saturate(dot(s.Normal, lightDir)) * atten;
			float toonL = step(_LitOffset, NdotL) * s.Shadow * oc;
			half3 diffuseColor = lerp( s.Albedo * s.SSS, s.Albedo, toonL ) * _LightColor0;

			half specular = step(_HighLitOffset, pow(max(0,dot(reflect(-lightDir, s.Normal), viewDir)), s.Glossiness * _SpecPower ));
			half3 specularColor = specular * toonL * _LightColor0 * s.Glossy * _SpecScale * _SpecTint;

			return half4( (diffuseColor + specularColor) * s.InnerLine, 1);
		}

		struct Input {
			float2 uv_MainTex;
			float4 vertColor : COLOR;
		};

		void surf (Input IN, inout CustomSurfaceOutput o) {
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			half4 comb = tex2D(_CombMap, IN.uv_MainTex);
			o.Albedo = c.rgb;
			o.SSS = tex2D(_SSSTex, IN.uv_MainTex) * _SSSColor;
			o.vertexOc = IN.vertColor.r;
			o.Glossy = comb.r;
			o.Glossiness = comb.b;
			o.Shadow = comb.g;
			o.InnerLine = comb.a;
		}
		ENDCG
	}
	FallBack "Diffuse"
}

