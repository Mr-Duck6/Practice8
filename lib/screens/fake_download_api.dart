import 'dart:async';
import 'dart:math';

import '../models/download_file.dart';

class FakeDownloadApi {
  FakeDownloadApi({this.failureRate = 0.2, Random? random})
    : _random = random ?? Random();

  final double failureRate;
  final Random _random;

  Future<List<DownloadFile>> fetchFiles() async {
    await Future<void>.delayed(const Duration(milliseconds: 1000));

    return [
      DownloadFile(id: '1', name: 'Document_Report.pdf', size: '15 MB'),
      DownloadFile(id: '2', name: 'App_Installer.apk', size: '120 MB'),
      DownloadFile(id: '3', name: 'Presentation.pptx', size: '45 MB'),
      DownloadFile(id: '4', name: 'Dataset_2026.csv', size: '85 MB'),
      DownloadFile(id: '5', name: 'Archive_Backup.zip', size: '250 MB'),
    ];
  }

  Stream<double> downloadFileStream(
    String fileId, {
    StreamController<double>? controller,
  }) {
    late StreamController<double> activeController;
    activeController = controller ?? StreamController<double>();

    double currentProgress = 0.0;
    Timer? timer;
    int seconds = 0;

    void startSimulation() {
      timer = Timer.periodic(const Duration(milliseconds: 300), (t) {
        if (activeController.isClosed) {
          t.cancel();
          return;
        }

        seconds++;
        currentProgress += _random.nextDouble() * 0.15;

        if (currentProgress >= 1.0) {
          currentProgress = 1.0;
          activeController.add(currentProgress);
          activeController.close();
          t.cancel();
        } else {
          if (_random.nextDouble() < (failureRate * 0.05)) {
            activeController.addError(
              StateError('Помилка мережі під час завантаження'),
            );
            t.cancel();
            activeController.close();
          } else {
            activeController.add(currentProgress);
          }
        }
      });
    }

    activeController = StreamController<double>(
      onListen: startSimulation,
      onCancel: () {
        timer?.cancel();
      },
    );

    return activeController.stream;
  }
}
