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
  const staticDir = path.join(__dirname, "static");
  if (!fs.existsSync(staticDir)) {
    fs.mkdirSync(staticDir, { recursive: true });
  }

  const filePath = path.join(staticDir, "song.mp3");
  fs.writeFile(filePath, req.body, (err) => {
    if (err) {
      console.error("❌ Failed to write uploaded song:", err);
      return res.status(500).json({ success: false, error: err.message });
    }
    console.log("📂 Successfully uploaded new local song.mp3");
    res.json({ success: true });
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