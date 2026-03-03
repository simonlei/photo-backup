import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:photo_backup_app/blocs/upload_bloc.dart';
import 'package:photo_backup_app/models/upload_task.dart';
import 'package:photo_backup_app/services/network_service.dart';
import 'package:photo_backup_app/services/rclone_service.dart';
import 'package:photo_backup_app/services/upload_queue_service.dart';

@GenerateMocks([RcloneService, UploadQueueService, NetworkService])
import 'upload_bloc_test.mocks.dart';

UploadTask makeTask(String id, {UploadStatus status = UploadStatus.pending}) {
  final now = DateTime(2024, 6, 1);
  return UploadTask(
    id: id,
    localPath: '/sdcard/$id.jpg',
    remotePath: 'remote:backup/$id.jpg',
    status: status,
    progress: 0.0,
    createdAt: now,
    updatedAt: now,
  );
}

UploadBloc makeBloc({
  required MockRcloneService rclone,
  required MockUploadQueueService queue,
  required MockNetworkService network,
}) {
  return UploadBloc(
    rcloneService: rclone,
    queueService: queue,
    networkService: network,
  );
}

void main() {
  late MockRcloneService mockRclone;
  late MockUploadQueueService mockQueue;
  late MockNetworkService mockNetwork;

  setUp(() {
    mockRclone = MockRcloneService();
    mockQueue = MockUploadQueueService();
    mockNetwork = MockNetworkService();
  });

  // Default stubs used across multiple tests
  void stubQueueDefaults() {
    when(mockQueue.addTask(any)).thenAnswer((_) async {});
    when(mockQueue.updateTask(any)).thenAnswer((_) async {});
    when(mockQueue.updateProgress(any, any)).thenAnswer((_) async {});
    when(mockQueue.getPendingTasks()).thenAnswer((_) async => []);
    when(mockQueue.getAllTasks()).thenAnswer((_) async => []);
    when(mockQueue.getTask(any)).thenAnswer((_) async => null);
    when(mockQueue.getStatistics()).thenAnswer((_) async => {});
    when(mockQueue.getTotalCount()).thenAnswer((_) async => 0);
    when(mockQueue.deleteCompletedTasks(olderThanDays: anyNamed('olderThanDays')))
        .thenAnswer((_) async {});
    when(mockQueue.close()).thenAnswer((_) async {});
  }

  void stubRcloneDefaults() {
    when(mockRclone.cancelUpload(any)).thenAnswer((_) async => true);
    when(mockRclone.dispose()).thenAnswer((_) async {});
  }

  group('UploadBloc initial state', () {
    test('starts with UploadInitial', () {
      stubQueueDefaults();
      stubRcloneDefaults();
      when(mockNetwork.checkBeforeUpload())
          .thenAnswer((_) async => NetworkCheckResult.ok);

      final bloc = makeBloc(
          rclone: mockRclone, queue: mockQueue, network: mockNetwork);
      expect(bloc.state, isA<UploadInitial>());
      bloc.close();
    });
  });

  group('StartUpload — network checks', () {
    blocTest<UploadBloc, UploadState>(
      'emits UploadFailure when no network connection',
      build: () {
        stubQueueDefaults();
        stubRcloneDefaults();
        when(mockNetwork.checkBeforeUpload())
            .thenAnswer((_) async => NetworkCheckResult.noConnection);
        return makeBloc(
            rclone: mockRclone, queue: mockQueue, network: mockNetwork);
      },
      act: (bloc) => bloc.add(const StartUpload(
        taskId: 'task-1',
        localPath: '/sdcard/photo.jpg',
        remotePath: 'remote:backup/photo.jpg',
      )),
      expect: () => [
        isA<UploadFailure>().having(
          (s) => s.errorMessage,
          'errorMessage',
          contains('无网络'),
        ),
      ],
    );

    blocTest<UploadBloc, UploadState>(
      'emits UploadWarning when on mobile data but continues upload',
      build: () {
        stubQueueDefaults();
        stubRcloneDefaults();
        when(mockNetwork.checkBeforeUpload())
            .thenAnswer((_) async => NetworkCheckResult.mobile);
        // Upload stream returns a single completed progress event
        when(mockRclone.uploadFile(
          uploadId: anyNamed('uploadId'),
          localPath: anyNamed('localPath'),
          remotePath: anyNamed('remotePath'),
        )).thenAnswer((_) => Stream.value(UploadProgress(
              uploadId: 'task-1',
              percent: 100.0,
              bytesTransferred: 1000,
              totalBytes: 1000,
              speedMBps: 2.0,
              etaSeconds: 0,
              status: UploadStatus.completed,
            )));
        when(mockQueue.getTask('task-1'))
            .thenAnswer((_) async => makeTask('task-1'));
        return makeBloc(
            rclone: mockRclone, queue: mockQueue, network: mockNetwork);
      },
      act: (bloc) => bloc.add(const StartUpload(
        taskId: 'task-1',
        localPath: '/sdcard/photo.jpg',
        remotePath: 'remote:backup/photo.jpg',
      )),
      expect: () => [
        isA<UploadWarning>().having(
          (s) => s.warningType,
          'warningType',
          WarningType.mobileData,
        ),
        // Upload continues after the warning
        isA<UploadInProgress>(),
        isA<UploadSuccess>(),
      ],
    );

    blocTest<UploadBloc, UploadState>(
      'starts upload when WiFi is available',
      build: () {
        stubQueueDefaults();
        stubRcloneDefaults();
        when(mockNetwork.checkBeforeUpload())
            .thenAnswer((_) async => NetworkCheckResult.ok);
        when(mockRclone.uploadFile(
          uploadId: anyNamed('uploadId'),
          localPath: anyNamed('localPath'),
          remotePath: anyNamed('remotePath'),
        )).thenAnswer((_) => Stream.value(UploadProgress(
              uploadId: 'task-1',
              percent: 100.0,
              bytesTransferred: 500,
              totalBytes: 500,
              speedMBps: 5.0,
              etaSeconds: 0,
              status: UploadStatus.completed,
            )));
        when(mockQueue.getTask('task-1'))
            .thenAnswer((_) async => makeTask('task-1'));
        return makeBloc(
            rclone: mockRclone, queue: mockQueue, network: mockNetwork);
      },
      act: (bloc) => bloc.add(const StartUpload(
        taskId: 'task-1',
        localPath: '/sdcard/photo.jpg',
        remotePath: 'remote:backup/photo.jpg',
      )),
      expect: () => [
        isA<UploadInProgress>(),
        isA<UploadSuccess>().having((s) => s.taskId, 'taskId', 'task-1'),
      ],
    );
  });

  group('CancelUpload', () {
    blocTest<UploadBloc, UploadState>(
      'emits UploadCancelled when task exists',
      build: () {
        stubQueueDefaults();
        stubRcloneDefaults();
        final task = makeTask('task-1');
        when(mockQueue.getTask('task-1')).thenAnswer((_) async => task);
        return makeBloc(
            rclone: mockRclone, queue: mockQueue, network: mockNetwork);
      },
      act: (bloc) => bloc.add(const CancelUpload('task-1')),
      expect: () => [
        isA<UploadCancelled>().having((s) => s.taskId, 'taskId', 'task-1'),
      ],
    );

    blocTest<UploadBloc, UploadState>(
      'emits nothing when task does not exist',
      build: () {
        stubQueueDefaults();
        stubRcloneDefaults();
        when(mockQueue.getTask(any)).thenAnswer((_) async => null);
        return makeBloc(
            rclone: mockRclone, queue: mockQueue, network: mockNetwork);
      },
      act: (bloc) => bloc.add(const CancelUpload('nonexistent')),
      expect: () => [],
    );
  });

  group('LoadUploadQueue', () {
    blocTest<UploadBloc, UploadState>(
      'emits UploadQueueLoaded with categorized tasks',
      build: () {
        stubQueueDefaults();
        stubRcloneDefaults();
        when(mockQueue.getAllTasks()).thenAnswer((_) async => [
              makeTask('p1', status: UploadStatus.pending),
              makeTask('u1', status: UploadStatus.uploading),
              makeTask('c1', status: UploadStatus.completed),
              makeTask('f1', status: UploadStatus.failed),
              makeTask('ca1', status: UploadStatus.cancelled),
            ]);
        return makeBloc(
            rclone: mockRclone, queue: mockQueue, network: mockNetwork);
      },
      act: (bloc) => bloc.add(const LoadUploadQueue()),
      expect: () => [
        isA<UploadQueueLoaded>()
            .having((s) => s.pending.length, 'pending', 1)
            .having((s) => s.uploading.length, 'uploading', 1)
            .having((s) => s.completed.length, 'completed', 1)
            .having((s) => s.failed.length, 'failed', 2), // failed + cancelled
      ],
    );

    blocTest<UploadBloc, UploadState>(
      'emits UploadQueueLoaded with empty lists when queue is empty',
      build: () {
        stubQueueDefaults();
        stubRcloneDefaults();
        return makeBloc(
            rclone: mockRclone, queue: mockQueue, network: mockNetwork);
      },
      act: (bloc) => bloc.add(const LoadUploadQueue()),
      expect: () => [
        isA<UploadQueueLoaded>()
            .having((s) => s.totalCount, 'totalCount', 0),
      ],
    );

    blocTest<UploadBloc, UploadState>(
      'emits UploadFailure when queue throws',
      build: () {
        stubQueueDefaults();
        stubRcloneDefaults();
        when(mockQueue.getAllTasks()).thenThrow(Exception('db error'));
        return makeBloc(
            rclone: mockRclone, queue: mockQueue, network: mockNetwork);
      },
      act: (bloc) => bloc.add(const LoadUploadQueue()),
      expect: () => [
        isA<UploadFailure>().having(
          (s) => s.errorMessage,
          'errorMessage',
          contains('加载队列失败'),
        ),
      ],
    );
  });

  group('RetryUpload', () {
    blocTest<UploadBloc, UploadState>(
      'retries a failed task and emits UploadInProgress + UploadSuccess',
      build: () {
        stubQueueDefaults();
        stubRcloneDefaults();
        when(mockNetwork.checkBeforeUpload())
            .thenAnswer((_) async => NetworkCheckResult.ok);
        final failedTask = makeTask('t1', status: UploadStatus.failed);
        when(mockQueue.getTask('t1')).thenAnswer((_) async => failedTask);
        when(mockRclone.uploadFile(
          uploadId: anyNamed('uploadId'),
          localPath: anyNamed('localPath'),
          remotePath: anyNamed('remotePath'),
        )).thenAnswer((_) => Stream.value(UploadProgress(
              uploadId: 't1',
              percent: 100.0,
              bytesTransferred: 200,
              totalBytes: 200,
              speedMBps: 1.0,
              etaSeconds: 0,
              status: UploadStatus.completed,
            )));
        return makeBloc(
            rclone: mockRclone, queue: mockQueue, network: mockNetwork);
      },
      act: (bloc) => bloc.add(const RetryUpload('t1')),
      expect: () => [
        isA<UploadInProgress>(),
        isA<UploadSuccess>().having((s) => s.taskId, 'taskId', 't1'),
      ],
    );

    blocTest<UploadBloc, UploadState>(
      'does nothing for a task that cannot retry',
      build: () {
        stubQueueDefaults();
        stubRcloneDefaults();
        final completedTask = makeTask('t1', status: UploadStatus.completed);
        when(mockQueue.getTask('t1')).thenAnswer((_) async => completedTask);
        return makeBloc(
            rclone: mockRclone, queue: mockQueue, network: mockNetwork);
      },
      act: (bloc) => bloc.add(const RetryUpload('t1')),
      expect: () => [], // no state change
    );
  });

  group('ClearCompleted', () {
    blocTest<UploadBloc, UploadState>(
      'calls deleteCompletedTasks and then reloads queue',
      build: () {
        stubQueueDefaults();
        stubRcloneDefaults();
        return makeBloc(
            rclone: mockRclone, queue: mockQueue, network: mockNetwork);
      },
      act: (bloc) => bloc.add(const ClearCompleted(olderThanDays: 3)),
      verify: (_) {
        verify(mockQueue.deleteCompletedTasks(olderThanDays: 3)).called(1);
        verify(mockQueue.getAllTasks()).called(1);
      },
      expect: () => [isA<UploadQueueLoaded>()],
    );
  });

  group('PauseUpload', () {
    blocTest<UploadBloc, UploadState>(
      'emits UploadPaused when task exists',
      build: () {
        stubQueueDefaults();
        stubRcloneDefaults();
        final task = makeTask('t1', status: UploadStatus.uploading);
        when(mockQueue.getTask('t1')).thenAnswer((_) async => task);
        return makeBloc(
            rclone: mockRclone, queue: mockQueue, network: mockNetwork);
      },
      act: (bloc) => bloc.add(const PauseUpload('t1')),
      expect: () => [
        isA<UploadPaused>().having((s) => s.taskId, 'taskId', 't1'),
      ],
    );
  });
}
