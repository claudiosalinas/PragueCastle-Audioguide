import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'track_locations.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  runApp(const PragueAudioGuideApp());
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
  bool hasStarted = false; // To wait for user interaction

  @override
  void initState() {
    super.initState();
    mapController = MapController();

    player.durationStream.listen((d) {
      setState(() => trackDuration = d ?? Duration.zero);
    });
    player.positionStream.listen((p) {
      setState(() => trackPosition = p);
    });
    player.playerStateStream.listen((state) {
      setState(() => isPlaying = state.playing);
    });
  }

  Future<void> playTrack(int index) async {
    if (currentTrack == index && isPlaying) return;

    await player.stop();
    setState(() => currentTrack = index);

    await player.setAsset(
        'assets/audio/${(index + 1).toString().padLeft(2, '0')}_${trackFileName(index)}.mp3');

    await player.play();

    mapController.move(trackLocations[index], 16.0);
  }

  String trackFileName(int index) {
    switch (index) {
      case 0: return 'welcome_to_prague_castle';
      case 1: return 'first_courtyard';
      case 2: return 'matthias_gate';
      case 3: return 'second_courtyard';
      case 4: return 'chapel_of_the_holy_cross';
      case 5: return 'spanish_hall';
      case 6: return 'third_courtyard';
      case 7: return 'st_vitus_cathedral';
      case 8: return 'south_portal';
      case 9: return 'st_wenceslas_chapel';
      case 10: return 'the_royal_crypt';
      case 11: return 'old_royal_palace_vladislav_hall';
      case 12: return 'ludwig_wing';
      case 13: return 'st_george_s_basilica';
      case 14: return 'st_george_s_convent';
      case 15: return 'golden_lane';
      case 16: return 'daliborka_tower';
      case 17: return 'white_tower';
      case 18: return 'powder_tower_mihulka';
      case 19: return 'black_tower';
      case 20: return 'old_castle_stairs';
      case 21: return 'south_gardens_garden_on_the_ramparts';
      case 22: return 'royal_garden';
      case 23: return 'exit_and_conclusion';
      default: return '';
    }
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!hasStarted) {
      return Scaffold(
        appBar: AppBar(title: const Text('Prague Castle Audio Guide')),
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
      appBar: AppBar(title: const Text('Prague Castle Audio Guide')),
      body: Column(
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
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
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
            ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Text(
                  'Track ${currentTrack + 1}: ${trackFileName(currentTrack)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Slider(
                  min: 0,
                  max: trackDuration.inMilliseconds.toDouble(),
                  value: trackPosition.inMilliseconds.clamp(0, trackDuration.inMilliseconds).toDouble(),
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
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: isCurrent ? Colors.green : Colors.black,
                          ),
                        ),
                        onTap: () => playTrack(index),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
