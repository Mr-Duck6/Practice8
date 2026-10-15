enum FileStatus { initial, downloading, success, error, cancelled }

class DownloadFile {
  final String id;
  final String name;
  final String size;
  FileStatus status;
  double progress; // від 0.0 до 1.0
  String? errorMessage;
  int? elapsedSeconds;

  DownloadFile({
    required this.id,
    required this.name,
    required this.size,
    this.status = FileStatus.initial,
    this.progress = 0.0,
    this.errorMessage,
    this.elapsedSeconds,
  });

  DownloadFile copyWith({
    FileStatus? status,
    double? progress,
    String? errorMessage,
    int? elapsedSeconds,
  }) {
    return DownloadFile(
      id: id,
      name: name,
      size: size,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    );
  }
}
