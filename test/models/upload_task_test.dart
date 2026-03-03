import 'package:flutter_test/flutter_test.dart';
import 'package:photo_backup_app/models/upload_task.dart';

void main() {
  final baseTime = DateTime(2024, 1, 1, 12, 0, 0);

  UploadTask makeTask({
    String id = 'task-1',
    String localPath = '/sdcard/DCIM/photo.jpg',
    String remotePath = 'remote:backup/2024/photo.jpg',
    UploadStatus status = UploadStatus.pending,
    double progress = 0.0,
    String? errorMessage,
  }) {
    return UploadTask(
      id: id,
      localPath: localPath,
      remotePath: remotePath,
      status: status,
      progress: progress,
      errorMessage: errorMessage,
      createdAt: baseTime,
      updatedAt: baseTime,
    );
  }

  group('UploadTask.fromMap / toMap', () {
    test('round-trips all fields', () {
      final task = makeTask(
        status: UploadStatus.uploading,
        progress: 42.5,
        errorMessage: null,
      );

      final map = task.toMap();
      final restored = UploadTask.fromMap(map);

      expect(restored.id, task.id);
      expect(restored.localPath, task.localPath);
      expect(restored.remotePath, task.remotePath);
      expect(restored.status, task.status);
      expect(restored.progress, task.progress);
      expect(restored.errorMessage, task.errorMessage);
      expect(restored.createdAt, task.createdAt);
      expect(restored.updatedAt, task.updatedAt);
    });

    test('round-trips with optional errorMessage', () {
      final task = makeTask(
        status: UploadStatus.failed,
        errorMessage: 'Network timeout',
      );

      final restored = UploadTask.fromMap(task.toMap());
      expect(restored.errorMessage, 'Network timeout');
    });

    test('toMap encodes status as integer index', () {
      final map = makeTask(status: UploadStatus.completed).toMap();
      expect(map['status'], UploadStatus.completed.index);
    });

    test('fromMap decodes all UploadStatus values', () {
      for (final status in UploadStatus.values) {
        final map = makeTask(status: status).toMap();
        final restored = UploadTask.fromMap(map);
        expect(restored.status, status);
      }
    });
  });

  group('UploadTask.create', () {
    test('creates task with pending status and zero progress', () {
      final task = UploadTask.create(
        id: 'new-id',
        localPath: '/sdcard/pic.png',
        remotePath: 'remote:backup/pic.png',
      );

      expect(task.id, 'new-id');
      expect(task.status, UploadStatus.pending);
      expect(task.progress, 0.0);
      expect(task.errorMessage, isNull);
      expect(task.createdAt, isNotNull);
      expect(task.updatedAt, isNotNull);
    });
  });

  group('UploadTask.copyWith', () {
    test('updates only specified fields', () {
      final original = makeTask();
      final updated = original.copyWith(
        status: UploadStatus.completed,
        progress: 100.0,
      );

      expect(updated.id, original.id);
      expect(updated.localPath, original.localPath);
      expect(updated.status, UploadStatus.completed);
      expect(updated.progress, 100.0);
    });

    test('preserves original when no arguments provided', () {
      final original = makeTask(status: UploadStatus.uploading, progress: 55.0);
      final copy = original.copyWith();

      expect(copy, original);
    });
  });

  group('UploadTask computed properties', () {
    test('isCompleted', () {
      expect(makeTask(status: UploadStatus.completed).isCompleted, isTrue);
      expect(makeTask(status: UploadStatus.pending).isCompleted, isFalse);
    });

    test('isFailed', () {
      expect(makeTask(status: UploadStatus.failed).isFailed, isTrue);
      expect(makeTask(status: UploadStatus.completed).isFailed, isFalse);
    });

    test('isCancelled', () {
      expect(makeTask(status: UploadStatus.cancelled).isCancelled, isTrue);
      expect(makeTask(status: UploadStatus.pending).isCancelled, isFalse);
    });

    test('isInProgress', () {
      expect(makeTask(status: UploadStatus.uploading).isInProgress, isTrue);
      expect(makeTask(status: UploadStatus.pending).isInProgress, isFalse);
    });

    test('canRetry is true for failed and cancelled', () {
      expect(makeTask(status: UploadStatus.failed).canRetry, isTrue);
      expect(makeTask(status: UploadStatus.cancelled).canRetry, isTrue);
      expect(makeTask(status: UploadStatus.pending).canRetry, isFalse);
      expect(makeTask(status: UploadStatus.uploading).canRetry, isFalse);
      expect(makeTask(status: UploadStatus.completed).canRetry, isFalse);
    });

    test('fileName extracts last path component', () {
      final task = makeTask(localPath: '/sdcard/DCIM/Camera/IMG_001.jpg');
      expect(task.fileName, 'IMG_001.jpg');
    });

    test('remoteDir strips filename from remote path', () {
      final task = makeTask(
        remotePath: 'remote:backup/2024/01/photo.jpg',
      );
      expect(task.remoteDir, 'remote:backup/2024/01');
    });
  });

  group('UploadTask equality (Equatable)', () {
    test('two tasks with same fields are equal', () {
      final a = makeTask();
      final b = makeTask();
      expect(a, equals(b));
    });

    test('tasks with different ids are not equal', () {
      final a = makeTask(id: 'task-1');
      final b = makeTask(id: 'task-2');
      expect(a, isNot(equals(b)));
    });

    test('tasks with different status are not equal', () {
      final a = makeTask(status: UploadStatus.pending);
      final b = makeTask(status: UploadStatus.completed);
      expect(a, isNot(equals(b)));
    });
  });

  group('UploadTask toString', () {
    test('contains id, filename, status, and progress', () {
      final task = makeTask(
        id: 'test-id',
        localPath: '/sdcard/photo.jpg',
        status: UploadStatus.uploading,
        progress: 75.0,
      );
      final str = task.toString();
      expect(str, contains('test-id'));
      expect(str, contains('photo.jpg'));
      expect(str, contains('uploading'));
    });
  });
}
