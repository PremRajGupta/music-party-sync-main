final Map<String, bool> _hostMap = {};

void setHostImpl(String roomId, bool isHost) {
  _hostMap[roomId] = isHost;
}

bool isHostImpl(String roomId) {
  return _hostMap[roomId] ?? false;
}
