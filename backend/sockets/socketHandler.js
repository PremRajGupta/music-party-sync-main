const { rooms, saveRooms } = require("../controllers/roomController");

module.exports = (io) => {
  io.on("connection", (socket) => {
    console.log(`✅ User Connected: ${socket.id}`);

    const handleUserLeaving = (roomId) => {
      if (!roomId || !rooms[roomId]) return;
      const room = rooms[roomId];
      
      if (socket.userName) {
        if (socket.userName === room.hostName) {
          console.log(`📢 Host ${socket.userName} left/disconnected. Cancelling room ${roomId}`);
          io.to(roomId).emit("room-cancelled");
          delete rooms[roomId];
          saveRooms(rooms);
        } else {
          const initialLen = room.members.length;
          room.members = room.members.filter(m => m.name !== socket.userName);
          if (room.members.length !== initialLen) {
            console.log(`🗑️ Removed guest ${socket.userName} from room ${roomId}`);
            saveRooms(rooms);
            io.to(roomId).emit("room-updated", room);
          }
        }
      }
    };

    // Join a Room
    socket.on("join-room", (data) => {
      let roomId = data;
      let userName = null;
      if (typeof data === "object" && data !== null) {
        roomId = data.roomId;
        userName = data.userName;
      }

      socket.join(roomId);
      console.log(`📥 Socket ${socket.id} joined room ${roomId}`);
      
      if (roomId) {
        socket.roomId = roomId;
      }
      if (userName) {
        socket.userName = userName;
      }

      if (roomId) {
        // Auto-create room in Node.js if it doesn't exist (failsafe)
        if (!rooms[roomId]) {
          rooms[roomId] = {
            roomId,
            roomName: "Music Room",
            hostName: userName || "Host",
            members: [],
            currentSongIndex: -1,
            isPlaying: false,
            progress: 0.0,
            localSongName: null,
          };
        }
        
        const room = rooms[roomId];
        if (userName) {
          const exists = room.members.find(m => m.name === userName);
          if (!exists) {
            const isHost = userName === room.hostName;
            room.members.push({
              name: userName,
              host: isHost,
            });
            saveRooms(rooms);
          }
        }
        
        // Broadcast updated room to all connected WebSockets
        io.to(roomId).emit("room-updated", room);
      }
      
      // Request current playback status from the Host so the guest is synced immediately
      socket.to(roomId).emit("request-host-sync", roomId);
    });

    // Leave a Room
    socket.on("leave-room", (roomId) => {
      handleUserLeaving(roomId);
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
      if (socket.roomId) {
        handleUserLeaving(socket.roomId);
      }
    });
  });
};