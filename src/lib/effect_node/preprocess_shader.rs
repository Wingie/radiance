pub fn preprocess_shader(effect_source: &str) -> Result<(Vec<String>, u32, f32), String> {
    let mut processed_sources = Vec::<String>::new();
    let mut processed_source = String::new();
    let mut input_count = 1;
    let mut frequency = 0.;

    for l in effect_source.lines() {
        let line_parts: Vec<&str> = l.split_whitespace().collect();
        if !line_parts.is_empty() && line_parts[0] == "#property" {
            if line_parts.len() >= 2 {
                if line_parts[1] == "inputCount" {
                    if line_parts.len() >= 3 {
                        input_count = line_parts[2].parse::<u32>().map_err(|e| e.to_string())?;
                    } else {
                        return Err(String::from("inputCount missing argument"));
                    }
                } else if line_parts[1] == "frequency" {
                    if line_parts.len() >= 3 {
                        frequency = line_parts[2].parse::<f32>().map_err(|e| e.to_string())?;
                    } else {
                        return Err(String::from("frequency missing argument"));
                    }
                } else if line_parts[1] == "description" {
                    if line_parts.len() >= 3 {
                        // TODO parse description and do something with it
                    } else {
                        return Err(String::from("description missing argument"));
                    }
                } else {
                    return Err(format!("Unrecognized property: {}", line_parts[1]));
                }
            } else {
                return Err(String::from("Missing property name"));
            }
        } else if !line_parts.is_empty() && line_parts[0] == "#buffershader" {
            processed_sources.push(std::mem::take(&mut processed_source));
        } else {
            processed_source.push_str(l);
            processed_source.push('\n');
        }
    }

    processed_sources.push(processed_source);

    Ok((processed_sources, input_count, frequency))
}
