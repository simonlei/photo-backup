import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_backup_app/blocs/upload_bloc.dart';
import 'package:photo_backup_app/models/upload_task.dart';
import 'package:photo_backup_app/services/network_service.dart';
import 'package:photo_backup_app/services/rclone_service.dart';
import 'package:photo_backup_app/services/upload_queue_service.dart';

// --- Mocks (mocktail, no code generation needed) ---

class MockRcloneService extends Mock implements RcloneService {}
class MockUploadQueueService extends Mock implements UploadQueueService {}
class MockNetworkService extends Mock implements NetworkService {}

// --- Helpers ---

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

UploadProgress makeProgress(
  String uploadId, {
  double percent = 100.0,
  UploadStatus status = UploadStatus.completed,
}) {
  return UploadProgress(
    uploadId: uploadId,
    percent: percent,
    bytesTransferred: 1000,
    totalBytes: 1000,
    speedMBps: 2.0,
    etaSeconds: 0,
    status: status,
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
    registerFallbackValue(makeTask('fallback'));
    registerFallbackValue(UploadStatus.pending);
  });

  // Shared stub helpers
  void stubQueueOk() {
    when(() => mockQueue.addTask(any())).thenAnswer((_) async {});
    when(() => mockQueue.addTasks(any())).thenAnswer((_) async {});
    when(() => mockQueue.updateTask(any())).thenAnswer((_) async {});
    when(() => mockQueue.updateProgress(any(), any())).thenAnswer((_) async {});
    when(() => mockQueue.getPendingTasks()).thenAnswer((_) async => []);
    when(() => mockQueue.getAllTasks()).thenAnswer((_) async => []);
    when(() => mockQueue.getTask(any())).thenAnswer((_) async => null);
    when(() => mockQueue.getStatistics()).thenAnswer((_) async => {});
    when(() => mockQueue.getTotalCount()).thenAnswer((_) async => 0);
    when(() => mockQueue.deleteCompletedTasks(olderThanDays: any(named: 'olderThanDays')))
        .thenAnswer((_) async {});
    when(() => mockQueue.close()).thenAnswer((_) async {});
  }

  void stubRcloneOk() {
    when(() => mockRclone.cancelUpload(any())).thenAnswer((_) async => true);
    when(() => mockRclone.dispose()).thenAnswer((_) async {});
  }

  // ── Initial state ──────────────────────────────────────────────────────────

  group('UploadBloc initial state', () {
    test('starts with UploadInitial', () {
      stubQueueOk();
      stubRcloneOk();
      final bloc = makeBloc(rclone: mockRclone, queue: mockQueue, network: mockNetwork);
      expect(bloc.state, isA<UploadInitial>());
      bloc.close();
    });
  });

  // ── StartUpload — network checks ───────────────────────────────────────────

  group('StartUpload — network checks', () {
    blocTest<UploadBloc, UploadState>(
      'emits UploadFailure when no network connection',
      build: () {
        stubQueueOk();
        stubRcloneOk();
        when(() => mockNetwork.checkBeforeUpload())
            .thenAnswer((_) async => NetworkCheckResult.noConnection);
        return makeBloc(rclone: mockRclone, queue: mockQueue, network: mockNetwork);
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
      'emits UploadWarning then continues upload on mobile data',
      build: () {
        stubQueueOk();
        stubRcloneOk();
        when(() => mockNetwork.checkBeforeUpload())
            .thenAnswer((_) async => NetworkCheckResult.mobile);
        when(() => mockRclone.uploadFile(
          uploadId: any(named: 'uploadId'),
          localPath: any(named: 'localPath'),
          remotePath: any(named: 'remotePath'),
        )).thenAnswer((_) => Stream.value(makeProgress('task-1')));
        when(() => mockQueue.getTask('task-1'))
            .thenAnswer((_) async => makeTask('task-1'));
        return makeBloc(rclone: mockRclone, queue: mockQueue, network: mockNetwork);
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
        isA<UploadInProgress>(),
        isA<UploadSuccess>(),
      ],
    );

    blocTest<UploadBloc, UploadState>(
      'starts upload and emits UploadInProgress + UploadSuccess on WiFi',
      build: () {
        stubQueueOk();
        stubRcloneOk();
        when(() => mockNetwork.checkBeforeUpload())
            .thenAnswer((_) async => NetworkCheckResult.ok);
        when(() => mockRclone.uploadFile(
          uploadId: any(named: 'uploadId'),
          localPath: any(named: 'localPath'),
          remotePath: any(named: 'remotePath'),
        )).thenAnswer((_) => Stream.value(makeProgress('task-1')));
        when(() => mockQueue.getTask('task-1'))
            .thenAnswer((_) async => makeTask('task-1'));
        return makeBloc(rclone: mockRclone, queue: mockQueue, network: mockNetwork);
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

  // ── CancelUpload ───────────────────────────────────────────────────────────

  group('CancelUpload', () {
    blocTest<UploadBloc, UploadState>(
      'emits UploadCancelled when task exists',
      build: () {
        stubQueueOk();
        stubRcloneOk();
        when(() => mockQueue.getTask('task-1'))
            .thenAnswer((_) async => makeTask('task-1'));
        return makeBloc(rclone: mockRclone, queue: mockQueue, network: mockNetwork);
      },
      act: (bloc) => bloc.add(const CancelUpload('task-1')),
      expect: () => [
        isA<UploadCancelled>().having((s) => s.taskId, 'taskId', 'task-1'),
      ],
    );

    blocTest<UploadBloc, UploadState>(
      'emits nothing when task does not exist',
      build: () {
        stubQueueOk();
        stubRcloneOk();
        return makeBloc(rclone: mockRclone, queue: mockQueue, network: mockNetwork);
      },
      act: (bloc) => bloc.add(const CancelUpload('nonexistent')),
      expect: () => [],
    );
  });

  // ── LoadUploadQueue ────────────────────────────────────────────────────────

  group('LoadUploadQueue', () {
    blocTest<UploadBloc, UploadState>(
      'emits UploadQueueLoaded with categorized tasks',
      build: () {
        stubQueueOk();
        stubRcloneOk();
        when(() => mockQueue.getAllTasks()).thenAnswer((_) async => [
              makeTask('p1', status: UploadStatus.pending),
              makeTask('u1', status: UploadStatus.uploading),
              makeTask('c1', status: UploadStatus.completed),
              makeTask('f1', status: UploadStatus.failed),
              makeTask('ca1', status: UploadStatus.cancelled),
            ]);
        return makeBloc(rclone: mockRclone, queue: mockQueue, network: mockNetwork);
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
      'emits UploadQueueLoaded with zero totalCount when queue is empty',
      build: () {
        stubQueueOk();
        stubRcloneOk();
        return makeBloc(rclone: mockRclone, queue: mockQueue, network: mockNetwork);
      },
      act: (bloc) => bloc.add(const LoadUploadQueue()),
      expect: () => [
        isA<UploadQueueLoaded>().having((s) => s.totalCount, 'totalCount', 0),
      ],
    );

    blocTest<UploadBloc, UploadState>(
      'emits UploadFailure when queue throws',
      build: () {
        stubQueueOk();
        stubRcloneOk();
        when(() => mockQueue.getAllTasks()).thenThrow(Exception('db error'));
        return makeBloc(rclone: mockRclone, queue: mockQueue, network: mockNetwork);
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

  // ── RetryUpload ────────────────────────────────────────────────────────────

  group('RetryUpload', () {
    blocTest<UploadBloc, UploadState>(
      'retries a failed task and emits UploadInProgress + UploadSuccess',
      build: () {
        stubQueueOk();
        stubRcloneOk();
        when(() => mockNetwork.checkBeforeUpload())
            .thenAnswer((_) async => NetworkCheckResult.ok);
        when(() => mockQueue.getTask('t1'))
            .thenAnswer((_) async => makeTask('t1', status: UploadStatus.failed));
        when(() => mockRclone.uploadFile(
          uploadId: any(named: 'uploadId'),
          localPath: any(named: 'localPath'),
          remotePath: any(named: 'remotePath'),
        )).thenAnswer((_) => Stream.value(makeProgress('t1')));
        return makeBloc(rclone: mockRclone, queue: mockQueue, network: mockNetwork);
      },
      act: (bloc) => bloc.add(const RetryUpload('t1')),
      expect: () => [
        isA<UploadInProgress>(),
        isA<UploadSuccess>().having((s) => s.taskId, 'taskId', 't1'),
      ],
    );

    blocTest<UploadBloc, UploadState>(
      'does nothing for a task that cannot retry (completed)',
      build: () {
        stubQueueOk();
        stubRcloneOk();
        when(() => mockQueue.getTask('t1'))
            .thenAnswer((_) async => makeTask('t1', status: UploadStatus.completed));
        return makeBloc(rclone: mockRclone, queue: mockQueue, network: mockNetwork);
      },
      act: (bloc) => bloc.add(const RetryUpload('t1')),
      expect: () => [],
    );
  });

  // ── ClearCompleted ─────────────────────────────────────────────────────────

  group('ClearCompleted', () {
    blocTest<UploadBloc, UploadState>(
      'calls deleteCompletedTasks and reloads queue',
      build: () {
        stubQueueOk();
        stubRcloneOk();
        return makeBloc(rclone: mockRclone, queue: mockQueue, network: mockNetwork);
      },
      act: (bloc) => bloc.add(const ClearCompleted(olderThanDays: 3)),
      verify: (_) {
        verify(() => mockQueue.deleteCompletedTasks(olderThanDays: 3)).called(1);
        verify(() => mockQueue.getAllTasks()).called(1);
      },
      expect: () => [isA<UploadQueueLoaded>()],
    );
  });

  // ── PauseUpload ────────────────────────────────────────────────────────────

  group('PauseUpload', () {
    blocTest<UploadBloc, UploadState>(
      'emits UploadPaused when task exists',
      build: () {
        stubQueueOk();
        stubRcloneOk();
        when(() => mockQueue.getTask('t1'))
            .thenAnswer((_) async => makeTask('t1', status: UploadStatus.uploading));
        return makeBloc(rclone: mockRclone, queue: mockQueue, network: mockNetwork);
      },
      act: (bloc) => bloc.add(const PauseUpload('t1')),
      expect: () => [
        isA<UploadPaused>().having((s) => s.taskId, 'taskId', 't1'),
      ],
    );
  });
}
