import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<List<File>> getDownloadedVideos() async {
  final dir = await getApplicationDocumentsDirectory();
  final videoDir = Directory('${dir.path}/videos');
  // print(videoDir);

  if (!await videoDir.exists()) {
    return [];
  }

  final files = videoDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.mp4'))
      .toList();

  print(files);
  return files;
}
