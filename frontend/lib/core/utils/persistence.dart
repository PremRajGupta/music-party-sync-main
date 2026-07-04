import 'persistence_stub.dart'
    if (dart.library.html) 'persistence_web.dart';

abstract class Persistence {
  static void setHost(String roomId, bool isHost) {
    setHostImpl(roomId, isHost);
  }

  static bool isHost(String roomId) {
    return isHostImpl(roomId);
  }
}
