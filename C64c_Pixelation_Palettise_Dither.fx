/*
	Description : C64c Pixelation Palettise Dither
	Author      : Fox2232
	License     : MIT, Copyright (c) 2020


	MIT License

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

*/

#include "ReShade.fxh"
#include "ReShadeUI.fxh"

namespace C64c_Pixelation_Palettise_Dither
{
	//// UI ELEMENTS ////////////////////////////////////////////////////////////////
	uniform int pixelation_x <
		ui_label = "pixelation X";
		ui_tooltip = "pixelation X";
		ui_category = "Pixelate";
		ui_type = "slider";
		ui_min = 1;
		ui_max = 20; // 5 for 2x density on 1080p; 10 for 1080p; 20 for 2160p
		> = 5;
	uniform int pixelation_y <
		ui_label = "pixelation Y";
		ui_tooltip = "pixelation Y";
		ui_category = "Pixelate";
		ui_type = "slider";
		ui_min = 1;
		ui_max = 20; // 3 for 2x density on 1080p; 5 for 1080p; 10 for 2160p
		> = 3;
	uniform float pixelation_comparison <
		ui_type = "slider";
		ui_label = "Pixelation Comparison";
		ui_tooltip = "Pixelation Comparison";
		ui_category = "Pixelate";
		ui_min = 0.0f;
		ui_max = 1.0f;
		> = 0.5;
	uniform float palettise_comparison <
		ui_type = "slider";
		ui_label = "Palettise Comparison";
		ui_tooltip = "Palettise Comparison";
		ui_category = "Pixelate";
		ui_min = 0.0f;
		ui_max = 1.0f;
		> = 0.5;
	uniform int dither_level <
		ui_type = "slider";
		ui_label = "Dither Level";
		ui_tooltip = "Dither Level";
		ui_category = "Dithering";
		ui_min = 0;
		ui_max = 5;
	> = 4;
	uniform int dither_method <
		ui_type = "slider";
		ui_label = "Dither Method";
		ui_tooltip = "Dither Method";
		ui_category = "Dithering";
		ui_min = 1;
		ui_max = 2;
	> = 2;
		uniform bool border <
		ui_label = "Size to Border";
		ui_tooltip = "Size to Border";
		ui_category = "Border";
	> = 0;
	uniform int border_color <
		ui_type = "slider";
		ui_label = "Border Color";
		ui_tooltip = "Border Color";
		ui_category = "Border";
		ui_min = 0;
		ui_max = 15;
	> = 10;

	//// TEXTURES ///////////////////////////////////////////////////////////////////
	texture2D texMipMe { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; MipLevels = 8; };
	texture texPixelized { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT;};
	texture2D texPaletized { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; MipLevels = 1;};
	//// SAMPLERS ///////////////////////////////////////////////////////////////////
	sampler samplerMipMe { Texture = texMipMe; MipFilter = POINT; MinFilter = Linear; MagFilter = Linear; };
	sampler2D samplerPix { Texture = texPixelized; };
	sampler samplerPal { Texture = texPaletized; MipFilter = POINT; MinFilter = Linear; MagFilter = POINT; };
	//// FUNCTIONS //////////////////////////////////////////////////////////////////

	//GetHueInRadians
	float getHue(float3 RGB){
		float R = RGB.x; float G = RGB.y; float B = RGB.z;
		float minC; float maxC; float Eps = 1e-10; float toRad = 1.0471975512;
		minC = min(min(R,G),B);
		maxC = max(max(R,G),B);
		if(maxC==minC) return 0;
		if(maxC == R) return   (G-B)/(maxC-minC+Eps)*toRad;
		if(maxC == G) return 2+(B-R)/(maxC-minC+Eps)*toRad;
		if(maxC == B) return 4+(R-G)/(maxC-minC+Eps)*toRad;
		return 0;
	}
	//Palette
	float3 palette(int index){
		float3 Palette[16] = {
		float3(  0,   0,   0) / 255., // BLACK =		0
		float3( 96,  96,  96) / 255., // Dark GREY *
		float3(139, 139, 139) / 255., // Med GREY *		Gray Selection
		float3(180, 181, 180) / 255.,  // LT GREY =
		float3(255, 255, 255) / 255., // WHITE =		4
		float3(156,  47,  43) / 255., // RED =a1/8		5
		float3(103, 177,  78) / 255., // GREEN -5L
		float3( 65,  45, 159) / 255., // BLUE -5L		RGB Selection
		float3(189, 127, 119) / 255., // LT RED =a1/8
		float3(148, 225, 120) / 255., // LT GREEN -10L
		float3(135, 119, 218) / 255., // LT BLUE *+=	10
		float3( 71, 175, 184) / 255., // CYAN -20L		11
		float3(165,  58, 138) / 255., // PURPLE *+-		CMY Selection
		float3(230, 232, 112) / 255., // YELLOW *+-		13
		float3(158, 107,  50) / 255., // ORANGE =		14
		float3(103,  75,  10) / 255.  // BROWN =a		15
		};
		return Palette[index];
	}

	float3 RGBtoHSL(in float3 RGB){//Hue in radians
		float H, S, L = 0.5; float toRad = 1.0471975512;
		float R = RGB.x; float G = RGB.y; float B = RGB.z;
		float minC; float maxC; float Eps = 1e-10;
		minC = min(min(R,G),B);
		maxC = max(max(R,G),B);
		float chroma =  maxC - minC;
		H = getHue(RGB);
		S = 2 * ( maxC - minC ) / ( 1 + abs(maxC - 0.5) + abs(minC - 0.5) );
		L = (maxC+minC)/2;
		S = maxC == 0 ? 0 : chroma / (1-abs(2*L-1));
		if((L==0)||(L==1)){S = 0;}else{S = chroma/(1-abs(2*maxC-chroma-1));}
		return float3(H, S, L);
	}

	float3 HSLtoRGB( float3 hsl ) {
		float H = hsl.x; float S = hsl.y; float L = hsl.z; float toRad = 1.0471975512; float3 RGB;
		float C = (1-abs(2*L-1))*S; float unH = H / toRad; unH = unH < 0 ? unH+6 : unH%6;
		float X = C*(1-abs(unH%2-1));
		float minC = L - 0.5*C;
		if(abs(unH-0.5)<=0.5) RGB=float3(C, X, 0);
		if(abs(unH-1.5)<=0.5) RGB=float3(X, C, 0);
		if(abs(unH-2.5)<=0.5) RGB=float3(0, C, X);
		if(abs(unH-3.5)<=0.5) RGB=float3(0, X, C);
		if(abs(unH-4.5)<=0.5) RGB=float3(X, 0, C);
		if(abs(unH-5.5)<=0.5) RGB=float3(C, 0, X);
		RGB=RGB+float3(minC,minC,minC);
		return RGB;
	}

	float indexValue(float2 texcoord : TEXCOORD, float3 c) {
		int MatrixEdge = 4; float MatrixSize = 16; float MatrxOut; float2 uv = texcoord.xy;
		int ix = 0; int iy = 0;
		int indexMatrix1[1] = { 0};
		int indexMatrix4[4] = { 0, 2,
								3, 1};
		int indexMatrix36[36] = { 13, 22, 18, 27, 11, 20,
								  31,  4, 36,  9, 29,  2,
								  12, 21, 14, 23, 16, 25,
								  30,  3,  5, 32, 34,  7,
								  17, 26, 10, 19, 15, 24,
								   8, 35, 28,  1,  6, 33};
		int indexMatrix64[64] = {0,  32, 8,  40, 2,  34, 10, 42,
								48, 16, 56, 24, 50, 18, 58, 26,
								12, 44, 4,  36, 14, 46, 6,  38,
								60, 28, 52, 20, 62, 30, 54, 22,
								3,  35, 11, 43, 1,  33, 9,  41,
								51, 19, 59, 27, 49, 17, 57, 25,
								15, 47, 7,  39, 13, 45, 5,  37,
								63, 31, 55, 23, 61, 29, 53, 21};
								
		int indexMatrix256[256] = {  0,192, 48,240, 12,204, 60,252,  3,195, 51,243, 15,207, 63,255,
								  128, 64,176,112,140, 76,188,124,131, 67,179,115,143, 79,191,127,
								   32,224, 16,208, 44,236, 28,220, 35,227, 19,211, 47,239, 31,223,
								  160, 96,144, 80,172,108,156, 92,163, 99,147, 83,175,111,159, 95,
								    8,200, 56,248,  4,196, 52,244, 11,203, 59,251,  7,199, 55,247,
								  136, 72,184,120,132, 68,180,116,139, 75,187,123,135, 71,183,119,
								   40,232, 24,216, 36,228, 20,212, 43,235, 27,219, 39,231, 23,215,
								  168,104,152, 88,164,100,148, 84,171,107,155, 91,167,103,151, 87,
								    2,194, 50,242, 14,206, 62,254,  1,193, 49,241, 13,205, 61,253,
								  130, 66,178,114,142, 78,190,126,129, 65,177,113,141, 77,189,125,
								   34,226, 18,210, 46,238, 30,222, 33,225, 17,209, 45,237, 29,221,
								  162, 98,146, 82,174,110,158, 94,161, 97,145, 81,173,109,157, 93,
								   10,202, 58,250,  6,198, 54,246,  9,201, 57,249,  5,197, 53,245,
								  138, 74,186,122,134, 70,182,118,137, 73,185,121,133, 69,181,117,
								   42,234, 26,218, 38,230, 22,214, 41,233, 25,217, 37,229, 21,213,
								  170,106,154, 90,166,102,150, 86,169,105,153, 89,165,101,149, 85 };
		if(dither_level == 0){MatrixEdge =  1;MatrixSize =   1; ix = int(floor(texcoord.x * BUFFER_WIDTH) % MatrixEdge);iy = int(floor(texcoord.y * BUFFER_HEIGHT) % MatrixEdge); MatrxOut =   indexMatrix1[ix + iy * MatrixEdge] / MatrixSize;};
		if(dither_level == 1){MatrixEdge =  2;MatrixSize =   4; ix = int(floor(texcoord.x * BUFFER_WIDTH) % MatrixEdge);iy = int(floor(texcoord.y * BUFFER_HEIGHT) % MatrixEdge); MatrxOut =   indexMatrix4[ix + iy * MatrixEdge] / MatrixSize;};
		if(dither_level == 2){MatrixEdge =  6;MatrixSize =  36; ix = int(floor(texcoord.x * BUFFER_WIDTH) % MatrixEdge);iy = int(floor(texcoord.y * BUFFER_HEIGHT) % MatrixEdge); MatrxOut =  indexMatrix36[ix + iy * MatrixEdge] / MatrixSize;};
		if(dither_level == 3){MatrixEdge =  8;MatrixSize =  64; ix = int(floor(texcoord.x * BUFFER_WIDTH) % MatrixEdge);iy = int(floor(texcoord.y * BUFFER_HEIGHT) % MatrixEdge); MatrxOut =  indexMatrix64[ix + iy * MatrixEdge] / MatrixSize;};
		if(dither_level == 4){MatrixEdge = 16;MatrixSize = 256; ix = int(floor(texcoord.x * BUFFER_WIDTH) % MatrixEdge);iy = int(floor(texcoord.y * BUFFER_HEIGHT) % MatrixEdge); MatrxOut = indexMatrix256[ix + iy * MatrixEdge] / MatrixSize;};
		if(dither_level == 5) MatrxOut = frac(sin(dot(uv, float2(12.9898+c.x+c.z*0.5, 78.233+c.y+c.z*0.5))) * 43758.5453);
		return MatrxOut;
	}

	float HSLInversity(float3 HSL1, float3 HSL2, float3 HSLref){
		float3 XYZ1 = float3(cos(HSL1.x)*HSL1.y, sin(HSL1.x)*HSL1.y, sin(2*HSL1.z-1));
		float3 XYZ2 = float3(cos(HSL2.x)*HSL2.y, sin(HSL2.x)*HSL2.y, sin(2*HSL2.z-1));
		float3 XYZr = float3(cos(HSLref.x)*HSLref.y, sin(HSLref.x)*HSLref.y, sin(2*HSLref.z-1));
		float3 XYZ1d = XYZ1 - XYZr; float3 XYZ2d = XYZ2 - XYZr;
		float V1=sqrt(dot(XYZ1d, XYZ1d));//Get vec lengths and product
		float V2=sqrt(dot(XYZ2d, XYZ2d));
		float Vv=dot(XYZ1d, XYZ2d);
		float inv=acos(Vv/(V1*V2))*0.31830988618379;//get angular inversity in range 0~1 (0°~180°)
		return inv; //return 1-inversity as smaller, the better
	}

	float HSLDistSpheric(float3 HSL1, float3 HSL2){
		float3 XYZ1 = float3(cos(HSL1.x)*HSL1.y, sin(HSL1.x)*HSL1.y, sin(2*HSL1.z-1));
		float3 XYZ2 = float3(cos(HSL2.x)*HSL2.y, sin(HSL2.x)*HSL2.y, sin(2*HSL2.z-1));
		float3 diff = XYZ1 - XYZ2;
		float  dist = sqrt(dot(diff,diff));
		return dist;
	}

	struct ret2xfloat3structHsL {float3 colorHSL1, colorHSL2, colorHSL3, colorHSL4;};
	ret2xfloat3structHsL closestColorsHsL(float3 HSL) {
		float candidateDist[4]; int candidateIndex[4]; float3 candidateRGB[4];
		candidateIndex[0] = 0; candidateIndex[1] = 0; candidateIndex[2] = 10; candidateIndex[3] = 10;
		int paletteSize = 16; float distances[16]; float mindist;
		for (int i = 0; i < 16; i++) {//get all distances from target pixel
			distances[i] = HSLDistSpheric(HSL, RGBtoHSL(palette(i)));
		}
		
		mindist = min(min(min(distances[0], distances[1]),min(distances[2], distances[3])),distances[4]);
		for (int i = 0; i < 5; ++i){if(distances[i]==mindist){candidateIndex[0] = i; candidateDist[0]=distances[i];candidateRGB[0]=palette(i); distances[i] += 100000;break;};}
		mindist = min(min(min(distances[5],distances[6]),min(distances[7],distances[8])),min(distances[9],distances[10]));
		for (int i = 5; i < 11; ++i){if(distances[i]==mindist){candidateIndex[1] = i;candidateDist[1]=distances[i];candidateRGB[1]=palette(i); distances[i] += 100000;break;};}
		mindist = min(min(min(distances[5],distances[6]),min(distances[7],distances[8])),min(min(distances[9],distances[10]),min(distances[11],min(distances[12],distances[13]))));
		for (int i = 5; i < 14; ++i){if(distances[i]==mindist){candidateIndex[2] = i;candidateDist[2]=distances[i];candidateRGB[2]=palette(i); distances[i] += 100000;break;};}
		mindist = min(min(min(min(distances[0],distances[1]),min(distances[2],distances[3])),min(min(distances[4],distances[5]),min(distances[6],distances[7]))),min(min(min(distances[8],distances[9]),min(distances[10],distances[11])),min(min(distances[12],distances[13]),min(distances[14],distances[15]))));
		for (int i = 0; i < 16; ++i){if(distances[i]==mindist){candidateIndex[3] = i;candidateDist[3]=distances[i];candidateRGB[3]=palette(i); distances[i] += 100000;break;};}

		int distIndexC1 = 0; int distIndexC2 = 0; int distIndexC3 = 0; int distIndexC4 = 0;
		//Sorting Candidates for output
		for (int i = 0; i < 4; i++) {
			if(candidateDist[i] < candidateDist[distIndexC1]) distIndexC1 = i;
		}
		candidateDist[distIndexC1] += 100000;
		for (int i = 0; i < 4; i++) {
			if(candidateDist[i] < candidateDist[distIndexC2]) distIndexC2 = i;
		}
		candidateDist[distIndexC2] += 100000;
		for (int i = 0; i < 4; i++) {
			if(candidateDist[i] < candidateDist[distIndexC3]) distIndexC3 = i;
		}
		candidateDist[distIndexC3] += 100000;
		for (int i = 0; i < 4; i++) {
			if(candidateDist[i] < candidateDist[distIndexC4]) distIndexC4 = i;
		}

		ret2xfloat3structHsL ret2xfloat3HsL;
		ret2xfloat3HsL.colorHSL1 = RGBtoHSL(candidateRGB[distIndexC1]);//Closest;
		ret2xfloat3HsL.colorHSL2 = RGBtoHSL(candidateRGB[distIndexC2]);//2nd Closest;
		ret2xfloat3HsL.colorHSL3 = RGBtoHSL(candidateRGB[distIndexC3]);//3rd Closest;
		ret2xfloat3HsL.colorHSL4 = RGBtoHSL(candidateRGB[distIndexC4]);//3rd Closest;
		return ret2xfloat3HsL;
	}

	float3 ditherHsL(float3 color, float2 texcoord : TEXCOORD) {
		ret2xfloat3structHsL colorsHSL = closestColorsHsL(color); float3 closest[4];
		closest[0] = colorsHSL.colorHSL1; float Eps = 1e-4;
		closest[1] = colorsHSL.colorHSL2;
		closest[2] = colorsHSL.colorHSL3;
		closest[3] = colorsHSL.colorHSL4;
		
		float d = indexValue(texcoord, color);
		if(dither_method==1){
			float delta1=HSLDistSpheric(color, closest[0]);
			float delta2=HSLDistSpheric(color, closest[1]);
			float delta3=HSLDistSpheric(color, closest[2]);
			float delta4=HSLDistSpheric(color, closest[3]);
			float sum = delta1+delta2+delta3+delta4; float a1=delta1/sum; float a2=delta2/sum; float a3=delta3/sum; float a4=delta4/sum;
			float n1=a1==0?1000000:1/a1; float n2=a2==0?1000000:1/a2; float n3=a3==0?1000000:1/a3; float n4=a4==0?1000000:1/a4;
			n1=pow(n1,2.83); n2=pow(n2,2.83); n3=pow(n3,2.83); n4=pow(n4,2.83); float nsum=n1+n2+n3+n4;
			float f1=n1/nsum; float f2=n2/nsum; float f3=n3/nsum; float f4=n4/nsum;
			return d <= f1 ? closest[0] : d <= f1+f2 ? closest[1] : d <= f1+f2+f3 ? closest[2] : closest[3];
		}

		if(dither_method==2){
			float f1,f2,f3,f4; float sum; float3 ref; float n1, n2, n3, n4;
			float delta1=HSLDistSpheric(color, closest[0])+Eps;
			float delta2=HSLDistSpheric(color, closest[1])/(1-min(HSLInversity(closest[1], color, closest[0]),1-abs(closest[1].z-color.z))+Eps);
			n1=1/delta1; n2=1/delta2;
			sum = n1+n2;
			f1=n1/sum; f2=n2/sum;
			ref=closest[0]*f1+closest[1]*f2;
			float delta3=HSLDistSpheric(color, closest[2])/(1-min(HSLInversity(closest[2], color, ref),1-abs(closest[2].z-color.z))+Eps);
			n3=1/delta3;
			sum = n1+n2+n3;
			f1=n1/sum; f2=n2/sum; f3=n3/sum;
			ref=closest[0]*f1+closest[1]*f2+closest[2]*f3;
			float delta4=HSLDistSpheric(color, closest[3])/(1-min(HSLInversity(closest[3], color, ref),1-abs(closest[3].z-color.z))+Eps);
			n4=1/delta4;
			n1=pow(n1,2.45); n2=pow(n2,2.45); n3=pow(n3,2.45); n4=pow(n4,2.45);sum = n1+n2+n3+n4;
			f1=n1/sum; f2=n2/sum; f3=n3/sum; f4=n4/sum;
			ref=closest[0]*f1+closest[1]*f2+closest[2]*f3+closest[3]*f4;
			return d <= f1 ? closest[0] : d <= f1+f2 ? closest[1] : d <= f1+f2+f3 ? closest[2] : closest[3];
		}
		return float3(1,1,1);
	}

	//// PIXEL SHADERS //////////////////////////////////////////////////////////////
	float4 PS_MipMe(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
		if(border==1){float x, y;
			x = texcoord.x*1.25-0.125; y = texcoord.y*1.25-0.125;
			float2 uv = float2(x,y);
			return tex2D( ReShade::BackBuffer, uv );
		}
		return tex2D( ReShade::BackBuffer, texcoord );
	}

	float4 PS_Pixelize(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
	float2 uv = texcoord.xy; float3 tc;
	if(uv.x < (palettise_comparison/pixelation_x-0.0002) && uv.y < (pixelation_comparison/pixelation_y-0.0002)){
		float2 coord = float2(uv.x*pixelation_x, uv.y*pixelation_y);
		tc = tex2Dlod(samplerMipMe, float4(coord,0,0)).rgb;
	}
	
	if(uv.x > (palettise_comparison-0.0002) && uv.y < (pixelation_comparison-0.0002)){
		float dx = pixelation_x*BUFFER_RCP_WIDTH;
		float dy = pixelation_y*BUFFER_RCP_HEIGHT;
		float2 coord = float2(dx*floor(uv.x/dx+0.5), dy*floor(uv.y/dy+0.5));
		tc = tex2Dlod(samplerMipMe, float4(coord,0,0)).rgb;
	}
	else if(uv.y>=(pixelation_comparison+0.0002)){
		tc = tex2Dlod(samplerMipMe, float4(texcoord.xy,0,0)).rgb ;
	}
	return float4(tc, 1.0);
	}

	//**** DITHERING ***************************************************************
	float4 PS_Dither(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
	float2 uv = texcoord.xy;
	float3 tc; float4 tcOut = float4(1, 0, 0.5, 1);

	if (uv.x < (palettise_comparison/pixelation_x-0.0002) && uv.y < (pixelation_comparison/pixelation_y-0.0002)){
		//float2 coord = ();
		tc = tex2D(samplerPix, texcoord.xy).rgb;
		tcOut = float4(HSLtoRGB(ditherHsL(RGBtoHSL(tc), texcoord.xy)), 1);
	}
	if (uv.x < (palettise_comparison-0.0002) && uv.y>=(pixelation_comparison+0.0002)){
		float2 coord = float2(floor(uv.x*BUFFER_WIDTH+0.5)*BUFFER_RCP_WIDTH, floor(uv.y*BUFFER_HEIGHT+0.5)*BUFFER_RCP_HEIGHT);
		tc = tex2D(samplerPix, coord).rgb;
		tcOut = float4(HSLtoRGB(ditherHsL(RGBtoHSL(tc), coord)), 1.0);
	}
	else if (uv.x>=(palettise_comparison+0.0002)){
		tc = tex2D(samplerPix, texcoord.xy).rgb ;
		tcOut = float4(tc, 1.0);
	}
	return tcOut;
	}

	float4 PS_Recompose(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
		float2 uv = texcoord.xy;
		float3 tc; float4 tcOut = float4(1, 0, 0.5, 1);
		if(border==1){float x, y;
			x = texcoord.x*1.25-0.125; y = texcoord.y*1.25-0.125;
			if(texcoord.x<0.1||texcoord.x>0.9||texcoord.y<0.1||texcoord.y>0.9){return float4(palette(border_color),1);}
		}
		if (uv.x < (palettise_comparison-0.0002) && uv.y<(pixelation_comparison+0.0002)){
			float2 coord = float2((uv.x*BUFFER_WIDTH+0.5)/(pixelation_x*BUFFER_WIDTH), (uv.y*BUFFER_HEIGHT+0.5)/(pixelation_y*BUFFER_HEIGHT));
			tc = tex2D(samplerPal, coord).rgb;
			tcOut = float4(tc, 1.0);
		}else{
			tc = tex2D(samplerPal, texcoord.xy).rgb ;
			tcOut = float4(tc, 1.0);
		}
		return tcOut;
	}
	//// TECHNIQUES /////////////////////////////////////////////////////////////////
	technique C64c_Pixelation_Palettise_Dither {
		pass C64c_pass0 { // Mip Creation
			VertexShader   = PostProcessVS;
			PixelShader    = PS_MipMe;
				RenderTarget   = texMipMe;
		}
		pass C64c_pass1 {// Pixelation
			VertexShader   = PostProcessVS;
			PixelShader    = PS_Pixelize;
			RenderTarget   = texPixelized;
		}
		pass C64c_pass2 {// Dithering
			VertexShader   = PostProcessVS;
			PixelShader    = PS_Dither;
			RenderTarget   = texPaletized;
		}
		pass C64c_pass3{
			VertexShader   = PostProcessVS;
			PixelShader    = PS_Recompose;
		}
	}
}
