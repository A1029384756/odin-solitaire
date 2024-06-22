#version 330

out vec4 fragColor;

uniform vec2 u_resolution;
uniform float u_time;
uniform float u_hue;

float effectDensity = 4.0;
float effectScale = 0.3;
float timeScale = 0.4;
float pixelSize = 700.0;

float brightnessPercent = 0.5;

vec4 colorA = vec4(0.8, 0.1, 0.1, 1.0);
vec4 colorB = vec4(0.0, 0.2, 0.8, 1.0);
vec4 black = 0.6*vec4(79./255.,99./255., 103./255., 1./0.6);

vec4 hueShift( vec4 color, float hueAdjust ) {
    const vec3  kRGBToYPrime = vec3 (0.299, 0.587, 0.114);
    const vec3  kRGBToI      = vec3 (0.596, -0.275, -0.321);
    const vec3  kRGBToQ      = vec3 (0.212, -0.523, 0.311);

    const vec3  kYIQToR     = vec3 (1.0, 0.956, 0.621);
    const vec3  kYIQToG     = vec3 (1.0, -0.272, -0.647);
    const vec3  kYIQToB     = vec3 (1.0, -1.107, 1.704);

    float   YPrime  = dot (color.rgb, kRGBToYPrime);
    float   I       = dot (color.rgb, kRGBToI);
    float   Q       = dot (color.rgb, kRGBToQ);
    float   hue     = atan (Q, I);
    float   chroma  = sqrt (I * I + Q * Q);

    hue += hueAdjust;

    Q = chroma * sin (hue);
    I = chroma * cos (hue);

    vec3    yIQ   = vec3 (YPrime, I, Q);

    return vec4( dot (yIQ, kYIQToR), dot (yIQ, kYIQToG), dot (yIQ, kYIQToB), color.a );
}

void main() {
    // Normalized pixel coordinates (from 0 to 1)
    float pxSize = length(u_resolution.xy)/pixelSize;
    vec2 uv = (floor(gl_FragCoord.xy*(1.0/pxSize))*pxSize - 0.5*u_resolution.xy)/length(u_resolution.xy);
    float uvLen = length(uv);
    float scaledTime = u_time * timeScale;

    float newPixelAngle = atan(uv.y, uv.x) + (2.2 + 0.4)*uvLen - 7.05; 
    vec2 mid = (u_resolution.xy / length(u_resolution.xy)) / 2.0;
    vec2 sv = vec2((uvLen * cos(newPixelAngle) + mid.x), (uvLen * sin(newPixelAngle) + mid.y)) - mid;

    sv *= 30.0;
    scaledTime = u_time * 6.0 * timeScale + 1033.0;
    vec2 uv2 = vec2(sv.x + sv.y);
    
    for (int i = 0; i < 5; i += 1) {
      uv2 += sin(max(sv.x, sv.y)) + sv;
      sv += 0.5*vec2(cos(5.1123314 + 0.353*uv2.y + scaledTime*0.131121), sin(uv2.x - 0.113*scaledTime));
      sv -= 1.0*cos(sv.x + sv.y) - 1.00*sin(sv.x*0.711 - sv.y);
    }

    float smokeRes = min(2.0, max(-2.0, 1.5 + length(sv) * 0.12 - 1.7));
    if (smokeRes < 0.2) {
      smokeRes = (smokeRes - 0.2) * 0.6 + 0.2;
    }

    float c1p = max(0.0, 1.0 - 2.0 * abs(1.0 - smokeRes));
    float c2p = max(0.0, 1.0 - 2.0 * smokeRes);
    float cb = 1.0 - min(1.0, c1p + c2p);
    
    vec4 aShift = hueShift(colorA, u_hue);
    vec4 bShift = hueShift(colorB, u_hue);
    // Output to screen
    vec4 outColor = hueShift(aShift * c1p + bShift * c2p + vec4(cb * black.rgb, cb * aShift.a), u_hue);

    float L = 0.3 * outColor.r + 0.6 * outColor.g + 0.1 * outColor.b;
    outColor.rgb = outColor.rgb * brightnessPercent;
    fragColor = outColor;
}
