const { v4: uuidv4 } = require("uuid");
const { getIO } = require("../services/socketService");

// Pure in-memory rooms storage to prevent blocking the event loop
const rooms = {};

// Helper to save rooms (no-op since we are purely in-memory)
const saveRooms = (roomsData) => {};

const createRoom = (req, res) => {
  const { roomName, hostName } = req.body;

  const roomId = "SB-" + uuidv4().substring(0, 6).toUpperCase();

  rooms[roomId] = {
    roomId,
    roomName,
    hostName,
    members: [
      {
        name: hostName,
        host: true,
      },
    ],
    currentSongIndex: -1,
    isPlaying: false,
    progress: 0.0,
    localSongName: null,
    createdAt: new Date(),
  };

  saveRooms(rooms);

  res.status(201).json({
    success: true,
    room: rooms[roomId],
  });
};

const findRoomById = (id) => {
  if (!id) return null;
  const normalizedId = id.trim().toUpperCase();
  
  // Try exact match
  if (rooms[normalizedId]) return rooms[normalizedId];

  // Try with SB- prefix added
  if (!normalizedId.startsWith("SB-")) {
    const prefixedId = "SB-" + normalizedId;
    if (rooms[prefixedId]) return rooms[prefixedId];
  }

  // Try with SB- prefix removed
  if (normalizedId.startsWith("SB-")) {
    const unprefixedId = normalizedId.substring(3);
    if (rooms[unprefixedId]) return rooms[unprefixedId];
  }

  return null;
};

const joinRoom = (req, res) => {
  const { roomId, userName } = req.body;

  const room = findRoomById(roomId);

  if (!room) {
    return res.status(404).json({
      success: false,
      message: "Room not found",
    });
  }

  // Prevent duplicate names
  const exists = room.members.find(
    (member) => member.name === userName,
  );

  if (!exists) {
    room.members.push({
      name: userName,
      host: false,
    });
    saveRooms(rooms);
  }

  // Broadcast updated room to everyone connected using actual room ID
  try {
    const io = getIO();
    io.to(room.roomId).emit("room-updated", room);
    console.log(`📢 Room Updated and Broadcasted: ${room.roomId}`);
  } catch (err) {
    console.log("Socket not initialized yet.");
  }

  res.json({
    success: true,
    room,
  });
};

const getRoom = (req, res) => {
  const room = findRoomById(req.params.roomId);

  if (!room) {
    return res.status(404).json({
      success: false,
      message: "Room not found",
    });
  }

  res.json({
    success: true,
    room,
  });
};

const syncRoom = (req, res) => {
  const roomData = req.body.room || req.body;
  const { roomId, roomName, hostName, members, currentSongIndex, isPlaying, progress, localSongName } = roomData;

  if (!roomId) {
    return res.status(400).json({ success: false, message: "Invalid room data" });
  }

  rooms[roomId] = {
    roomId,
    roomName,
    hostName,
    members: members || [],
    currentSongIndex: currentSongIndex !== undefined ? currentSongIndex : -1,
    isPlaying: isPlaying || false,
    progress: progress || 0.0,
    localSongName: localSongName || null,
    updatedAt: new Date(),
  };

  saveRooms(rooms);

  // Broadcast updated room to all connected WebSockets
  try {
    const io = getIO();
    io.to(roomId).emit("room-updated", rooms[roomId]);
    console.log(`📢 Room Synced and Broadcasted via WebSockets: ${roomId} (Members: ${rooms[roomId].members.length})`);
  } catch (err) {
    console.log("Socket not initialized yet:", err.message);
  }

  res.json({
    success: true,
    room: rooms[roomId],
  });
};

module.exports = {
  rooms,
  saveRooms,
  createRoom,
  joinRoom,
  getRoom,
  syncRoom,
};