// lib/main.dart
import 'package:flutter/foundation.dart'; // per kIsWeb
import 'html_stub.dart' if (dart.library.html) 'html_web.dart';
import 'dart:io' show File, Directory, Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'track_locations.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const PragueAudioGuideApp());

  if (kIsWeb &&
      HtmlHelper.window?.navigator.serviceWorker?.controller != null) {
    HtmlHelper.window!.navigator.serviceWorker!.controller!
        .postMessage('downloadOffline');
  }
}

class PragueAudioGuideApp extends StatelessWidget {
  const PragueAudioGuideApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prague Castle Audio Guide',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AudioMapPage(),
    );
  }
}

class AudioMapPage extends StatefulWidget {
  const AudioMapPage({Key? key}) : super(key: key);

  @override
  State<AudioMapPage> createState() => _AudioMapPageState();
}

class _AudioMapPageState extends State<AudioMapPage> {
  final AudioPlayer player = AudioPlayer();
  int currentTrack = 0;
  late final MapController mapController;

  Duration trackDuration = Duration.zero;
  Duration trackPosition = Duration.zero;
  bool isPlaying = false;
  bool hasStarted = false;

  ConcatenatingAudioSource? playlist;

  @override
  void initState() {
    super.initState();
    mapController = MapController();

    // 🔄 ascolta aggiornamenti
    player.durationStream.listen((d) {
      if (d != null) {
        setState(() => trackDuration = d);
      }
    });
    player.positionStream.listen((p) {
      setState(() => trackPosition = p);
    });
    player.playerStateStream.listen((state) {
      setState(() => isPlaying = state.playing);
    });
    player.currentIndexStream.listen((index) {
      if (index != null) {
        setState(() => currentTrack = index);
      }
    });
  }

  Future<void> preloadTracks() async {
    final sources = List.generate(
      trackLocations.length,
      (i) => AudioSource.asset(
        'assets/audio/${(i + 1).toString().padLeft(2, '0')}_${trackFileName(i)}.mp3',
      ),
    );
    playlist = ConcatenatingAudioSource(children: sources);
    await player.setAudioSource(playlist!);
  }

  void cacheAllAssets() {
    if (kIsWeb &&
        HtmlHelper.window?.navigator.serviceWorker?.controller != null) {
      HtmlHelper.window!.navigator.serviceWorker!.controller!
          .postMessage('downloadOffline');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download offline avviato')),
      );
    }
  }

  Future<void> playTrack(int index) async {
    if (playlist == null) return; // non ancora pronto
    await player.seek(Duration.zero, index: index);
    await player.play();

    mapController.move(trackLocations[index], 16.0);
  }

  String trackFileName(int index) {
    const names = [
      'welcome_to_prague_castle',
      'first_courtyard',
      'matthias_gate',
      'second_courtyard',
      'chapel_of_the_holy_cross',
      'spanish_hall',
      'third_courtyard',
      'st_vitus_cathedral',
      'south_portal',
      'st_wenceslas_chapel',
      'the_royal_crypt',
      'old_royal_palace_vladislav_hall',
      'ludwig_wing',
      'st_george_s_basilica',
      'st_george_s_convent',
      'golden_lane',
      'daliborka_tower',
      'white_tower',
      'powder_tower_mihulka',
      'black_tower',
      'old_castle_stairs',
      'south_gardens_garden_on_the_ramparts',
      'royal_garden',
      'exit_and_conclusion',
    ];
    return (index >= 0 && index < names.length) ? names[index] : '';
  }

  Future<void> downloadTrack(int index) async {
    final fileName =
        '${(index + 1).toString().padLeft(2, '0')}_${trackFileName(index)}.mp3';

    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permesso negato per salvare il file')),
        );
        return;
      }
    }

    final assetPath = 'assets/audio/$fileName';
    try {
      final byteData = await rootBundle.load(assetPath);

      Directory? baseDir;
      if (Platform.isAndroid) {
        baseDir = await getExternalStorageDirectory();
      } else {
        baseDir = await getApplicationDocumentsDirectory();
      }

      final targetDir = Directory('${baseDir!.path}/Audioguida_Praga');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final outFile = File('${targetDir.path}/$fileName');
      await outFile.writeAsBytes(byteData.buffer.asUint8List());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Traccia salvata in ${outFile.path}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore salvataggio: $e')),
      );
    }
  }

  Widget audioControlsAndList() {
    return Column(
      children: [
        Text(
          'Track ${currentTrack + 1}: ${trackFileName(currentTrack)}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Slider(
          min: 0,
          max: trackDuration.inMilliseconds.toDouble(),
          value: trackPosition.inMilliseconds
              .clamp(0, trackDuration.inMilliseconds)
              .toDouble(),
          onChanged: (value) {
            player.seek(Duration(milliseconds: value.toInt()));
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: () {
                if (isPlaying) {
                  player.pause();
                } else {
                  player.play();
                }
              },
            ),
            Text(
              "${trackPosition.toString().split('.').first} / ${trackDuration.toString().split('.').first}",
            ),
            const SizedBox(width: 20),
            ElevatedButton(
              onPressed: () => downloadTrack(currentTrack),
              child: const Text('Scarica traccia'),
            ),
          ],
        ),
        Expanded(
          child: ListView.builder(
            itemCount: trackLocations.length,
            itemBuilder: (context, index) {
              final isCurrent = index == currentTrack;
              return ListTile(
                title: Text(
                  'Stop ${index + 1}: ${trackFileName(index)}',
                  style: TextStyle(
                    fontWeight:
                        isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent ? Colors.green : Colors.black,
                  ),
                ),
                onTap: () => playTrack(index),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (!hasStarted) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Prague Castle Audio Guide'),
          actions: [
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Scarica tutto offline',
              onPressed: cacheAllAssets,
            ),
          ],
        ),
        body: Center(
          child: ElevatedButton(
            child: const Text('Start Audio'),
            onPressed: () async {
              await preloadTracks(); // 🔥 prepara tutte le tracce
              setState(() {
                hasStarted = true;
              });
            },
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prague Castle Audio Guide'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Scarica tutto offline',
            onPressed: cacheAllAssets,
          ),
        ],
      ),
      body: isMobile
          ? FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: trackLocations[currentTrack],
                initialZoom: 16.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                ),
                MarkerLayer(
                  markers: trackLocations.asMap().entries.map<Marker>((entry) {
                    final index = entry.key;
                    final location = entry.value;
                    final isCurrent = index == currentTrack;

                    return Marker(
                      point: location,
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        onTap: () => playTrack(index),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.location_on,
                              color: isCurrent ? Colors.green : Colors.red,
                              size: isCurrent ? 50 : 40,
                            ),
                            Positioned(
                              top: 8,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            )
          : Column(
              children: [
                Expanded(
                  flex: 2,
                  child: FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      initialCenter: trackLocations[currentTrack],
                      initialZoom: 16.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                      ),
                      MarkerLayer(
                        markers: trackLocations.asMap()
                            .entries
                            .map<Marker>((entry) {
                          final index = entry.key;
                          final location = entry.value;
                          final isCurrent = index == currentTrack;

                          return Marker(
                            point: location,
                            width: 50,
                            height: 50,
                            child: GestureDetector(
                              onTap: () => playTrack(index),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color: isCurrent
                                        ? Colors.green
                                        : Colors.red,
                                    size: isCurrent ? 50 : 40,
                                  ),
                                  Positioned(
                                    top: 8,
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                Expanded(flex: 1, child: audioControlsAndList()),
              ],
            ),
      floatingActionButton: isMobile
          ? FloatingActionButton(
              child: const Icon(Icons.music_note),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: audioControlsAndList(),
                  ),
                );
              },
            )
          : null,
    );
  }
}
