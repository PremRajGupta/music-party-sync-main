const express = require("express");
const router = express.Router();
const { createRoom, joinRoom, getRoom, syncRoom } = require("../controllers/roomController");

router.post("/create", createRoom);
router.post("/join", joinRoom);
router.post("/sync", syncRoom);
router.get("/:roomId", getRoom);

module.exports = router;
