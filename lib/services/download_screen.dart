import 'dart:async';

import 'package:flutter/material.dart';

import '../models/download_file.dart';

class FakeDownloadApi {
  FakeDownloadApi({this.failureRate = 0.2});

  final double failureRate;

  Future<List<DownloadFile>> fetchFiles() async => <DownloadFile>[];

  Stream<double> downloadFileStream(
    String id, {
    required StreamController<double> controller,
  }) async* {
    for (var progress = 0.1; progress <= 1.0; progress += 0.1) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final value = progress.clamp(0.0, 1.0);
      controller.add(value);
      yield value;
    }
    await controller.close();
  }
}

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final FakeDownloadApi _api = FakeDownloadApi(failureRate: 0.2);
  late Future<List<DownloadFile>> _filesFuture;

  List<DownloadFile> _files = [];
  final Map<String, StreamSubscription<double>> _subscriptions = {};
  final Map<String, StreamController<double>> _controllers = {};
  final Map<String, Stopwatch> _stopwatches = {};

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  void _loadFiles() {
    _filesFuture = _api.fetchFiles().then((loadedFiles) {
      if (!mounted) return loadedFiles;
      setState(() {
        _files = loadedFiles;
      });
      return loadedFiles;
    });
  }

  void _startDownload(DownloadFile file) async {
    setState(() {
      final index = _files.indexWhere((f) => f.id == file.id);
      if (index != -1) {
        _files[index] = _files[index].copyWith(
          status: FileStatus.downloading,
          progress: 0.0,
          errorMessage: null,
        );
      }
    });

    final stopwatch = Stopwatch()..start();
    _stopwatches[file.id] = stopwatch;

    final controller = StreamController<double>();
    _controllers[file.id] = controller;

    final stream = _api
        .downloadFileStream(file.id, controller: controller)
        .timeout(
          const Duration(seconds: 4),
          onTimeout: (sink) {
            sink.addError(TimeoutException('Тайм-аут завантаження'));
          },
        );

    _subscriptions[file.id] = stream.listen(
      (progress) {
        if (!mounted) return;
        setState(() {
          final index = _files.indexWhere((f) => f.id == file.id);
          if (index != -1) {
            _files[index] = _files[index].copyWith(
              progress: progress,
              status: FileStatus.downloading,
            );
          }
        });
      },
      onError: (error) async {
        if (!mounted) return;

        // Закриваємо старий контролер
        await _controllers[file.id]?.close();

        setState(() {
          final index = _files.indexWhere((f) => f.id == file.id);
          if (index != -1) {
            _files[index] = _files[index].copyWith(
              status: FileStatus.error,
              errorMessage: error.toString(),
            );
          }
        });
      },
      onDone: () {
        stopwatch.stop();
        if (!mounted) return;
        setState(() {
          final index = _files.indexWhere((f) => f.id == file.id);
          if (index != -1 && _files[index].status == FileStatus.downloading) {
            _files[index] = _files[index].copyWith(
              status: FileStatus.success,
              progress: 1.0,
              elapsedSeconds: stopwatch.elapsed.inSeconds,
            );
          }
        });
      },
    );
  }

  void _cancelDownload(DownloadFile file) {
    _subscriptions[file.id]?.cancel();
    _controllers[file.id]?.close();
    _stopwatches[file.id]?.stop();

    setState(() {
      final index = _files.indexWhere((f) => f.id == file.id);
      if (index != -1) {
        _files[index] = _files[index].copyWith(
          status: FileStatus.cancelled,
          progress: 0.0,
        );
      }
    });
  }

  // «Завантажити всі» через Future.wait з обробкою помилок окремих файлів
  void _downloadAll() async {
    final pendingFiles = _files.where((f) => f.status != FileStatus.success);

    await Future.wait(
      pendingFiles.map((file) async {
        _startDownload(file);
      }),
    );
  }

  @override
  void dispose() {
    for (var sub in _subscriptions.values) {
      sub.cancel();
    }
    for (var controller in _controllers.values) {
      controller.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Менеджер завантажень'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _downloadAll,
            tooltip: 'Завантажити всі',
          ),
        ],
      ),
      body: FutureBuilder<List<DownloadFile>>(
        future: _filesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // 2. Стан помилки з кнопкою «Повторити»
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Помилка завантаження списку файлів'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _loadFiles();
                      });
                    },
                    child: const Text('Повторити'),
                  ),
                ],
              ),
            );
          }
          if (_files.isEmpty) {
            return const Center(child: Text('Список файлів порожній'));
          }

          // 4. Успішний стан — список файлів
          return ListView.builder(
            itemCount: _files.length,
            itemBuilder: (context, index) {
              final file = _files[index];
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            file.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            file.size,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: file.progress),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Статус: ${file.status.name} (${(file.progress * 100).toStringAsFixed(0)}%)',
                          ),
                          if (file.status == FileStatus.downloading)
                            TextButton(
                              onPressed: () => _cancelDownload(file),
                              child: const Text(
                                'Скасувати',
                                style: TextStyle(color: Colors.red),
                              ),
                            )
                          else
                            ElevatedButton(
                              onPressed: () => _startDownload(file),
                              child: const Text('Завантажити'),
                            ),
                        ],
                      ),
                      if (file.errorMessage != null)
                        Text(
                          'Помилка: ${file.errorMessage}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      if (file.elapsedSeconds != null)
                        Text(
                          'Час завантаження: ${file.elapsedSeconds} сек.',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
