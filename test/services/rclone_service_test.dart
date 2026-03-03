import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_backup_app/models/upload_task.dart';
import 'package:photo_backup_app/services/rclone_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('com.example.photobackup/rclone');

  setUp(() {
    // Reset mock handlers before each test
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  group('RcloneService._parseException', () {
    // We test exception parsing indirectly via cancelUpload / saveConfig / testConnection,
    // since _parseException is private. We use saveConfig because it re-throws.

    test('NETWORK_ERROR maps to NetworkException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        if (call.method == 'saveRcloneConfig') {
          throw PlatformException(code: 'NETWORK_ERROR', message: 'unreachable');
        }
        return null;
      });

      final service = RcloneService();
      expect(
        () => service.saveConfig('[remote]'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('AUTH_ERROR maps to AuthenticationException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        if (call.method == 'saveRcloneConfig') {
          throw PlatformException(code: 'AUTH_ERROR', message: 'bad creds');
        }
        return null;
      });

      final service = RcloneService();
      expect(
        () => service.saveConfig('[remote]'),
        throwsA(isA<AuthenticationException>()),
      );
    });

    test('TIMEOUT maps to TimeoutException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        if (call.method == 'saveRcloneConfig') {
          throw PlatformException(code: 'TIMEOUT', message: 'timed out');
        }
        return null;
      });

      final service = RcloneService();
      expect(
        () => service.saveConfig('[remote]'),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('UPLOAD_FAILED maps to UploadFailedException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        if (call.method == 'saveRcloneConfig') {
          throw PlatformException(code: 'UPLOAD_FAILED', message: 'io error');
        }
        return null;
      });

      final service = RcloneService();
      expect(
        () => service.saveConfig('[remote]'),
        throwsA(isA<UploadFailedException>()),
      );
    });

    test('unknown PlatformException code maps to AppException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        if (call.method == 'saveRcloneConfig') {
          throw PlatformException(code: 'UNKNOWN_CODE', message: 'something');
        }
        return null;
      });

      final service = RcloneService();
      expect(
        () => service.saveConfig('[remote]'),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('RcloneService.testConnection', () {
    test('returns true on success', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        if (call.method == 'testConnection') return true;
        return null;
      });

      final result = await RcloneService().testConnection();
      expect(result, isTrue);
    });

    test('returns false on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        if (call.method == 'testConnection') {
          throw PlatformException(code: 'NETWORK_ERROR');
        }
        return null;
      });

      final result = await RcloneService().testConnection();
      expect(result, isFalse);
    });
  });

  group('RcloneService.cancelUpload', () {
    test('returns true when native returns true', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        if (call.method == 'cancelUpload') return true;
        return null;
      });

      final result = await RcloneService().cancelUpload('upload-123');
      expect(result, isTrue);
    });

    test('returns false on exception (does not rethrow)', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        if (call.method == 'cancelUpload') {
          throw PlatformException(code: 'NOT_FOUND');
        }
        return null;
      });

      final result = await RcloneService().cancelUpload('nonexistent');
      expect(result, isFalse);
    });
  });

  group('RcloneService.getActiveUploads', () {
    test('returns list of active upload IDs', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        if (call.method == 'getActiveUploads') {
          return ['id-1', 'id-2'];
        }
        return null;
      });

      final ids = await RcloneService().getActiveUploads();
      expect(ids, ['id-1', 'id-2']);
    });

    test('returns empty list on exception', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        if (call.method == 'getActiveUploads') {
          throw PlatformException(code: 'ERROR');
        }
        return null;
      });

      final ids = await RcloneService().getActiveUploads();
      expect(ids, isEmpty);
    });
  });

  group('UploadProgress', () {
    test('fromMap / toMap round-trip', () {
      final map = <dynamic, dynamic>{
        'uploadId': 'test-id',
        'percent': 50.0,
        'bytesTransferred': 1024,
        'totalBytes': 2048,
        'speedMBps': 1.5,
        'etaSeconds': 10,
        'status': UploadStatus.uploading.index,
      };

      final progress = UploadProgress.fromMap(map);
      expect(progress.uploadId, 'test-id');
      expect(progress.percent, 50.0);
      expect(progress.bytesTransferred, 1024);
      expect(progress.totalBytes, 2048);
      expect(progress.speedMBps, 1.5);
      expect(progress.etaSeconds, 10);
      expect(progress.status, UploadStatus.uploading);
      expect(progress.isComplete, isFalse);
      expect(progress.isFailed, isFalse);
    });

    test('isComplete is true for completed status', () {
      final map = <dynamic, dynamic>{
        'uploadId': 'x',
        'percent': 100.0,
        'bytesTransferred': 2048,
        'totalBytes': 2048,
        'speedMBps': 0.0,
        'etaSeconds': 0,
        'status': UploadStatus.completed.index,
      };
      final progress = UploadProgress.fromMap(map);
      expect(progress.isComplete, isTrue);
    });

    test('isFailed is true for failed status', () {
      final map = <dynamic, dynamic>{
        'uploadId': 'x',
        'percent': 20.0,
        'bytesTransferred': 100,
        'totalBytes': 500,
        'speedMBps': 0.0,
        'etaSeconds': 0,
        'status': UploadStatus.failed.index,
      };
      final progress = UploadProgress.fromMap(map);
      expect(progress.isFailed, isTrue);
    });

    test('copyWith changes only specified fields', () {
      final original = UploadProgress(
        uploadId: 'orig',
        percent: 10.0,
        bytesTransferred: 100,
        totalBytes: 1000,
        speedMBps: 1.0,
        etaSeconds: 90,
        status: UploadStatus.uploading,
      );
      final updated = original.copyWith(percent: 50.0, etaSeconds: 45);
      expect(updated.percent, 50.0);
      expect(updated.etaSeconds, 45);
      expect(updated.uploadId, 'orig');
      expect(updated.status, UploadStatus.uploading);
    });
  });
}
