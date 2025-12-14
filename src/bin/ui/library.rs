use radiance::{
    EffectNodeProps, ImageNodeProps, NodeProps, ProjectionMappedOutputNodeProps,
    ScreenOutputNodeProps, UiBgNodeProps,
};
use std::sync::{Arc, Mutex};

#[cfg(feature = "mpv")]
use radiance::MovieNodeProps;

#[derive(Debug, Default)]
struct LibraryMemory {
    textedit: String,
}

#[derive(Debug)]
pub enum LibraryResponse {
    None,
    Close,
    AddNode(NodeProps),
}

/// Renders the library widget
pub fn library_ui(ui: &mut egui::Ui, newly_opened: bool) -> LibraryResponse {
    let library_id = ui.make_persistent_id("library");

    let library_memory = ui.ctx().memory_mut(|m| {
        m.data
            .get_temp_mut_or_default::<Arc<Mutex<LibraryMemory>>>(library_id)
            .clone()
    });

    let mut library_memory = library_memory.lock().unwrap();

    let textbox_response = ui.text_edit_singleline(&mut library_memory.textedit);

    if newly_opened {
        textbox_response.request_focus();
    }

    if textbox_response.lost_focus() {
        if ui.ctx().input(|i| i.key_pressed(egui::Key::Enter)) {
            let node_props = parse_input(library_memory.textedit.as_str());
            library_memory.textedit.clear();
            if let Some(node_props) = node_props {
                LibraryResponse::AddNode(node_props)
            } else {
                LibraryResponse::Close
            }
        } else {
            library_memory.textedit.clear();
            LibraryResponse::Close
        }
    } else {
        LibraryResponse::None
    }
}

/// Parses the library textbox input and returns NodeProps if valid
fn parse_input(input: &str) -> Option<NodeProps> {
    if input.is_empty() {
        return None;
    }

    // Check for video files
    if input.starts_with("file:")
        || input.starts_with("http:")
        || input.starts_with("https:")
        || input.starts_with("ytdl:")
        || input.starts_with("lavf:")
        || input.starts_with("av:")
        || input.ends_with(".mp4")
        || input.ends_with(".mkv")
        || input.ends_with(".avi")
    {
        #[cfg(feature = "mpv")]
        {
            return Some(NodeProps::MovieNode(MovieNodeProps {
                name: input.to_string(),
                ..MovieNodeProps::default()
            }));
        }
        #[cfg(not(feature = "mpv"))]
        {
            println!(
                "Cannot instantiate MovieNode for {}, mpv support is not enabled",
                input
            );
            return None;
        }
    }

    // Check for image files
    if input.ends_with(".png") || input.starts_with(".jpg") || input.ends_with(".gif") {
        return Some(NodeProps::ImageNode(ImageNodeProps {
            name: input.to_string(),
            ..ImageNodeProps::default()
        }));
    }

    // Check for special node types
    Some(match input {
        "UiBg" => NodeProps::UiBgNode(UiBgNodeProps::default()),
        "ScreenOutput" => NodeProps::ScreenOutputNode(ScreenOutputNodeProps::default()),
        "ProjectionMappedOutput" => {
            NodeProps::ProjectionMappedOutputNode(ProjectionMappedOutputNodeProps::default())
        }
        _ => {
            // Default to EffectNode
            NodeProps::EffectNode(EffectNodeProps {
                name: input.to_string(),
                ..EffectNodeProps::default()
            })
        }
    })
}
