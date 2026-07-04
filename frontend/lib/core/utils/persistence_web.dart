import 'dart:html' as html;

void setHostImpl(String roomId, bool isHost) {
  html.window.localStorage['is_host_$roomId'] = isHost.toString();
}

bool isHostImpl(String roomId) {
  return html.window.localStorage['is_host_$roomId'] == 'true';
}
