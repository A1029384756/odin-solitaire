#version 330

out vec4 fragColor;

uniform vec2 u_resolution;
uniform float u_time;
uniform float u_hue;

vec3 hueShift( vec3 color, float hueAdjust ) {
    const vec3  kRGBToYPrime = vec3 (0.299, 0.587, 0.114);
    const vec3  kRGBToI      = vec3 (0.596, -0.275, -0.321);
    const vec3  kRGBToQ      = vec3 (0.212, -0.523, 0.311);

    const vec3  kYIQToR     = vec3 (1.0, 0.956, 0.621);
    const vec3  kYIQToG     = vec3 (1.0, -0.272, -0.647);
    const vec3  kYIQToB     = vec3 (1.0, -1.107, 1.704);

    float   YPrime  = dot (color, kRGBToYPrime);
    float   I       = dot (color, kRGBToI);
    float   Q       = dot (color, kRGBToQ);
    float   hue     = atan (Q, I);
    float   chroma  = sqrt (I * I + Q * Q);

    hue += hueAdjust;

    Q = chroma * sin (hue);
    I = chroma * cos (hue);

    vec3    yIQ   = vec3 (YPrime, I, Q);

    return vec3( dot (yIQ, kYIQToR), dot (yIQ, kYIQToG), dot (yIQ, kYIQToB) );
}

void main() {
    float effectDensity = 4.0;
    float effectScale = 0.3;
    float timeScale = 0.000125;
    float desaturationPercent = 0.7;
    float brightnessPercent = 0.5;
    float scaledTime = u_time * timeScale;
    
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = gl_FragCoord.xy/u_resolution.xy;
    
    // scale y to the aspect ratio
    uv.y *= u_resolution.y / u_resolution.x;
    
    // effect density/repeat
    uv = uv * effectDensity;
   
    for(float i = 1.0; i < 8.0; i += 1.0){
        uv.x += effectScale * sin(uv.y * i + scaledTime) - scaledTime * i * 10.0;
        uv.y += effectScale * cos(uv.x * i + scaledTime) - sin(scaledTime * i);
    }
    
    // Time varying pixel color
    vec3 col = hueShift(0.5 + 0.5*sin(uv.xyx * 0.3+vec3(0,2,4)), u_hue) * brightnessPercent;

    float L = 0.3*col.x + 0.6*col.y + 0.1*col.z;
    vec3 desaturated;
    desaturated.x = col.x + desaturationPercent * (L - col.x);
    desaturated.y = col.y + desaturationPercent * (L - col.y);
    desaturated.z = col.z + desaturationPercent * (L - col.z);

    // Output to screen
    fragColor = vec4(desaturated,1.0);
}
