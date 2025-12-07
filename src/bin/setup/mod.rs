use std::{collections::HashSet, fs, path::Path};

// Include the generated code from build.rs
include!(concat!(env!("OUT_DIR"), "/embedded_library.rs"));

/// Extracts embedded files into the resource directory.
/// Synchronizes the directory with EMBEDDED_LIBRARY: adds missing files,
/// updates files that differ, and removes files not in EMBEDDED_LIBRARY.
pub fn load_default_library(resource_dir: &Path) {
    let library_dir = resource_dir.join("library");
    if !library_dir.exists() {
        fs::create_dir(&library_dir).unwrap();
    }

    let builtin_library_dir = resource_dir.join("builtin_library");
    if !builtin_library_dir.exists() {
        fs::create_dir(&builtin_library_dir).unwrap();
    }

    let embedded_files: HashSet<&str> = EMBEDDED_LIBRARY.iter().map(|(name, _)| *name).collect();

    let existing_files: Vec<String> = if let Ok(entries) = fs::read_dir(&builtin_library_dir) {
        entries
            .filter_map(|entry| entry.ok().and_then(|e| e.file_name().into_string().ok()))
            .collect()
    } else {
        Vec::new()
    };

    for (filename, content) in EMBEDDED_LIBRARY.iter() {
        let file_path = builtin_library_dir.join(filename);

        if let Ok(existing_content) = fs::read(&file_path) {
            if existing_content != *content {
                // Content differs, rewrite it
                match fs::write(&file_path, content) {
                    Ok(()) => println!("Updated built-in effect: {}", filename),
                    Err(e) => println!("Could not update {}: {}", file_path.display(), e),
                }
            }
        } else {
            // File doesn't exist, create it
            match fs::write(&file_path, content) {
                Ok(()) => println!("Added built-in effect: {}", filename),
                Err(e) => println!("Could not add {}: {}", file_path.display(), e),
            }
        }
    }

    // Delete files that are not in EMBEDDED_LIBRARY
    for existing_file in existing_files {
        if !embedded_files.contains(existing_file.as_str()) {
            let file_path = builtin_library_dir.join(&existing_file);
            match fs::remove_file(&file_path) {
                Ok(()) => println!("Removed file: {}", existing_file),
                Err(e) => println!("Could not remove {}: {}", file_path.display(), e),
            }
        }
    }
}
