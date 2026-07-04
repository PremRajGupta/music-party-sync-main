const express = require("express");
const http = require("http");
const { Server } = require("socket.io");
const cors = require("cors");
const fs = require("fs");
const path = require("path");

const roomRoutes = require("./routes/roomRoutes");
const socketHandler = require("./sockets/socketHandler");
const { initSocket } = require("./services/socketService");

const app = express();
const server = http.createServer(app);

// ================================
// Socket.IO
// ================================
const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
  },
});

// Initialize Socket Service
initSocket(io);

// ================================
// Middleware
// ================================
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve static files from the "static" folder
app.use("/static", express.static(path.join(__dirname, "static")));

// ================================
// File Upload Endpoint
// ================================
app.post("/api/upload", express.raw({ type: "*/*", limit: "50mb" }), (req, res) => {
  const body = req.body;
  if (!body || body.length < 4) {
    return res.status(400).json({ success: false, error: "Empty file" });
  }

  // Validate it looks like an audio file (MP3/M4A/WAV magic bytes)
  const isMP3 = body[0] === 0xFF && (body[1] & 0xE0) === 0xE0;
  const isID3 = body[0] === 0x49 && body[1] === 0x44 && body[2] === 0x33; // ID3
  const isM4A = body[4] === 0x66 && body[5] === 0x74 && body[6] === 0x79 && body[7] === 0x70; // ftyp
  const isWAV = body[0] === 0x52 && body[1] === 0x49 && body[2] === 0x46 && body[3] === 0x46; // RIFF
  if (!isMP3 && !isID3 && !isM4A && !isWAV) {
    return res.status(400).json({ success: false, error: "Invalid audio file" });
  }

  const staticDir = path.join(__dirname, "static");
  if (!fs.existsSync(staticDir)) {
    fs.mkdirSync(staticDir, { recursive: true });
  }

  const tempPath = path.join(staticDir, `song_${Date.now()}.tmp`);
  const finalPath = path.join(staticDir, "song.mp3");

  fs.writeFile(tempPath, body, (err) => {
    if (err) {
      console.error("❌ Failed to write temp uploaded song:", err);
      return res.status(500).json({ success: false, error: err.message });
    }

    fs.rename(tempPath, finalPath, (renameErr) => {
      if (renameErr) {
        console.error("❌ Failed to rename uploaded song:", renameErr);
        fs.unlink(tempPath, () => {});
        return res.status(500).json({ success: false, error: renameErr.message });
      }
      console.log("📂 Successfully uploaded and atomized new local song.mp3");
      res.json({ success: true });
    });
  });
});

// ================================
// Health Check
// ================================
app.get("/", (req, res) => {
  res.json({
    success: true,
    app: "SyncBeat Backend",
    version: "1.0.0",
    status: "Running",
  });
});

// ================================
// API Routes
// ================================
app.use("/api/rooms", roomRoutes);

// ================================
// Socket Handler
// ================================
socketHandler(io);

// ================================
// Server
// ================================
const PORT = process.env.PORT || 5001;

server.listen(PORT, () => {
  console.log("======================================");
  console.log("🎵 SyncBeat Backend Started");
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`🌐 http://localhost:${PORT}`);
  console.log("======================================");
});