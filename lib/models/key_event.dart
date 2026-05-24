import 'dart:io';

class GlobalKeyEvent {
  final int keyCode;
  final bool isKeyDown;
  final DateTime timestamp;
  final Map<String, bool> modifiers;

  const GlobalKeyEvent({
    required this.keyCode,
    required this.isKeyDown,
    required this.timestamp,
    required this.modifiers,
  });

  factory GlobalKeyEvent.fromMap(Map<dynamic, dynamic> map) {
    final rawMods = map['modifiers'];
    final mods = rawMods is Map
        ? rawMods.map((k, v) => MapEntry(k.toString(), v == true))
        : <String, bool>{};
    return GlobalKeyEvent(
      keyCode: (map['keyCode'] as num).toInt(),
      isKeyDown: map['isKeyDown'] == true,
      timestamp: DateTime.now(),
      modifiers: mods,
    );
  }

  String get displayName =>
      Platform.isMacOS ? _macKeyName(keyCode) : _winKeyName(keyCode);

  bool get isModifier {
    if (Platform.isMacOS) {
      return {54, 55, 56, 57, 58, 59, 60, 61, 62, 63}.contains(keyCode);
    }
    return {16, 17, 18, 20, 91, 92, 160, 161, 162, 163, 164, 165}.contains(keyCode);
  }
}

String _macKeyName(int code) {
  const names = <int, String>{
    0: 'A', 1: 'S', 2: 'D', 3: 'F', 4: 'H', 5: 'G', 6: 'Z', 7: 'X',
    8: 'C', 9: 'V', 11: 'B', 12: 'Q', 13: 'W', 14: 'E', 15: 'R',
    16: 'Y', 17: 'T', 18: '1', 19: '2', 20: '3', 21: '4', 22: '6',
    23: '5', 24: '=', 25: '9', 26: '7', 27: '-', 28: '8', 29: '0',
    30: ']', 31: 'O', 32: 'U', 33: '[', 34: 'I', 35: 'P', 36: '↵',
    37: 'L', 38: 'J', 39: "'", 40: 'K', 41: ';', 42: '\\', 43: ',',
    44: '/', 45: 'N', 46: 'M', 47: '.', 48: '⇥', 49: '⎵', 50: '`',
    51: '⌫', 53: '⎋', 54: '⌘R', 55: '⌘', 56: '⇧', 57: '⇪',
    58: '⌥', 59: '⌃', 60: '⇧R', 61: '⌥R', 62: '⌃R', 63: 'fn',
    71: '⌧', 76: '↵', 96: 'F5', 97: 'F6', 98: 'F7', 99: 'F3',
    100: 'F8', 101: 'F9', 103: 'F11', 105: 'F13', 107: 'F14',
    109: 'F10', 111: 'F12', 113: 'F15', 114: 'Help', 115: '↖',
    116: '⇞', 117: '⌦', 119: '↘', 121: '⇟', 122: 'F1', 123: '←',
    124: '→', 125: '↓', 126: '↑',
  };
  return names[code] ?? 'K$code';
}

String _winKeyName(int vk) {
  const names = <int, String>{
    8: '⌫', 9: '⇥', 13: '↵', 16: '⇧', 17: '⌃', 18: '⌥', 19: 'Pause',
    20: '⇪', 27: '⎋', 32: '⎵', 33: 'PgUp', 34: 'PgDn', 35: 'End',
    36: 'Home', 37: '←', 38: '↑', 39: '→', 40: '↓', 45: 'Ins',
    46: 'Del', 91: '⊞L', 92: '⊞R', 93: 'Menu',
    96: '0', 97: '1', 98: '2', 99: '3', 100: '4',
    101: '5', 102: '6', 103: '7', 104: '8', 105: '9',
    106: 'Num*', 107: 'Num+', 109: 'Num-', 110: 'Num.', 111: 'Num/',
    112: 'F1', 113: 'F2', 114: 'F3', 115: 'F4', 116: 'F5', 117: 'F6',
    118: 'F7', 119: 'F8', 120: 'F9', 121: 'F10', 122: 'F11', 123: 'F12',
    160: '⇧L', 161: '⇧R', 162: '⌃L', 163: '⌃R', 164: '⌥L', 165: '⌥R',
    186: ';', 187: '=', 188: ',', 189: '-', 190: '.', 191: '/',
    192: '`', 219: '[', 220: '\\', 221: ']', 222: "'",
  };
  if (vk >= 48 && vk <= 57) return String.fromCharCode(vk);
  if (vk >= 65 && vk <= 90) return String.fromCharCode(vk);
  return names[vk] ?? 'K$vk';
}
