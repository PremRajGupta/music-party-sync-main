import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/socket_service.dart';
import '../../models/room.dart';
import '../../shared/widgets/page_background.dart';
import '../../shared/widgets/primary_button.dart';
import '../../core/services/room_service.dart';
import '../../core/services/api_service.dart';
import '../settings/settings_screen.dart';

class PlayerScreen extends StatefulWidget {
  final Room room;

  const PlayerScreen({super.key, required this.room});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _pulseController;
  late final AnimationController _equalizerController;
  late final AnimationController _djLightsController;

  final AudioPlayer _audioPlayer = AudioPlayer();
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  Duration _hostPosition = Duration.zero;
  Duration _hostDuration = Duration.zero;

  late Room room;
  bool isPlaying = false;

  double progress = 0.0;
  double volume = 0.65;

  final List<Map<String, dynamic>> playlist = [];

  final List<List<Color>> artGradients = [
    [const Color(0xFF00D4FF), const Color(0xFF7B61FF)],
    [const Color(0xFFFF416C), const Color(0xFFFF4B2B)],
    [const Color(0xFF11998E), const Color(0xFF38EF7D)],
    [const Color(0xFFF12711), const Color(0xFFF5AF19)],
  ];

  int currentSongIndex = -1;
  DateTime _lastPositionEmit = DateTime.now();
  bool _tunedIn = false;
  bool _initialSeekDone = false;

  @override
  void initState() {
    super.initState();
    room = widget.room;

    // Set up audioplayer listeners
    _audioPlayer.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() {
        _duration = d;
      });

      final isHost = SocketService.instance.userName == room.hostName;
      if (!isHost && _tunedIn && !_initialSeekDone && d.inMilliseconds > 0 && progress > 0) {
        _initialSeekDone = true;
        final targetMs = (progress * d.inMilliseconds).toInt();
        _audioPlayer.seek(Duration(milliseconds: targetMs));
      }
    });

    _audioPlayer.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() {
        _position = p;
        if (_duration.inMilliseconds > 0) {
          progress = p.inMilliseconds / _duration.inMilliseconds;
        }
      });

      // Periodic progress sync (every 1 second) if we are the host and playing
      final isHost = SocketService.instance.userName == room.hostName;
      if (isHost && isPlaying) {
        final now = DateTime.now();
        if (now.difference(_lastPositionEmit).inMilliseconds > 1000) {
          _lastPositionEmit = now;
          SocketService.instance.sendSeek(
            room.roomId, 
            progress,
            positionMs: _position.inMilliseconds,
            durationMs: _duration.inMilliseconds,
          );
        }
      }
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      if (!mounted) return;
      setState(() {
        _position = Duration.zero;
        progress = 0.0;
      });
      _updatePlaybackState(false, localEmit: true);
    });

    // Listen for room updates (dynamic device list)
    SocketService.instance.onRoomUpdated((data) {
      final updatedRoom = Room.fromJson(data);
      if (!mounted) return;
      setState(() {
        room = updatedRoom;
      });
    });

    // Listen for play/pause sync
    SocketService.instance.onPlaybackStateChanged((data) {
      final isPlayingSync = data["isPlaying"] as bool;
      if (!mounted) return;
      _updatePlaybackState(isPlayingSync, localEmit: false);
    });

    // Listen for seek sync
    SocketService.instance.onSeekChanged((data) {
      final progressSync = (data["progress"] as num).toDouble();
      final positionMsSync = data["positionMs"] as int?;
      final durationMsSync = data["durationMs"] as int?;

      if (!mounted) return;
      setState(() {
        progress = progressSync;
        if (positionMsSync != null) {
          _hostPosition = Duration(milliseconds: positionMsSync);
        }
        if (durationMsSync != null) {
          _hostDuration = Duration(milliseconds: durationMsSync);
        }
        final targetMs = (progressSync * _duration.inMilliseconds).toInt();
        _audioPlayer.seek(Duration(milliseconds: targetMs));
      });
    });

    // Listen for song change sync
    SocketService.instance.onSongChanged((data) {
      final songIndexSync = data["songIndex"] as int;
      if (!mounted) return;
      setState(() {
        currentSongIndex = songIndexSync;
        _initialSeekDone = false;
      });
      _playSong();
    });

    // Listen for local song change sync
    SocketService.instance.onLocalSongChanged((data) {
      final songName = data["songName"] as String;
      if (!mounted) return;

      int existingIndex = playlist.indexWhere((song) => song["title"] == songName);
      if (existingIndex == -1) {
        playlist.add({
          "title": songName,
          "artist": "Sync Local File",
          "url": "https://music-party-socket.onrender.com/static/song.mp3?t=${DateTime.now().millisecondsSinceEpoch}",
          "bytes": null,
        });
        artGradients.add([const Color(0xFF8A2387), const Color(0xFFE94057)]);
        existingIndex = playlist.length - 1;
      } else {
        playlist[existingIndex]["url"] = "https://music-party-socket.onrender.com/static/song.mp3?t=${DateTime.now().millisecondsSinceEpoch}";
      }
      setState(() {
        currentSongIndex = existingIndex;
        _initialSeekDone = false;
      });
      _playSong();
    });

    // Listen for host sync requests (when a new guest joins)
    final isHost = SocketService.instance.userName == room.hostName;
    if (isHost) {
      SocketService.instance.onRequestHostSync((data) {
        if (!mounted) return;
        SocketService.instance.sendSeek(
          room.roomId, 
          progress,
          positionMs: _position.inMilliseconds,
          durationMs: _duration.inMilliseconds,
        );
        SocketService.instance.sendPlaybackState(room.roomId, isPlaying);
        if (currentSongIndex != -1) {
          SocketService.instance.sendSongChange(room.roomId, currentSongIndex);
        }
      });
    }

    SocketService.instance.onRoomCancelled(() {
      if (!mounted) return;
      _audioPlayer.pause();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("The host has closed this room."),
          backgroundColor: Colors.redAccent,
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    });

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.92,
      upperBound: 1.05,
    );

    _equalizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _djLightsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _syncPlaybackWithServer();
  }

  Future<void> _setInitialSource() async {
    if (playlist.isEmpty || currentSongIndex == -1) return;
    final currentSong = playlist[currentSongIndex];
    try {
      if (currentSong["bytes"] != null) {
        await _audioPlayer
            .setSource(BytesSource(currentSong["bytes"] as Uint8List))
            .timeout(const Duration(seconds: 2))
            .catchError((e) {
              debugPrint("Error setting initial source bytes: $e");
              return null;
            });
      } else {
        final url = currentSong["url"] ?? "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3";
        await _audioPlayer
            .setSource(UrlSource(url as String))
            .timeout(const Duration(seconds: 2))
            .catchError((e) {
              debugPrint("Error setting initial source url: $e");
              return null;
            });
      }
      await _audioPlayer
          .setVolume(volume)
          .timeout(const Duration(seconds: 2))
          .catchError((e) {
            debugPrint("Error setting volume: $e");
            return null;
          });
    } catch (e) {
      debugPrint("Error setting initial source: $e");
    }
  }

  Future<void> _syncPlaybackWithServer() async {
    final isHost = SocketService.instance.userName == room.hostName;
    try {
      final latestRoom = await RoomService.getRoom(room.roomId);
      if (!mounted) return;
      
      setState(() {
        room = latestRoom;
        currentSongIndex = latestRoom.currentSongIndex;
        isPlaying = latestRoom.isPlaying;
        progress = latestRoom.progress;
        _initialSeekDone = false;
      });

      if (latestRoom.localSongName != null) {
        int existingIndex = playlist.indexWhere((song) => song["title"] == latestRoom.localSongName);
        if (existingIndex == -1) {
          playlist.add({
            "title": latestRoom.localSongName!,
            "artist": "Sync Local File",
            "url": "https://music-party-socket.onrender.com/static/song.mp3?t=${DateTime.now().millisecondsSinceEpoch}",
            "bytes": null,
          });
          artGradients.add([const Color(0xFF8A2387), const Color(0xFFE94057)]);
          existingIndex = playlist.length - 1;
        } else {
          playlist[existingIndex]["url"] = "https://music-party-socket.onrender.com/static/song.mp3?t=${DateTime.now().millisecondsSinceEpoch}";
        }
        setState(() {
          currentSongIndex = existingIndex;
        });
      }

      if (playlist.isEmpty || currentSongIndex == -1) return;

      final currentSong = playlist[currentSongIndex];
      try {
        if (currentSong["bytes"] != null) {
          await _audioPlayer
              .setSource(BytesSource(currentSong["bytes"] as Uint8List))
              .timeout(const Duration(seconds: 2))
              .catchError((e) {
                debugPrint("Error setting sync source bytes: $e");
                return null;
              });
        } else {
          final url = currentSong["url"] ?? "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3";
          await _audioPlayer
              .setSource(UrlSource(url as String))
              .timeout(const Duration(seconds: 2))
              .catchError((e) {
                debugPrint("Error setting sync source url: $e");
                return null;
              });
        }
        await _audioPlayer
            .setVolume(volume)
            .timeout(const Duration(seconds: 2))
            .catchError((e) {
              debugPrint("Error setting sync volume: $e");
              return null;
            });
      } catch (e) {
        debugPrint("Error setting sync source: $e");
      }

      if (isPlaying && (isHost || _tunedIn)) {
        try {
          if (currentSong["bytes"] != null) {
            await _audioPlayer
                .play(BytesSource(currentSong["bytes"] as Uint8List))
                .timeout(const Duration(seconds: 2))
                .catchError((e) {
                  debugPrint("Error playing sync bytes: $e");
                  return null;
                });
          } else {
            final url = currentSong["url"] ?? "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3";
            await _audioPlayer
                .play(UrlSource(url as String))
                .timeout(const Duration(seconds: 2))
                .catchError((e) {
                  debugPrint("Error playing sync url: $e");
                  return null;
                });
          }
        } catch (e) {
          debugPrint("Error playing sync audio: $e");
        }
        if (progress > 0) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!mounted) return;
            final targetMs = (progress * _duration.inMilliseconds).toInt();
            if (targetMs > 0) {
              _audioPlayer.seek(Duration(milliseconds: targetMs));
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error syncing room playback state: $e");
      _setInitialSource();
    }
  }

  void _updatePlaybackState(bool playing, {required bool localEmit}) {
    setState(() {
      isPlaying = playing;
    });

    if (playing) {
      _audioPlayer.resume();
      _rotationController.repeat();
      _pulseController.repeat(reverse: true);
      _equalizerController.repeat(reverse: true);
      _djLightsController.repeat(reverse: true);
    } else {
      _audioPlayer.pause();
      _rotationController.stop();
      _pulseController.stop();
      _equalizerController.stop();
      _djLightsController.stop();
    }

    if (localEmit) {
      SocketService.instance.sendPlaybackState(room.roomId, playing);
    }
  }

  Future<void> _playSong() async {
    if (playlist.isEmpty || currentSongIndex == -1) return;
    final currentSong = playlist[currentSongIndex];
    try {
      if (currentSong["bytes"] != null) {
        await _audioPlayer
            .play(BytesSource(currentSong["bytes"] as Uint8List))
            .timeout(const Duration(seconds: 2))
            .catchError((e) {
              debugPrint("Error playing audio bytes: $e");
              return null;
            });
      } else {
        final url = currentSong["url"] ?? "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3";
        await _audioPlayer
            .play(UrlSource(url as String))
            .timeout(const Duration(seconds: 2))
            .catchError((e) {
              debugPrint("Error playing audio url: $e");
              return null;
            });
      }
    } catch (e) {
      debugPrint("Error playing audio: $e");
    }
    _updatePlaybackState(true, localEmit: false);
  }

  Future<void> _pickLocalSong() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav'],
        withData: true,
      );

      if (result != null && result.files.single.name.isNotEmpty && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final fileName = result.files.single.name;
        final songName = fileName.replaceAll(RegExp(r'\.(mp3|m4a|wav)$'), '');

        try {
          final uploadDio = Dio(BaseOptions(baseUrl: "https://music-party-socket.onrender.com/api"));
          await uploadDio.post(
            '/upload',
            data: bytes,
            options: Options(
              contentType: 'audio/mpeg',
            ),
          );
        } catch (e) {
          debugPrint("Error uploading local song: $e");
        }

        final localSong = {
          "title": songName,
          "artist": "Local Audio File",
          "url": null,
          "bytes": bytes,
        };

        setState(() {
          playlist.add(localSong);
          currentSongIndex = playlist.length - 1;
          isPlaying = false;
          _initialSeekDone = false;
          artGradients.add([const Color(0xFF8A2387), const Color(0xFFE94057)]);
        });

        _setInitialSource();
        _rotationController.stop();
        _pulseController.stop();
        _equalizerController.stop();
        _djLightsController.stop();
        SocketService.instance.sendPlaybackState(room.roomId, false);
        SocketService.instance.sendLocalSongInfo(room.roomId, songName);
      }
    } catch (e) {
      debugPrint("Error picking file: $e");
    }
  }

  String get _currentHost {
    final host = Uri.base.host;
    return host.isNotEmpty ? host : "127.0.0.1";
  }

  String _cleanSongTitle(String rawTitle) {
    String name = rawTitle.replaceAll(RegExp(r'\.(mp3|wav|m4a|mp4|aac|flac)$', caseSensitive: false), '');
    name = name
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    name = name.replaceAll(RegExp(r'\s*[\(\[][0-9]+\s*kbps[\]\)]', caseSensitive: false), '');
    
    final mid = name.length ~/ 2;
    if (mid > 5) {
      for (int i = mid - 5; i <= mid + 5; i++) {
        if (i > 0 && i < name.length) {
          final part1 = name.substring(0, i).trim();
          String part2 = name.substring(i).trim();
          if (part2.startsWith('-')) {
            part2 = part2.substring(1).trim();
          }
          final s1 = part1.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
          final s2 = part2.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
          if (s1 == s2 && s1.isNotEmpty) {
            name = part1;
            break;
          }
        }
      }
    }
    return name.trim();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    final isHost = SocketService.instance.userName == room.hostName;
    if (isHost) {
      RoomService.deleteRoom(room.roomId);
    }
    SocketService.instance.leaveRoom(room.roomId);
    SocketService.instance.disconnect();

    _audioPlayer.dispose();
    _rotationController.dispose();
    _pulseController.dispose();
    _equalizerController.dispose();
    _djLightsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isHost = SocketService.instance.userName == room.hostName;
    final desktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      body: PageBackground(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF070B19),
                Color(0xFF0F172A),
                Color(0xFF080C1E),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: isHost
                      ? _buildHostLayout(context, desktop)
                      : _buildParticipantLayout(context, desktop),
                ),
                if (!isHost && !_tunedIn) _buildTuneInOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // HOST LAYOUT (Premium DJ Deck Interface)
  // ==========================================
  Widget _buildHostLayout(BuildContext context, bool desktop) {
    final songTitle = (currentSongIndex != -1 && playlist.isNotEmpty)
        ? playlist[currentSongIndex]["title"]!
        : "No Song Uploaded";
    final songArtist = (currentSongIndex != -1 && playlist.isNotEmpty)
        ? playlist[currentSongIndex]["artist"]!
        : "Upload an MP3 to start broadcasting";

    final rightSide = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderRow(isHost: true),
        const SizedBox(height: 25),
        _buildBroadcastStatusCard(),
        const SizedBox(height: 25),
        // Progress Slider
        Slider(
          value: progress,
          activeColor: AppColors.primary,
          inactiveColor: Colors.white10,
          onChanged: (currentSongIndex != -1 && playlist.isNotEmpty)
              ? (value) {
                  setState(() {
                    progress = value;
                  });
                  final targetMs = (value * _duration.inMilliseconds).toInt();
                  _audioPlayer.seek(Duration(milliseconds: targetMs));
                  SocketService.instance.sendSeek(
                    room.roomId, 
                    value,
                    positionMs: targetMs,
                    durationMs: _duration.inMilliseconds,
                  );
                }
              : null,
        ),
        // Timestamps
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(_position), style: const TextStyle(color: Colors.white60)),
              Text("${(progress * 100).toInt()}% SYNCED", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11)),
              Text(_formatDuration(_duration), style: const TextStyle(color: Colors.white60)),
            ],
          ),
        ),
        const SizedBox(height: 30),
        _buildPlayerControls(),
        const SizedBox(height: 35),
        // Volume Control
        Text("Studio Monitor Volume", style: AppTextStyles.title.copyWith(fontSize: 14, color: Colors.white70)),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.volume_mute, color: Colors.white30, size: 20),
            Expanded(
              child: Slider(
                value: volume,
                activeColor: AppColors.secondary,
                inactiveColor: Colors.white10,
                onChanged: (value) {
                  setState(() {
                    volume = value;
                  });
                  _audioPlayer.setVolume(value);
                },
              ),
            ),
            const Icon(Icons.volume_up, color: AppColors.secondary, size: 20),
          ],
        ),
        const SizedBox(height: 30),
        Text("Party Guests", style: AppTextStyles.title),
        const SizedBox(height: 12),
        _buildDeviceList(),
      ],
    );

    if (desktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildAlbumArt(),
                const SizedBox(height: 30),
                Text(
                  _cleanSongTitle(songTitle),
                  style: AppTextStyles.heading.copyWith(fontSize: 28),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  songArtist,
                  style: AppTextStyles.body.copyWith(color: AppColors.grey),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 30),
                _buildEqualizer(),
              ],
            ),
          ),
          const SizedBox(width: 50),
          Expanded(
            flex: 5,
            child: SingleChildScrollView(child: rightSide),
          ),
        ],
      );
    } else {
      return SingleChildScrollView(
        child: Column(
          children: [
            _buildHeaderRow(isHost: true),
            const SizedBox(height: 20),
            _buildAlbumArt(),
            const SizedBox(height: 25),
            Text(
              _cleanSongTitle(songTitle),
              style: AppTextStyles.title.copyWith(fontSize: 22),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              songArtist,
              style: AppTextStyles.body.copyWith(color: AppColors.grey),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            _buildEqualizer(),
            const SizedBox(height: 25),
            rightSide,
          ],
        ),
      );
    }
  }

  // ==========================================
  // PARTICIPANT LAYOUT (Premium Sync Lounge)
  // ==========================================
  Widget _buildParticipantLayout(BuildContext context, bool desktop) {
    final songTitle = (currentSongIndex != -1 && playlist.isNotEmpty)
        ? playlist[currentSongIndex]["title"]!
        : "No Music Playing";
    final songArtist = (currentSongIndex != -1 && playlist.isNotEmpty)
        ? playlist[currentSongIndex]["artist"]!
        : "Waiting for host to play music...";

    final rightSide = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderRow(isHost: false),
        const SizedBox(height: 25),
        _buildSyncStatusCard(),
        const SizedBox(height: 25),
        // Disabled Progress Slider (Read-only for guest)
        Slider(
          value: progress,
          activeColor: AppColors.success,
          inactiveColor: Colors.white10,
          onChanged: null, // Read-only!
        ),
        // Timestamps
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(_hostPosition), style: const TextStyle(color: Colors.white60)),
              const Text("IN SYNC WITH DJ", style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
              Text(_formatDuration(_hostDuration), style: const TextStyle(color: Colors.white60)),
            ],
          ),
        ),
        const SizedBox(height: 35),
        // Local Device Volume Control
        Text("My Device Volume", style: AppTextStyles.title.copyWith(fontSize: 14, color: Colors.white70)),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.volume_mute, color: Colors.white30, size: 20),
            Expanded(
              child: Slider(
                value: volume,
                activeColor: AppColors.success,
                inactiveColor: Colors.white10,
                onChanged: (value) {
                  setState(() {
                    volume = value;
                  });
                  _audioPlayer.setVolume(value);
                },
              ),
            ),
            const Icon(Icons.volume_up, color: AppColors.success, size: 20),
          ],
        ),
        const SizedBox(height: 35),
        Text("Party Room Members", style: AppTextStyles.title),
        const SizedBox(height: 12),
        _buildDeviceList(),
      ],
    );

    if (desktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildAlbumArt(),
                const SizedBox(height: 30),
                Text(
                  _cleanSongTitle(songTitle),
                  style: AppTextStyles.heading.copyWith(fontSize: 28),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  songArtist,
                  style: AppTextStyles.body.copyWith(color: AppColors.grey),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 30),
                _buildEqualizer(),
              ],
            ),
          ),
          const SizedBox(width: 50),
          Expanded(
            flex: 5,
            child: SingleChildScrollView(child: rightSide),
          ),
        ],
      );
    } else {
      return SingleChildScrollView(
        child: Column(
          children: [
            _buildHeaderRow(isHost: false),
            const SizedBox(height: 20),
            _buildAlbumArt(),
            const SizedBox(height: 25),
            Text(
              _cleanSongTitle(songTitle),
              style: AppTextStyles.title.copyWith(fontSize: 22),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              songArtist,
              style: AppTextStyles.body.copyWith(color: AppColors.grey),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            _buildEqualizer(),
            const SizedBox(height: 25),
            rightSide,
          ],
        ),
      );
    }
  }

  // ==========================================
  // SHARED HEADER ROW
  // ==========================================
  Widget _buildHeaderRow({required bool isHost}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        ),
        Text(
          isHost ? "DJ CONTROL DECK" : "SYNC LOUNGE",
          style: AppTextStyles.heading.copyWith(
            fontSize: 20,
            letterSpacing: 2,
            color: isHost ? AppColors.primary : AppColors.success,
            shadows: [
              Shadow(
                blurRadius: 10,
                color: (isHost ? AppColors.primary : AppColors.success).withOpacity(0.5),
              ),
            ],
          ),
        ),
        Row(
          children: [
            if (isHost)
              IconButton(
                onPressed: _pickLocalSong,
                tooltip: "Broadcast Local Audio File",
                icon: const Icon(Icons.file_upload_outlined, color: AppColors.primary, size: 28),
              ),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 26),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // HOST BROADCASTING CARD
  // ==========================================
  Widget _buildBroadcastStatusCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          _PulseDot(color: isPlaying ? Colors.red : Colors.orange),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPlaying ? "BROADCASTING LIVE" : "BROADCAST PAUSED",
                  style: TextStyle(
                    color: isPlaying ? Colors.redAccent : Colors.orangeAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Room Code: ${room.roomId}",
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PARTICIPANT SYNC CARD
  // ==========================================
  Widget _buildSyncStatusCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.success.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          const _PulseDot(color: AppColors.success),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "LOCKED & IN SYNC",
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Connected to DJ ${room.hostName}'s Room",
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumArt() {
    return Container(
      height: 280,
      width: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(35),
        color: const Color(0xFF0F172A),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 25,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(33),
        child: AnimatedBuilder(
          animation: _djLightsController,
          builder: (context, child) {
            final val = _djLightsController.value;
            return Row(
              children: [
                Expanded(
                  child: _buildHalfLight(0, val),
                ),
                Container(
                  width: 2,
                  color: Colors.white.withOpacity(0.06),
                ),
                Expanded(
                  child: _buildHalfLight(1, val),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHalfLight(int index, double animationValue) {
    final intensity = index == 0 ? animationValue : (1.0 - animationValue);
    final isGlow = isPlaying;
    
    final baseColor = index == 0 ? const Color(0xFF00D4FF) : const Color(0xFFFF007F);
    
    final bgGlow = isGlow
        ? RadialGradient(
            center: Alignment.center,
            radius: 0.9,
            colors: [
              baseColor.withOpacity(0.38 * intensity),
              baseColor.withOpacity(0.06 * intensity),
              Colors.transparent,
            ],
          )
        : null;

    return Container(
      decoration: BoxDecoration(
        gradient: bgGlow,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 85,
              height: 85,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: baseColor.withOpacity(isGlow ? 0.28 + intensity * 0.72 : 0.12),
                border: Border.all(
                  color: baseColor.withOpacity(isGlow ? 0.95 : 0.25),
                  width: 3.5,
                ),
                boxShadow: isGlow
                    ? [
                        BoxShadow(
                          color: baseColor.withOpacity(0.65 * intensity),
                          blurRadius: 25 + intensity * 25,
                          spreadRadius: 3 + intensity * 7,
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.5 * intensity),
                          blurRadius: 10,
                          spreadRadius: 1.5,
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: Icon(
                  Icons.lightbulb_rounded,
                  color: isGlow 
                      ? Colors.white.withOpacity(0.6 + intensity * 0.4) 
                      : Colors.white24,
                  size: 38,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              index == 0 ? "LEFT STROBE" : "RIGHT STROBE",
              style: TextStyle(
                color: baseColor.withOpacity(isGlow ? 0.35 + intensity * 0.65 : 0.25),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEqualizer() {
    return EqualizerVisualizer(isPlaying: isPlaying);
  }

  Widget _buildPlayerControls() {
    final hasSong = currentSongIndex != -1 && playlist.isNotEmpty;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          onPressed: hasSong
              ? () {
                  if (_duration.inMilliseconds > 0) {
                    final targetMs = max(0, _position.inMilliseconds - 10000);
                    final targetDuration = Duration(milliseconds: targetMs);
                    _audioPlayer.seek(targetDuration);
                    final newProgress = targetMs / _duration.inMilliseconds;
                    setState(() {
                      _position = targetDuration;
                      progress = newProgress;
                    });
                    SocketService.instance.sendSeek(room.roomId, newProgress);
                  }
                }
              : null,
          icon: const Icon(
            Icons.replay_10_rounded,
            size: 42,
            color: Colors.white,
          ),
          disabledColor: Colors.white24,
        ),
        ScaleTransition(
          scale: _pulseController,
          child: Container(
            decoration: BoxDecoration(
              color: hasSong ? AppColors.primary : Colors.white24,
              shape: BoxShape.circle,
              boxShadow: hasSong
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 15,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
            child: IconButton(
              onPressed: hasSong
                  ? () {
                      _updatePlaybackState(!isPlaying, localEmit: true);
                    }
                  : null,
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: hasSong ? Colors.black : Colors.white38,
                size: 45,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: hasSong
              ? () {
                  if (_duration.inMilliseconds > 0) {
                    final targetMs = min(_duration.inMilliseconds, _position.inMilliseconds + 10000);
                    final targetDuration = Duration(milliseconds: targetMs);
                    _audioPlayer.seek(targetDuration);
                    final newProgress = targetMs / _duration.inMilliseconds;
                    setState(() {
                      _position = targetDuration;
                      progress = newProgress;
                    });
                    SocketService.instance.sendSeek(room.roomId, newProgress);
                  }
                }
              : null,
          icon: const Icon(
            Icons.forward_10_rounded,
            size: 42,
            color: Colors.white,
          ),
          disabledColor: Colors.white24,
        ),
      ],
    );
  }

  Widget _buildDeviceList() {
    return Column(
      children: room.members.map((member) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: member.host ? AppColors.primary : AppColors.success,
                child: Icon(
                  member.host ? Icons.laptop : Icons.phone_android,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      member.host ? "Host / DJ" : "Guest / Listener",
                      style: TextStyle(
                        color: member.host ? AppColors.primary : AppColors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Text(
                    member.host ? "Broadcasting" : "Synced",
                    style: TextStyle(
                      color: member.host ? AppColors.primary : AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.circle,
                    color: member.host ? AppColors.primary : AppColors.success,
                    size: 10,
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTuneInOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(35),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.music_note_rounded,
              color: AppColors.success,
              size: 80,
            ),
            const SizedBox(height: 20),
            Text(
              "Welcome to the Sync Party!",
              style: AppTextStyles.heading.copyWith(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              "Click the button below to tune in to the host's sound stream.",
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () async {
                setState(() {
                  _tunedIn = true;
                });
                if (currentSongIndex != -1 && playlist.isNotEmpty) {
                  if (isPlaying) {
                    await _playSong();
                    if (progress > 0) {
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (!mounted) return;
                        final targetMs = (progress * _duration.inMilliseconds).toInt();
                        if (targetMs > 0) {
                          _audioPlayer.seek(Duration(milliseconds: targetMs));
                        }
                      });
                    }
                  } else {
                    await _setInitialSource();
                    if (progress > 0) {
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (!mounted) return;
                        final targetMs = (progress * _duration.inMilliseconds).toInt();
                        if (targetMs > 0) {
                          _audioPlayer.seek(Duration(milliseconds: targetMs));
                        }
                      });
                    }
                  }
                }
              },
              child: const Text(
                "Tune In",
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EqualizerVisualizer extends StatefulWidget {
  final bool isPlaying;

  const EqualizerVisualizer({super.key, required this.isPlaying});

  @override
  State<EqualizerVisualizer> createState() => _EqualizerVisualizerState();
}

class _EqualizerVisualizerState extends State<EqualizerVisualizer> {
  late List<double> _heights;
  Timer? _timer;
  final int _barCount = 18;

  @override
  void initState() {
    super.initState();
    _heights = List.generate(_barCount, (_) => 6.0);
    _startAnimation();
  }

  void _startAnimation() {
    _timer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!mounted) return;
      setState(() {
        if (widget.isPlaying) {
          final rand = Random();
          for (int i = 0; i < _barCount; i++) {
            double bias;
            if (i < 5) {
              bias = 14 + rand.nextDouble() * 32;
            } else if (i < 12) {
              bias = 10 + rand.nextDouble() * 24;
            } else {
              bias = 4 + rand.nextDouble() * 16;
            }
            _heights[i] = bias;
          }
        } else {
          _heights = List.generate(_barCount, (_) => 6.0);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_barCount, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.5),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 5,
            height: _heights[index],
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.6),
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: widget.isPlaying
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.25),
                        blurRadius: 5,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;

  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.6 * _controller.value),
                blurRadius: 8 + 6 * _controller.value,
                spreadRadius: 2 * _controller.value,
              ),
            ],
          ),
        );
      },
    );
  }
}