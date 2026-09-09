import 'dart:convert';

/// Represents a discovered peer in the local network.
class Peer {
  final String id;
  final String ip;
  final int port;
  final String name;
  final String os; // "windows" | "android" | "ios" | "macos" | "linux"
  final String devType; // "desktop" | "mobile"
  final DateTime lastSeen;

  const Peer({
    required this.id,
    required this.ip,
    required this.port,
    required this.name,
    required this.os,
    required this.devType,
    required this.lastSeen,
  });

  Peer copyWith({
    String? id,
    String? ip,
    int? port,
    String? name,
    String? os,
    String? devType,
    DateTime? lastSeen,
  }) {
    return Peer(
      id: id ?? this.id,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      name: name ?? this.name,
      os: os ?? this.os,
      devType: devType ?? this.devType,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ip': ip,
      'port': port,
      'name': name,
      'os': os,
      'devType': devType,
      'lastSeen': lastSeen.toIso8601String(),
    };
  }

  factory Peer.fromMap(Map<String, dynamic> map) {
    return Peer(
      id: map['id'] as String? ?? '',
      ip: map['ip'] as String? ?? '',
      port: map['port'] as int? ?? 49200,
      name: map['name'] as String? ?? 'Unknown Device',
      os: (map['os'] as String? ?? 'unknown').toLowerCase(),
      devType: map['devType'] as String? ?? 'desktop',
      lastSeen: map['lastSeen'] != null
          ? DateTime.tryParse(map['lastSeen'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory Peer.fromJson(String source) =>
      Peer.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Peer && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Peer(id: $id, name: $name, ip: $ip, port: $port, os: $os, devType: $devType)';
  }
}
