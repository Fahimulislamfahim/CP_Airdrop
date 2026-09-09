import 'peer.dart';

enum TransferStatus {
  pending,
  connecting,
  transferring,
  completed,
  declined,
  failed,
  cancelled,
}

class Transfer {
  final String id;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final String checksum;
  final Peer peer;
  final bool isOutgoing;
  final TransferStatus status;
  final int bytesTransferred;
  final String? localFilePath;
  final String? errorMessage;
  final DateTime createdAt;

  const Transfer({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.checksum,
    required this.peer,
    required this.isOutgoing,
    required this.status,
    this.bytesTransferred = 0,
    this.localFilePath,
    this.errorMessage,
    required this.createdAt,
  });

  double get progress =>
      fileSize > 0 ? (bytesTransferred / fileSize).clamp(0.0, 1.0) : 0.0;

  double get progressPercentage => progress * 100;

  Transfer copyWith({
    String? id,
    String? fileName,
    int? fileSize,
    String? mimeType,
    String? checksum,
    Peer? peer,
    bool? isOutgoing,
    TransferStatus? status,
    int? bytesTransferred,
    String? localFilePath,
    String? errorMessage,
    DateTime? createdAt,
  }) {
    return Transfer(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      checksum: checksum ?? this.checksum,
      peer: peer ?? this.peer,
      isOutgoing: isOutgoing ?? this.isOutgoing,
      status: status ?? this.status,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      localFilePath: localFilePath ?? this.localFilePath,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
