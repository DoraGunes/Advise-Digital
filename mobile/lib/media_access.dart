import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

export 'package:image_picker/image_picker.dart' show XFile;

/// image_picker uses the native gallery on Android, file_selector on Windows,
/// and the browser file input on web. Keep XFile rather than platform paths.
class MediaAccess {
  MediaAccess._();

  static final ImagePicker _picker = ImagePicker();

  static Future<XFile?> pickOne({String mediaType = 'AUTO'}) async {
    try {
      if (mediaType.toUpperCase() == 'IMAGE') {
        return await _picker.pickImage(
            source: ImageSource.gallery, imageQuality: 92);
      }
      if (mediaType.toUpperCase() == 'VIDEO') {
        return await _picker.pickVideo(source: ImageSource.gallery);
      }
      return await _picker.pickMedia(
          imageQuality: 92, requestFullMetadata: false);
    } catch (error) {
      throw _selectionError(error);
    }
  }

  static Future<List<XFile>> pickMany({int limit = 8}) async {
    final count = limit.clamp(1, 8);
    if (count == 1) {
      final file = await pickOne();
      return file == null ? const <XFile>[] : <XFile>[file];
    }
    try {
      final files = await _picker.pickMultipleMedia(
        limit: count,
        requestFullMetadata: false,
      );
      return files.take(count).toList(growable: false);
    } catch (error) {
      throw _selectionError(error);
    }
  }

  static MediaSelectionException _selectionError(Object error) {
    final description = error.toString().toLowerCase();
    return MediaSelectionException(description.contains('permission') ||
            description.contains('access_denied')
        ? 'Fotoğraf ve video erişimine izin verin. Telefon ayarlarını kontrol edin.'
        : 'Dosya seçici açılamadı. Uygulamayı yeniden açıp tekrar deneyin.');
  }

  static bool isImage(XFile file) {
    final mime = file.mimeType?.toLowerCase() ?? '';
    if (mime.startsWith('image/')) return true;
    final name = file.name.toLowerCase();
    return const [
      '.jpg',
      '.jpeg',
      '.jfif',
      '.png',
      '.webp',
      '.gif',
      '.bmp',
      '.heic',
      '.heif',
      '.avif',
      '.tif',
      '.tiff',
    ].any(name.endsWith);
  }

  static String? coverMime(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) return 'image/jpeg';
    const png = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length >= 8 &&
        List.generate(8, (i) => bytes[i] == png[i]).every((value) => value))
      return 'image/png';
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP')
      return 'image/webp';
    return null;
  }
}

class MediaSelectionException implements Exception {
  final String message;
  const MediaSelectionException(this.message);
  @override
  String toString() => message;
}

class MediaPreview extends StatefulWidget {
  final XFile file;
  final double? height;
  final double? width;
  final BoxFit fit;
  const MediaPreview(
      {super.key,
      required this.file,
      this.height,
      this.width,
      this.fit = BoxFit.cover});

  @override
  State<MediaPreview> createState() => _MediaPreviewState();
}

class _MediaPreviewState extends State<MediaPreview> {
  late Future<Uint8List?> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = _load();
  }

  @override
  void didUpdateWidget(covariant MediaPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file != widget.file) _bytes = _load();
  }

  Future<Uint8List?> _load() async {
    if (!MediaAccess.isImage(widget.file)) return null;
    // Preview never reads an entire video or an oversized source image.
    if (await widget.file.length() > 24 * 1024 * 1024) return null;
    return widget.file.readAsBytes();
  }

  Widget _placeholder({bool error = false, bool loading = false}) => Container(
        height: widget.height ?? 160,
        width: widget.width,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                    error
                        ? Icons.image_not_supported_outlined
                        : MediaAccess.isImage(widget.file)
                            ? Icons.image_outlined
                            : Icons.videocam_outlined,
                    size: 32),
                const SizedBox(height: 8),
                Text(
                    error
                        ? 'Önizleme açılamadı'
                        : MediaAccess.isImage(widget.file)
                            ? 'Görsel hazır'
                            : 'Video hazır',
                    textAlign: TextAlign.center),
              ]),
      );

  @override
  Widget build(BuildContext context) => Semantics(
        label: MediaAccess.isImage(widget.file)
            ? 'Seçilen görsel'
            : 'Seçilen video',
        child: FutureBuilder<Uint8List?>(
            future: _bytes,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return _placeholder(loading: true);
              }
              final bytes = snapshot.data;
              if (bytes == null) return _placeholder(error: snapshot.hasError);
              return Image.memory(bytes,
                  height: widget.height,
                  width: widget.width,
                  fit: widget.fit,
                  gaplessPlayback: true,
                  cacheWidth: 1400,
                  errorBuilder: (context, error, stackTrace) =>
                      _placeholder(error: true));
            }),
      );
}
