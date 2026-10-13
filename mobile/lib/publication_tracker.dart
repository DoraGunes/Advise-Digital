import 'dart:async';

/// A submit is never repeated. Missing/stale reads keep the operation unresolved.
class PublicationTracker {
  static Future<Map<String, dynamic>> follow({
    required String id,
    required bool submit,
    required Future<Map<String, dynamic>> Function() send,
    required Future<Map<String, dynamic>?> Function() read,
    required Future<void> Function() confirmed,
    void Function(Map<String, dynamic>)? onUpdate,
    Future<void> Function()? pause,
    bool Function()? cancelled,
    int reads = 20,
  }) async {
    Map<String, dynamic>? latest;
    Future<Map<String, dynamic>?> accept(Map<String, dynamic>? row) async {
      if (row == null) return null;
      latest = row;
      onUpdate?.call(row);
      if (row['publishStatus']?.toString().toUpperCase() == 'PUBLISHED') {
        await confirmed();
        return row;
      }
      return null;
    }
    if (submit) {
      Map<String, dynamic>? response;
      try { response = await send(); } catch (_) {
        // A lost response is not a rejected publication.
      }
      final done = await accept(response);
      if (done != null) return done;
    }
    for (var attempt = 0; attempt < reads; attempt++) {
      if (cancelled?.call() == true) break;
      Map<String, dynamic>? row;
      try { row = await read(); } catch (_) {
        // Continue bounded GET checks; never resubmit.
      }
      final done = await accept(row);
      if (done != null) return done;
      if (attempt + 1 < reads) {
        await (pause?.call() ?? Future<void>.delayed(const Duration(seconds: 3)));
      }
    }
    final unresolved = <String,dynamic>{
      ...?latest, 'id': id, 'publishStatus': 'PUBLISH_UNKNOWN',
      'publicationPending': true,
    };
    onUpdate?.call(unresolved);
    return unresolved;
  }
}
