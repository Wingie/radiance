use std::collections::HashMap;

use radiance::{ArcTextureViewSampler, NodeId, RenderTarget, RenderTargetId, UiBgNodeProps};

#[derive(Debug)]
pub struct UiBg {
    _shader_module: wgpu::ShaderModule,
    bind_group_1_layout: wgpu::BindGroupLayout,
    bind_group_2_layout: wgpu::BindGroupLayout,
    _render_pipeline_layout: wgpu::PipelineLayout,
    render_pipeline: wgpu::RenderPipeline,
    render_target: Option<(RenderTargetId, RenderTarget)>,
    passes: Vec<UiBgPass>,
}

#[derive(Debug)]
struct UiBgPass {
    texture: ArcTextureViewSampler,
    uniform_buffer: wgpu::Buffer,
}

// The uniform buffer associated with the effect
#[repr(C)]
#[derive(Default, Debug, Copy, Clone, bytemuck::Pod, bytemuck::Zeroable)]
struct Uniforms {
    opacity: f32,
}

impl UiBg {
    pub fn new(device: &wgpu::Device, surface_format: wgpu::TextureFormat) -> Self {
        // Set up WGPU resources for drawing the UI BG
        let shader_module = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("BG output shader"),
            source: wgpu::ShaderSource::Wgsl(include_str!("bg.wgsl").into()),
        });
        let bind_group_1_layout =
            device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                entries: &[wgpu::BindGroupLayoutEntry {
                    binding: 0, // UpdateUniforms
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Buffer {
                        ty: wgpu::BufferBindingType::Uniform,
                        has_dynamic_offset: false,
                        min_binding_size: None,
                    },
                    count: None,
                }],
                label: Some("bg bind group layout 1 (uniforms)"),
            });
        let bind_group_2_layout =
            device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                entries: &[
                    wgpu::BindGroupLayoutEntry {
                        binding: 0,
                        visibility: wgpu::ShaderStages::FRAGMENT,
                        ty: wgpu::BindingType::Texture {
                            multisampled: false,
                            view_dimension: wgpu::TextureViewDimension::D2,
                            sample_type: wgpu::TextureSampleType::Float { filterable: true },
                        },
                        count: None,
                    },
                    wgpu::BindGroupLayoutEntry {
                        binding: 1,
                        visibility: wgpu::ShaderStages::FRAGMENT,
                        ty: wgpu::BindingType::Sampler(wgpu::SamplerBindingType::Filtering),
                        count: None,
                    },
                ],
                label: Some("bg bind group layout 2 (textures)"),
            });
        let render_pipeline_layout =
            device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
                label: Some("bg render pipeline layout"),
                bind_group_layouts: &[&bind_group_1_layout, &bind_group_2_layout],
                push_constant_ranges: &[],
            });

        // Make BG render pipeline
        let render_pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("bg render pipeline"),
            layout: Some(&render_pipeline_layout),
            vertex: wgpu::VertexState {
                module: &shader_module,
                entry_point: Some("vs_main"),
                buffers: &[],
                compilation_options: Default::default(),
            },
            fragment: Some(wgpu::FragmentState {
                module: &shader_module,
                entry_point: Some("fs_main"),
                targets: &[Some(wgpu::ColorTargetState {
                    format: surface_format,
                    blend: Some(wgpu::BlendState::PREMULTIPLIED_ALPHA_BLENDING),
                    write_mask: wgpu::ColorWrites::ALL,
                })],
                compilation_options: Default::default(),
            }),
            primitive: wgpu::PrimitiveState {
                topology: wgpu::PrimitiveTopology::TriangleStrip,
                strip_index_format: None,
                front_face: wgpu::FrontFace::Ccw,
                cull_mode: Some(wgpu::Face::Back),
                polygon_mode: wgpu::PolygonMode::Fill,
                unclipped_depth: false,
                conservative: false,
            },
            depth_stencil: None,
            multisample: wgpu::MultisampleState {
                count: 1,
                mask: !0,
                alpha_to_coverage_enabled: false,
            },
            multiview: None,
            cache: None,
        });

        Self {
            _shader_module: shader_module,
            bind_group_1_layout,
            bind_group_2_layout,
            _render_pipeline_layout: render_pipeline_layout,
            render_pipeline,
            render_target: None,
            passes: vec![],
        }
    }

    pub fn render_target(&self) -> (&RenderTargetId, &RenderTarget) {
        let (render_target_id, render_target) = self.render_target.as_ref().unwrap();
        (render_target_id, render_target)
    }

    pub fn create_or_update_render_target(&mut self, width: u32, height: u32) {
        if !self
            .render_target
            .as_ref()
            .is_some_and(|(_, rt)| rt.width() == width && rt.height() == height)
        {
            self.render_target = Some((
                RenderTargetId::gen(),
                RenderTarget::new(width, height, 1. / 60.),
            ));
        }
    }

    pub fn update(
        &mut self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        props: &radiance::Props,
        paint_results: &HashMap<NodeId, ArcTextureViewSampler>,
    ) {
        // Collect and upload data related to the UI BG drawing
        let mut passes: Vec<_> = paint_results
            .iter()
            .enumerate()
            .filter_map(|(i, (&node_id, texture))| {
                props
                    .node_props
                    .get(&node_id)
                    .and_then(|props| <&UiBgNodeProps>::try_from(props).ok())
                    .map(|&UiBgNodeProps { opacity }| {
                        let uniform_buffer = if let Some(UiBgPass { uniform_buffer, .. }) =
                            self.passes.get(i)
                        {
                            // Re-use the buffer if one exists
                            uniform_buffer.clone()
                        } else {
                            // Otherwise create a new buffer
                            device.create_buffer(&wgpu::BufferDescriptor {
                                label: Some("bg uniform buffer"),
                                size: std::mem::size_of::<Uniforms>() as u64,
                                usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
                                mapped_at_creation: false,
                            })
                        };

                        // Write to the buffer
                        let uniforms = Uniforms { opacity };
                        queue.write_buffer(&uniform_buffer, 0, bytemuck::cast_slice(&[uniforms]));

                        // Return the pass
                        (
                            node_id,
                            UiBgPass {
                                texture: texture.clone(),
                                uniform_buffer,
                            },
                        )
                    })
            })
            .collect();

        // Sort by node ID to maintain a stable superposition
        passes.sort_by_key(|&(node_id, _)| node_id);
        self.passes = passes.into_iter().map(|(_, pass)| pass).collect();
    }

    pub fn render(&self, device: &wgpu::Device, render_pass: &mut wgpu::RenderPass) {
        // Draw the UI BG
        for UiBgPass {
            texture,
            uniform_buffer,
        } in self.passes.iter()
        {
            let bind_group_1 = device.create_bind_group(&wgpu::BindGroupDescriptor {
                layout: &self.bind_group_1_layout,
                entries: &[wgpu::BindGroupEntry {
                    binding: 0,
                    resource: uniform_buffer.as_entire_binding(),
                }],
                label: Some("bg bind group 1 (uniforms)"),
            });
            let bind_group_2 = device.create_bind_group(&wgpu::BindGroupDescriptor {
                layout: &self.bind_group_2_layout,
                entries: &[
                    wgpu::BindGroupEntry {
                        binding: 0,
                        resource: wgpu::BindingResource::TextureView(&texture.view),
                    },
                    wgpu::BindGroupEntry {
                        binding: 1,
                        resource: wgpu::BindingResource::Sampler(&texture.sampler),
                    },
                ],
                label: Some("bg bind group 2 (texture)"),
            });

            render_pass.set_pipeline(&self.render_pipeline);
            render_pass.set_bind_group(0, &bind_group_1, &[]);
            render_pass.set_bind_group(1, &bind_group_2, &[]);
            render_pass.draw(0..6, 0..1);
        }
    }
}
