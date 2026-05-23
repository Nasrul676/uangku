import 'dart:io';
import 'package:archive/archive.dart';

void main() async {
  final archive = Archive();
  archive.addFile(ArchiveFile('test.txt', 12, 'Hello World!'.codeUnits));
  final zipBytes = ZipEncoder(password: '123').encode(archive);
  
  try {
    final decoded = ZipDecoder().decodeBytes(zipBytes!);
    print(decoded.files[0].content);
  } catch (e, stack) {
    print('Error caught: $e\n$stack');
  }
}
