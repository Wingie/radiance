#property description Distort first input according to second input. Uses red & green values of second input as UV lookup coordinates in first input.
#property inputCount 2

fn main(uv: vec2<f32>) -> vec4<f32> {
    let map = textureSample(iInputsTex[1], iSampler, uv);
    let newUV = mix(uv, map.rg, iIntensity * map.a * pow(defaultPulse, 2.));
    return textureSample(iInputsTex[0], iSampler, newUV);
}
