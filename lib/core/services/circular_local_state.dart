import 'package:shared_preferences/shared_preferences.dart';

/// Per-device, per-user memory of circulars: which ones I opened (the "New" dot) and which ones I acknowledged on this device. The server has no
/// per-user read state, and the only route that tells who acknowledged (`GET /school-calendar/circulars/:id/acknowledgment-status`, SCS:293-309) answers
/// with the NAMES of every pending recipient, so the app never calls it. Acknowledging is an idempotent upsert on the server (SCS:286-290), so a
/// second acknowledgment from another device is harmless. Only circular ids are stored: no text.
class CircularLocalState {
  final bool _memory;
  final Map<String, List<String>> _mem = {};
  CircularLocalState() : _memory = false;
  CircularLocalState.memory() : _memory = true;

  static String _key(String kind, String userId) => 'eldermin_teacher_circular_${kind}_$userId';

  Future<Set<String>> load(String kind, String userId) async {
    if (_memory) return {...?_mem[_key(kind, userId)]};
    try {
      final p = await SharedPreferences.getInstance();
      return (p.getStringList(_key(kind, userId)) ?? const <String>[]).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> save(String kind, String userId, Set<String> ids) async {
    if (_memory) {
      _mem[_key(kind, userId)] = ids.toList();
      return;
    }
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_key(kind, userId), ids.toList());
    } catch (_) {/* a convenience, never a failure */}
  }
}
