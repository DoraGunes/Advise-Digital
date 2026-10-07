import 'dart:convert';
import 'dart:typed_data';

import 'package:advise_digital/media_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('media detection uses filenames and MIME types', () {
    expect(MediaAccess.isImage(XFile('fixture.JPG')), isTrue);
    expect(MediaAccess.isImage(XFile('fixture.bin', mimeType: 'image/png')),
        isTrue);
    expect(MediaAccess.isImage(XFile('fixture.mp4')), isFalse);
  });

  test('cover sniff accepts bytes regardless of filename, path and MIME alias',
      () {
    expect(MediaAccess.coverMime(Uint8List.fromList([255, 216, 255, 0])),
        'image/jpeg');
    expect(
        MediaAccess.coverMime(
            Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10])),
        'image/png');
    expect(MediaAccess.coverMime(Uint8List.fromList('RIFF0000WEBP'.codeUnits)),
        'image/webp');
    expect(MediaAccess.coverMime(Uint8List.fromList([1, 2, 3])), isNull);
  });

  testWidgets('video preview never reads a platform file path', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: MediaPreview(
      file: XFile('/not-a-real-path/fixture.mp4'),
      height: 180,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Video hazır'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('in-memory image previews without dart:io', (tester) async {
    final Uint8List bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aOioAAAAASUVORK5CYII=');
    await tester.pumpWidget(MaterialApp(
        home: MediaPreview(
      file: XFile.fromData(bytes, name: 'fixture.png', mimeType: 'image/png'),
      height: 180,
    )));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
