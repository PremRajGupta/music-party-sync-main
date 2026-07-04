use std::collections::HashMap;
use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::sync::{Arc, Mutex};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Clone, Debug)]
struct Member {
    name: String,
    host: bool,
}

#[derive(Clone, Debug)]
struct Room {
    room_id: String,
    room_name: String,
    host_name: String,
    members: Vec<Member>,
}

type Rooms = Arc<Mutex<HashMap<String, Room>>>;

fn main() -> std::io::Result<()> {
    let bind_addr = std::env::var("ECHOSYNC_API_ADDR").unwrap_or_else(|_| "0.0.0.0:5000".to_string());
    let listener = TcpListener::bind(&bind_addr)?;
    let rooms = Arc::new(Mutex::new(HashMap::new()));

    println!("======================================");
    println!("🎵 EchoSync Rust Backend Listening on http://{}", bind_addr);
    println!("======================================");

    for stream in listener.incoming() {
        match stream {
            Ok(stream) => {
                let rooms = Arc::clone(&rooms);
                std::thread::spawn(move || {
                    if let Err(error) = handle_client(stream, rooms) {
                        eprintln!("request failed: {}", error);
                    }
                });
            }
            Err(error) => eprintln!("connection failed: {}", error),
        }
    }

    Ok(())
}

fn handle_client(mut stream: TcpStream, rooms: Rooms) -> std::io::Result<()> {
    let request = read_http_request(&mut stream)?;
    if request.is_empty() {
        return Ok(());
    }

    let mut lines = request.lines();
    let request_line = lines.next().unwrap_or_default();
    let mut parts = request_line.split_whitespace();
    let method = parts.next().unwrap_or_default();
    let path = parts.next().unwrap_or_default();

    let body = if let Some(idx) = request.find("\r\n\r\n") {
        &request[idx + 4..]
    } else if let Some(idx) = request.find("\n\n") {
        &request[idx + 2..]
    } else {
        request.split("\r\n\r\n").nth(1).unwrap_or_default()
    };

    println!("📥 Request: {} {} | Body: {}", method, path, body);

    match (method, path) {
        ("OPTIONS", _) => write_response(&mut stream, 204, "No Content", ""),
        ("GET", "/api/health") => write_response(&mut stream, 200, "OK", "{\"status\":\"ok\"}"),
        ("POST", "/api/rooms/create") => create_room(&mut stream, body, rooms),
        ("POST", "/api/rooms/join") => join_room(&mut stream, body, rooms),
        ("POST", "/api/rooms/delete") => delete_room(&mut stream, body, rooms),
        ("GET", path) if path.starts_with("/api/rooms/") => get_room(&mut stream, path, rooms),
        _ => write_response(
            &mut stream,
            404,
            "Not Found",
            "{\"error\":\"route not found\"}",
        ),
    }
}

fn sync_with_node(room: &Room) {
    let body = room_json(room);
    let node_addr = std::env::var("NODE_SYNC_ADDR").unwrap_or_else(|_| "127.0.0.1:5001".to_string());
    
    // Extract host name for the Host header (e.g. "music-party-socket:10000" -> "music-party-socket")
    let host_header = node_addr.split(':').next().unwrap_or("127.0.0.1");

    let request = format!(
        "POST /api/rooms/sync HTTP/1.1\r\nHost: {}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
        host_header,
        body.len(),
        body
    );

    if let Ok(mut stream) = TcpStream::connect(&node_addr) {
        let _ = stream.write_all(request.as_bytes());
        let _ = stream.flush();
        println!("🚀 Room successfully synced to Node.js socket server: {} (addr: {})", room.room_id, node_addr);
    } else {
        eprintln!("❌ Failed to connect to Node.js socket server for sync (addr: {})", node_addr);
    }
}

fn create_room(stream: &mut TcpStream, body: &str, rooms: Rooms) -> std::io::Result<()> {
    let room_name = json_string_value(body, "roomName").unwrap_or_else(|| "Music Room".to_string());
    let host_name = json_string_value(body, "hostName").unwrap_or_else(|| "Host".to_string());
    let room_id = "SB-".to_string() + &generate_room_id();

    println!("📥 Creating room request: Name={}, Host={}", room_name, host_name);

    let room = Room {
        room_id: room_id.clone(),
        room_name,
        host_name: host_name.clone(),
        members: vec![Member {
            name: host_name,
            host: true,
        }],
    };

    match rooms.lock() {
        Ok(mut lock) => { lock.insert(room_id.clone(), room.clone()); }
        Err(poisoned) => { poisoned.into_inner().insert(room_id.clone(), room.clone()); }
    };

    println!("✅ Room created successfully in memory: {}", room_id);
    
    // Sync to Node.js WebSocket server
    sync_with_node(&room);

    write_response(stream, 200, "OK", &room_json(&room))
}

fn delete_room(stream: &mut TcpStream, body: &str, rooms: Rooms) -> std::io::Result<()> {
    let room_id_raw = json_string_value(body, "roomId").unwrap_or_default();
    let normalized_id = room_id_raw.trim().to_uppercase();

    println!("📥 Room deletion request received: {}", normalized_id);

    if !normalized_id.is_empty() {
        let mut rooms_lock = rooms.lock().unwrap_or_else(|p| p.into_inner());
        rooms_lock.remove(&normalized_id);
        if !normalized_id.starts_with("SB-") {
            rooms_lock.remove(&format!("SB-{}", normalized_id));
        } else {
            rooms_lock.remove(&normalized_id[3..].to_string());
        }
        println!("🗑️ Room deleted successfully from Rust memory: {}", normalized_id);
    }

    write_response(stream, 200, "OK", "{\"success\":true}")
}

fn join_room(stream: &mut TcpStream, body: &str, rooms: Rooms) -> std::io::Result<()> {
    let room_id_raw = json_string_value(body, "roomId").unwrap_or_default();
    let user_name = json_string_value(body, "userName").unwrap_or_default();

    println!("📥 Join request received: RoomID={}, User={}", room_id_raw, user_name);

    if room_id_raw.is_empty() || user_name.is_empty() {
        println!("❌ Join request failed: Missing roomId or userName");
        return write_response(stream, 400, "Bad Request", "{\"error\":\"Missing roomId or userName\"}");
    }

    let mut rooms_lock = rooms.lock().unwrap_or_else(|p| p.into_inner());
    let normalized_id = room_id_raw.trim().to_uppercase();
    let mut target_id = String::new();

    if rooms_lock.contains_key(&normalized_id) {
        target_id = normalized_id;
    } else if !normalized_id.starts_with("SB-") {
        let prefixed = format!("SB-{}", normalized_id);
        if rooms_lock.contains_key(&prefixed) {
            target_id = prefixed;
        }
    } else if normalized_id.starts_with("SB-") {
        let unprefixed = normalized_id[3..].to_string();
        if rooms_lock.contains_key(&unprefixed) {
            target_id = unprefixed;
        }
    }

    if target_id.is_empty() {
        println!("❌ Join request failed: Room not found in memory (ID: {})", room_id_raw);
        return write_response(stream, 404, "Not Found", "{\"error\":\"room not found\"}");
    }

    if let Some(room) = rooms_lock.get_mut(&target_id) {
        let exists = room.members.iter().any(|m| m.name == user_name);
        if !exists {
            room.members.push(Member {
                name: user_name.clone(),
                host: false,
            });
            println!("👤 Added guest user {} to room {}", user_name, target_id);
        } else {
            println!("👤 User {} already in room {}", user_name, target_id);
        }
        
        let response_json = room_json(room);
        
        // Sync the updated room to Node.js WebSocket server
        sync_with_node(room);

        write_response(stream, 200, "OK", &response_json)
    } else {
        println!("❌ Join request failed: Room lock error");
        write_response(stream, 404, "Not Found", "{\"error\":\"room not found\"}")
    }
}

fn get_room(stream: &mut TcpStream, path: &str, rooms: Rooms) -> std::io::Result<()> {
    let room_id = path.trim_start_matches("/api/rooms/");
    let rooms_lock = rooms.lock().unwrap_or_else(|p| p.into_inner());

    let normalized_id = room_id.trim().to_uppercase();
    let mut target_id = String::new();

    if rooms_lock.contains_key(&normalized_id) {
        target_id = normalized_id;
    } else if !normalized_id.starts_with("SB-") {
        let prefixed = format!("SB-{}", normalized_id);
        if rooms_lock.contains_key(&prefixed) {
            target_id = prefixed;
        }
    } else if normalized_id.starts_with("SB-") {
        let unprefixed = normalized_id[3..].to_string();
        if rooms_lock.contains_key(&unprefixed) {
            target_id = unprefixed;
        }
    }

    if let Some(room) = rooms_lock.get(&target_id) {
        write_response(stream, 200, "OK", &room_json(room))
    } else {
        write_response(stream, 404, "Not Found", "{\"error\":\"room not found\"}")
    }
}

fn read_http_request(stream: &mut TcpStream) -> std::io::Result<String> {
    // Phase 1: read until we have the full header block (\r\n\r\n).
    stream.set_read_timeout(Some(std::time::Duration::from_secs(5)))?;
    let mut raw: Vec<u8> = Vec::with_capacity(4096);
    let mut tmp = [0u8; 1024];
    let header_end = loop {
        let n = stream.read(&mut tmp)?;
        if n == 0 {
            return Ok(String::new());
        }
        raw.extend_from_slice(&tmp[..n]);
        // Look for the header/body separator.
        if let Some(pos) = raw.windows(4).position(|w| w == b"\r\n\r\n") {
            break pos + 4; // first byte of body
        }
        if raw.len() > 32_768 {
            // Headers too large — bail out.
            return Ok(String::new());
        }
    };

    // Phase 2: read exactly Content-Length body bytes (if present).
    let headers_str = String::from_utf8_lossy(&raw[..header_end]).to_lowercase();
    let content_length: usize = headers_str
        .lines()
        .find(|l| l.starts_with("content-length:"))
        .and_then(|l| l.split(':').nth(1))
        .and_then(|v| v.trim().parse().ok())
        .unwrap_or(0);

    // We may have already read some body bytes beyond the header.
    let already_read = raw.len() - header_end;
    if content_length > already_read {
        let remaining = content_length - already_read;
        let mut body_buf = vec![0u8; remaining];
        stream.read_exact(&mut body_buf)?;
        raw.extend_from_slice(&body_buf);
    }

    Ok(String::from_utf8_lossy(&raw).to_string())
}

fn write_response(stream: &mut TcpStream, status_code: u16, status_text: &str, body: &str) -> std::io::Result<()> {
    let response = format!(
        "HTTP/1.1 {} {}\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: GET, POST, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
        status_code,
        status_text,
        body.len(),
        body
    );
    stream.write_all(response.as_bytes())?;
    stream.flush()
}

fn room_json(room: &Room) -> String {
    let mut members_json = String::new();
    members_json.push('[');
    for (i, member) in room.members.iter().enumerate() {
        if i > 0 {
            members_json.push(',');
        }
        members_json.push_str(&format!(
            "{{\"name\":\"{}\",\"host\":{}}}",
            json_escape(&member.name),
            member.host
        ));
    }
    members_json.push(']');

    format!(
        "{{\"success\":true,\"room\":{{\"roomId\":\"{}\",\"roomName\":\"{}\",\"hostName\":\"{}\",\"members\":{},\"currentSongIndex\":-1,\"isPlaying\":false,\"progress\":0.0,\"localSongName\":null}}}}",
        json_escape(&room.room_id),
        json_escape(&room.room_name),
        json_escape(&room.host_name),
        members_json
    )
}

fn json_string_value(body: &str, key: &str) -> Option<String> {
    let key_pattern = format!("\"{}\"", key);
    let index = body.find(&key_pattern)?;
    let start = body[index..].find(':')? + index + 1;
    let val_str = &body[start..].trim_start();
    if val_str.starts_with('"') {
        let end = val_str[1..].find('"')? + 1;
        Some(json_unescape(&val_str[1..end]))
    } else {
        None
    }
}

fn json_unescape(escaped: &str) -> String {
    let mut value = String::new();
    let mut chars = escaped.chars();
    while let Some(ch) = chars.next() {
        match ch {
            '"' => return value,
            '\\' => {
                if let Some(escaped_char) = chars.next() {
                    value.push(match escaped_char {
                        '"' => '"',
                        '\\' => '\\',
                        '/' => '/',
                        'n' => '\n',
                        'r' => '\r',
                        't' => '\t',
                        other => other,
                    });
                }
            }
            other => value.push(other),
        }
    }
    value
}

fn json_escape(value: &str) -> String {
    value
        .chars()
        .flat_map(|ch| match ch {
            '"' => "\\\"".chars().collect::<Vec<_>>(),
            '\\' => "\\\\".chars().collect::<Vec<_>>(),
            '\n' => "\\n".chars().collect::<Vec<_>>(),
            '\r' => "\\r".chars().collect::<Vec<_>>(),
            '\t' => "\\t".chars().collect::<Vec<_>>(),
            other => vec![other],
        })
        .collect()
}

fn generate_room_id() -> String {
    let millis = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis();
    let short = millis % 36_u128.pow(6);
    format!("{:0>6}", to_base36(short)).to_uppercase()
}

fn to_base36(mut value: u128) -> String {
    const DIGITS: &[u8; 36] = b"0123456789abcdefghijklmnopqrstuvwxyz";

    if value == 0 {
        return "0".to_string();
    }

    let mut chars = Vec::new();
    while value > 0 {
        let digit = (value % 36) as usize;
        chars.push(DIGITS[digit] as char);
        value /= 36;
    }

    chars.iter().rev().collect()
}
