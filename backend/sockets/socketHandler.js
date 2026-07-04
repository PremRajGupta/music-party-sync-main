const { rooms, saveRooms } = require("../controllers/roomController");

module.exports = (io) => {
  io.on("connection", (socket) => {
    console.log(`✅ User Connected: ${socket.id}`);

    // Join a Room
    socket.on("join-room", (roomId) => {
      socket.join(roomId);
      console.log(`📥 Socket ${socket.id} joined room ${roomId}`);
      
      // Request current playback status from the Host so the guest is synced immediately
      socket.to(roomId).emit("request-host-sync", roomId);
    });

    // Leave a Room
    socket.on("leave-room", (roomId) => {
      socket.leave(roomId);
      console.log(`📤 Socket ${socket.id} left room ${roomId}`);
    });

    // Start Party
    socket.on("start-party", (roomId) => {
      console.log(`🎵 Party Started in ${roomId}`);
      io.to(roomId).emit("party-started");
    });

    // Media Toggle (Play / Pause)
    socket.on("media-toggle", (data) => {
      const { roomId, isPlaying } = data;
      if (rooms[roomId]) {
        rooms[roomId].isPlaying = isPlaying;
        saveRooms(rooms);
      }
      socket.to(roomId).emit("media-toggle-broadcast", data);
    });

    // Media Seek
    socket.on("media-seek", (data) => {
      const { roomId, progress } = data;
      if (rooms[roomId]) {
        rooms[roomId].progress = progress;
        saveRooms(rooms);
      }
      socket.to(roomId).emit("media-seek-broadcast", data);
    });

    // Media Change (Playlist song change)
    socket.on("media-change", (data) => {
      const { roomId, songIndex } = data;
      if (rooms[roomId]) {
        rooms[roomId].currentSongIndex = songIndex;
        rooms[roomId].localSongName = null;
        rooms[roomId].progress = 0.0;
        rooms[roomId].isPlaying = true;
        saveRooms(rooms);
      }
      socket.to(roomId).emit("media-change-broadcast", data);
    });

    // Media Local Change (Host local file upload change)
    socket.on("media-local-change", (data) => {
      const { roomId, songName } = data;
      if (rooms[roomId]) {
        rooms[roomId].localSongName = songName;
        rooms[roomId].progress = 0.0;
        rooms[roomId].isPlaying = true;
        saveRooms(rooms);
      }
      socket.to(roomId).emit("media-local-change-broadcast", data);
    });

    // Disconnect
    socket.on("disconnect", () => {
      console.log(`❌ User Disconnected: ${socket.id}`);
    });
  });
};