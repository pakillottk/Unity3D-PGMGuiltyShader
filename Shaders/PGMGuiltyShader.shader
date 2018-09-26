  Shader "Toon/PGMGuiltyShader" {
	Properties {
		_LitOffset ("Lit offset", Range(0,1)) = 0.25
		_MainTex ("Texture", 2D) = "white" {}
		_Color("Main Color", Color) = (1,1,1,1)
		_SSSTex("SSS Map", 2D) = "white" {}
		_SSSTint("SSS Color", Color) = (1,1,1,1)
		_CombMap("Combined Map", 2D) = "white" {}	
		_SpecTint("Specular Color", Color) = (1,1,1,1)
		_SpecScale("Specular Scale", Range(0,10)) = 1
		_OutlineColor ("Outline Color", Color) = (0,0,0,1)
		_OutlineThickness ("Outline Thickness", Range(0,1))  = 0.2
	}

	SubShader {	
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
				float3 normal: NORMAL;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
			};

			v2f vert (appdata v)
			{
				v2f o;

				o.pos = UnityObjectToClipPos(v.vertex+normalize(v.normal)*(_OutlineThickness/100));
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				return _OutlineColor;
			}
			ENDCG
		}

		//Toon surface shader
		Tags { "RenderType" = "Opaque" }

		CGPROGRAM
			#pragma surface surf ToonLight

			struct CustomSurfaceOutput
			{
				fixed3 Albedo;
				fixed3 Normal;
				fixed3 Emission;
				fixed Alpha;
				fixed3 SSS;
				fixed Shadow;
				fixed Glossy;
				fixed Glossiness;
				fixed InnerLine;
				fixed VertexOcclussion;
			};

			sampler2D _ToonLut;
			half3 _SpecTint;
			half3 _RimColor;
			half _RimPower;
			half _LitOffset;
			half4 _OutlineColor;
			half4 _Color;
			float _SpecScale;

			half4 LightingToonLight (CustomSurfaceOutput s, half3 lightDir, half3 viewDir, half atten) {
			
				half NdotL  = saturate(dot (s.Normal, lightDir)) * atten; 
				float ndotv = saturate(dot(s.Normal, viewDir));
				float lut = step(_LitOffset, NdotL) * s.VertexOcclussion;
				
				half4 c;
				half3 albedoColor = s.Albedo * _Color * _LightColor0.rgb;
				c.rgb = lerp( albedoColor * s.SSS, albedoColor,lut * s.Shadow * s.VertexOcclussion);
				c.rgb += _SpecTint * s.Glossy * s.Glossiness * _LightColor0.rgb * lut * _SpecScale;
				c.rgb *= lerp( _OutlineColor, half3(1,1,1), s.InnerLine);
				c.a = s.Alpha;
				return c;
			}
  
			struct Input {
				float2 uv_MainTex;
				float4 vertColor : COLOR;
			};
        
			sampler2D _MainTex;
			sampler2D _SSSTex;
			sampler2D _CombMap;
			half3 _SSSTint;

			void surf (Input IN, inout CustomSurfaceOutput o) {
				half4 comb = tex2D(_CombMap, IN.uv_MainTex);				
				o.Albedo = tex2D (_MainTex, IN.uv_MainTex).rgb;
				o.SSS = tex2D(_SSSTex, IN.uv_MainTex).rgb * _SSSTint;
				o.Glossy = comb.r;
				o.Shadow = comb.g;
				o.Glossiness = comb.b;
				o.InnerLine = comb.a;
				o.VertexOcclussion = IN.vertColor.r;
			}
		ENDCG		
	}

	Fallback "Diffuse"
  }
