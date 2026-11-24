import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../../../../core/audio/wav_decoder.dart';
import '../model/benchmark_models.dart';
import 'benchmark_csv.dart';

/// Reads benchmark clips from, and writes CSVs to, the app's `benchmark/` folder.
class BenchmarkFiles {
  BenchmarkFiles(this.directory);

  final Directory directory;

  /// Opens the folder on external app storage, reachable with `adb push`/`adb pull`.
  static Future<BenchmarkFiles> open() async {
    final base =
        await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/benchmark');
    await dir.create(recursive: true);
    return BenchmarkFiles(dir);
  }

  /// Returns the clips listed in `manifest.json`, or an empty list when it is missing.
  Future<List<BenchmarkClip>> readManifest() async {
    final file = File('${directory.path}/manifest.json');
    if (!await file.exists()) {
      return const [];
    }
    final entries = jsonDecode(await file.readAsString()) as List<dynamic>;
    return entries
        .map((e) => BenchmarkClip.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns the PCM16 bytes of a clip's WAV file.
  Future<Uint8List> readPcm(BenchmarkClip clip) async => WavDecoder.decodePcm16(
    await File('${directory.path}/${clip.file}').readAsBytes(),
  );

  /// Writes rows to `results-<timestamp>.csv` and returns the file.
  Future<File> writeCsv(List<BenchmarkRow> rows, DateTime at) async {
    final stamp = at
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-')
        .split('T')
        .join('_');
    final file = File('${directory.path}/results-$stamp.csv');
    return file.writeAsString(BenchmarkCsv.encode(rows));
  }
}
