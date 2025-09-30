// lib/main.dart
import 'package:flutter/foundation.dart'; // per kIsWeb
// Import condizionale: su Web usa html_web.dart, altrove usa html_stub.dart
import 'html_stub.dart'
    if (dart.library.html) 'html_web.dart';

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

  // Solo su Web: chiedi al service worker di scaricare tutto subito
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
  bool hasStarted = false; // aspetta interazione utente

  @override
  void initState() {
    super.initState();
    mapController = MapController();
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

  /// Play di una traccia
  Future<void> playTrack(int index) async {
    await player.stop();

    final filePath =
        'assets/audio/${(index + 1).toString().padLeft(2, '0')}_${trackFileName(index)}.mp3';

    await player.setAsset(filePath);

    setState(() {
      currentTrack = index;
    });

    await player.play();

    // Sposta la mappa sul marker corretto
    mapController.move(trackLocations[index], 16.0);
  }

  String trackFileName(int index) {
    switch (index) {
      case 0:
        return 'welcome_to_prague_castle';
      case 1:
        return 'first_courtyard';
      case 2:
        return 'matthias_gate';
      case 3:
        return 'second_courtyard';
      case 4:
        return 'chapel_of_the_holy_cross';
      case 5:
        return 'spanish_hall';
      case 6:
        return 'third_courtyard';
      case 7:
        return 'st_vitus_cathedral';
      case 8:
        return 'south_portal';
      case 9:
        return 'st_wenceslas_chapel';
      case 10:
        return 'the_royal_crypt';
      case 11:
        return 'old_royal_palace_vladislav_hall';
      case 12:
        return 'ludwig_wing';
      case 13:
        return 'st_george_s_basilica';
      case 14:
        return 'st_george_s_convent';
      case 15:
        return 'golden_lane';
      case 16:
        return 'daliborka_tower';
      case 17:
        return 'white_tower';
      case 18:
        return 'powder_tower_mihulka';
      case 19:
        return 'black_tower';
      case 20:
        return 'old_castle_stairs';
      case 21:
        return 'south_gardens_garden_on_the_ramparts';
      case 22:
        return 'royal_garden';
      case 23:
        return 'exit_and_conclusion';
      default:
        return '';
    }
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

        // 🔥 Player reattivo con StreamBuilder
        StreamBuilder<Duration?>(
          stream: player.durationStream,
          builder: (context, snapshot) {
            final duration = snapshot.data ?? Duration.zero;

            return StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;

                return Column(
                  children: [
                    Slider(
                      min: 0,
                      max: duration.inMilliseconds.toDouble(),
                      value: position.inMilliseconds
                          .clamp(0, duration.inMilliseconds)
                          .toDouble(),
                      onChanged: (value) {
                        player.seek(Duration(milliseconds: value.toInt()));
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(player.playing
                              ? Icons.pause
                              : Icons.play_arrow),
                          onPressed: () {
                            if (player.playing) {
                              player.pause();
                            } else {
                              player.play();
                            }
                          },
                        ),
                        Text(
                          "${position.toString().split('.').first} / ${duration.toString().split('.').first}",
                        ),
                        const SizedBox(width: 20),
                        ElevatedButton(
                          onPressed: () => downloadTrack(currentTrack),
                          child: const Text('Scarica traccia'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
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
            onPressed: () {
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
                  markers:
                      trackLocations.asMap().entries.map<Marker>((entry) {
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
