struct Uniforms {
    resolution: vec2<f32>,
    size: vec2<f32>,
}

@group(0) @binding(0)
var<uniform> global: Uniforms;

@group(0) @binding(1)
var iSampler: sampler;

@group(0) @binding(2)
var iSpectrumTex: texture_1d<f32>;

struct VertexOutput {
    @builtin(position) gl_Position: vec4<f32>,
    @location(0) uv: vec2<f32>,
};

// 0xRRGGBBAA (SRGB) -> [r, g, b, a] in 0.0 - 1.0 (linear)
fn unpack_color(color: u32) -> vec4<f32> {
    let srgb = vec4<f32>(
        f32((color >> 24u) & 255u),
        f32((color >> 16u) & 255u),
        f32((color >> 8u) & 255u),
        f32(color & 255u),
    ) / 255.0;

    let cutoff = srgb < vec4<f32>(0.04045);
    let lower = srgb / vec4<f32>(12.92);
    let higher = pow((srgb + vec4<f32>(0.055)) / vec4<f32>(1.055), vec4<f32>(2.4));
    return select(higher, lower, cutoff);
}

@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> VertexOutput {
    var pos_array = array<vec2<f32>, 4>(
        vec2<f32>(1., 1.),
        vec2<f32>(-1., 1.),
        vec2<f32>(1., -1.),
        vec2<f32>(-1., -1.),
    );
    var uv_array = array<vec2<f32>, 4>(
        vec2<f32>(1., 0.),
        vec2<f32>(0., 0.),
        vec2<f32>(1., 1.),
        vec2<f32>(0., 1.),
    );

    return VertexOutput(
        vec4<f32>(pos_array[vertex_index], 0., 1.),
        uv_array[vertex_index],
    );
}

// Alpha-compsite two colors, putting one on top of the other
fn composite(under: vec4<f32>, over: vec4<f32>) -> vec4<f32> {
    let a_out = 1. - (1. - over.a) * (1. - under.a);
    return clamp(vec4<f32>((over.rgb + under.rgb * (1. - over.a)), a_out), vec4<f32>(0.), vec4<f32>(1.));
}

@fragment
fn fs_main(vertex: VertexOutput) -> @location(0) vec4<f32> {
    let spectrumColorOutline = unpack_color(0xAAAAAAFF);
    let spectrumColorBottom = unpack_color(0x440071FF);
    let spectrumColorTop = unpack_color(0xAA00FFFF);

    let oneYPixel = 1. / global.resolution.y;
    let oneYPoint = 1. / global.size.y;

    let freq = vertex.uv.x;
    let h = textureSample(iSpectrumTex, iSampler, freq).r;

    //let smoothEdge = 0.04;
    //let h = h * smoothstep(0., smoothEdge, freq) - smoothstep(1. - smoothEdge, 1., freq);
    let d = (vertex.uv.y - (1. - h)); // TODO this 1 - h is weird
    let c = mix(spectrumColorTop, spectrumColorBottom, clamp(d * 5., 0., 1.)) * step(0., d);
    let c2 = composite(c, spectrumColorOutline * (smoothstep(-oneYPoint - oneYPixel, -oneYPoint, d) - smoothstep(0., oneYPixel, d) ));

    return c;
}
