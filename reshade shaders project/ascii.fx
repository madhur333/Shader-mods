#include "ReShade.fxh"
#include "ReShadeUI.fxh"

uniform int Ascii_spacing < __UNIFORM_SLIDER_INT1
	ui_min = 0;
	ui_max = 5;
	ui_label = "Character Spacing";
	ui_tooltip = "Determines the spacing between characters. I feel 1 to 3 looks best.";
	ui_category = "Font style";
> = 1;

uniform int Ascii_font <
	ui_type = "combo";
	ui_label = "Font Size";
	ui_tooltip = "Choose font size";
	ui_category = "Font style";
	ui_items = 
	"Normal 5x5 font\0"
	;
> = 1;

uniform int Ascii_font_color_mode < __UNIFORM_SLIDER_INT1
	ui_min = 0;
	ui_max = 2;
	ui_label = "Font Color Mode";
	ui_tooltip = "0 = Foreground color on background color, 1 = Colorized grayscale, 2 = Full color";
	ui_category = "Color options";
> = 1;

uniform float3 Ascii_font_color < __UNIFORM_COLOR_FLOAT3
	ui_label = "Font Color";
	ui_tooltip = "Choose a font color";
	ui_category = "Color options";
> = float3(1.0, 1.0, 1.0);

uniform float3 Ascii_background_color < __UNIFORM_COLOR_FLOAT3
	ui_label = "Background Color";
	ui_tooltip = "Choose a background color";
	ui_category = "Color options";
> = float3(0.0, 0.0, 0.0);

uniform bool Ascii_swap_colors <
	ui_label = "Swap Colors";
	ui_tooltip = "Swaps the font and background color when you are too lazy to edit the settings above (I know I am)";
	ui_category = "Color options";
> = 0;

uniform bool Ascii_dithering <
	ui_label = "Dithering";
	ui_category = "Dithering";
> = 1;

uniform float Ascii_dithering_intensity < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0;
	ui_max = 4.0;
	ui_label = "Dither shift intensity";
	ui_tooltip = "For debugging purposes";
	ui_category = "Debugging";
> = 2.0;

uniform bool Ascii_dithering_debug_gradient <
	ui_label = "Dither debug gradient";
	ui_category = "Debugging";
> = 0;

#define asciiSampler ReShade::BackBuffer

uniform float timer < source = "timer"; >;
uniform float framecount < source = "framecount"; >;

float3 AsciiPass(float2 tex) {
	float2 Ascii_font_size = float2(5.0, 5.0);
	float num_of_chars = 17.;

	float quant = 1.0 / (num_of_chars - 1.0);
	float2 Ascii_block = Ascii_font_size + float(Ascii_spacing);
	float2 cursor_position = trunc((BUFFER_SCREEN_SIZE / Ascii_block) * tex) * (Ascii_block / BUFFER_SCREEN_SIZE);

	float3 color = tex2D(asciiSampler, cursor_position + float2(1.5, 1.5) * BUFFER_PIXEL_SIZE).rgb;
	color += tex2D(asciiSampler, cursor_position + float2(1.5, 3.5) * BUFFER_PIXEL_SIZE).rgb;
	color += tex2D(asciiSampler, cursor_position + float2(1.5, 5.5) * BUFFER_PIXEL_SIZE).rgb;
	color += tex2D(asciiSampler, cursor_position + float2(3.5, 1.5) * BUFFER_PIXEL_SIZE).rgb;
	color += tex2D(asciiSampler, cursor_position + float2(3.5, 3.5) * BUFFER_PIXEL_SIZE).rgb;
	color += tex2D(asciiSampler, cursor_position + float2(3.5, 5.5) * BUFFER_PIXEL_SIZE).rgb;
	color += tex2D(asciiSampler, cursor_position + float2(5.5, 1.5) * BUFFER_PIXEL_SIZE).rgb;
	color += tex2D(asciiSampler, cursor_position + float2(5.5, 3.5) * BUFFER_PIXEL_SIZE).rgb;
	color += tex2D(asciiSampler, cursor_position + float2(5.5, 5.5) * BUFFER_PIXEL_SIZE).rgb;

	color /= 9.0;

	float luma = dot(color, float3(0.2126, 0.7152, 0.0722));
	float gray = luma;

	if (Ascii_dithering_debug_gradient) {
		gray = cursor_position.x;
	}

	float2 p = frac((BUFFER_SCREEN_SIZE / Ascii_block) * tex);
	p = trunc(p * Ascii_block);
	float x = (Ascii_font_size.x * p.y + p.x);

	float n = 0;

	float n12   = (gray < (2. * quant))  ? 4194304.  : 131200.;
	float n34   = (gray < (4. * quant))  ? 324.      : 330.;
	float n56   = (gray < (6. * quant))  ? 283712.   : 12650880.;
	float n78   = (gray < (8. * quant))  ? 4532768.  : 13191552.;
	float n910  = (gray < (10. * quant)) ? 10648704. : 11195936.;
	float n1112 = (gray < (12. * quant)) ? 15218734. : 15255086.;
	float n1314 = (gray < (14. * quant)) ? 15252014. : 32294446.;
	float n1516 = (gray < (16. * quant)) ? 15324974. : 11512810.;

	float n1234     = (gray < (3. * quant))  ? n12   : n34;
	float n5678     = (gray < (7. * quant))  ? n56   : n78;
	float n9101112  = (gray < (11. * quant)) ? n910  : n1112;
	float n13141516 = (gray < (15. * quant)) ? n1314 : n1516;

	float n12345678 = (gray < (5. * quant)) ? n1234 : n5678;
	float n910111213141516 = (gray < (13. * quant)) ? n9101112 : n13141516;

	n = (gray < (9. * quant)) ? n12345678 : n910111213141516;

	float character = 0.0;

	float lit = (gray <= (1. * quant)) ? 0.0 : 1.0;

	float signbit = (n < 0.0) ? lit : 0.0;

	signbit = (x > 23.5) ? signbit : 0.0;

	character = (frac(abs(n * exp2(-x - 1.0))) >= 0.5) ? lit : signbit;

	if (clamp(p.x, 0.0, Ascii_font_size.x - 1.0) != p.x || clamp(p.y, 0.0, Ascii_font_size.y - 1.0) != p.y)
		character = 0.0;

	if (Ascii_swap_colors) {
		if (Ascii_font_color_mode == 2) {
			color = (character) ? character * color : Ascii_font_color;
		} else if (Ascii_font_color_mode == 1) {
			color = (character) ? Ascii_background_color * gray : Ascii_font_color;	
		} else {
			color = (character) ? Ascii_background_color : Ascii_font_color;
		}
	} else {
		if (Ascii_font_color_mode == 2) {
			color = (character) ? character * color : Ascii_background_color;
		} else if (Ascii_font_color_mode == 1) {
			color = (character) ? Ascii_font_color * gray : Ascii_background_color;
		} else {
			color = (character) ? Ascii_font_color : Ascii_background_color;
		}
	}

	return saturate(color);
}

float3 PS_Ascii(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {  
	float3 color = AsciiPass(texcoord);
	return color.rgb;
}

technique ASCII {
	pass ASCII {
		VertexShader = PostProcessVS;
		PixelShader = PS_Ascii;
	}
}
