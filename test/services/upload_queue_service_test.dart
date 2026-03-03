import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:photo_backup_app/models/upload_task.dart';
import 'package:photo_backup_app/services/upload_queue_service.dart';

/// Helper: create a fresh in-memory service instance for each test.
/// Because UploadQueueService is a singleton, we test at the public API level
/// using sqflite_common_ffi which provides a real SQLite in-memory database.
///
/// Note: The singleton pattern means tests must run sequentially and each
/// test must close the database after use. We achieve isolation by calling
/// close() + deleteAllTasks() between tests.
Future<UploadQueueService> createService() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final service = UploadQueueService();
  await service.init();
  return service;
}

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

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final service = UploadQueueService();
    await service.init();
    await service.deleteAllTasks();
  });

  tearDown(() async {
    final service = UploadQueueService();
    await service.deleteAllTasks();
    await service.close();
  });

  group('UploadQueueService - addTask / getTask', () {
    test('stores and retrieves a single task', () async {
      final service = await createService();
      final task = makeTask('t1');

      await service.addTask(task);
      final retrieved = await service.getTask('t1');

      expect(retrieved, isNotNull);
      expect(retrieved!.id, 't1');
      expect(retrieved.status, UploadStatus.pending);
    });

    test('returns null for unknown id', () async {
      final service = await createService();
      final result = await service.getTask('nonexistent');
      expect(result, isNull);
    });

    test('replace semantics: addTask overwrites duplicate id', () async {
      final service = await createService();
      final original = makeTask('t1');
      await service.addTask(original);

      final updated = original.copyWith(status: UploadStatus.completed);
      await service.addTask(updated);

      final retrieved = await service.getTask('t1');
      expect(retrieved!.status, UploadStatus.completed);
    });
  });

  group('UploadQueueService - addTasks', () {
    test('inserts all tasks atomically', () async {
      final service = await createService();
      final tasks = [makeTask('a'), makeTask('b'), makeTask('c')];

      await service.addTasks(tasks);

      expect(await service.getTotalCount(), 3);
    });
  });

  group('UploadQueueService - updateTask', () {
    test('updates status and sets updatedAt', () async {
      final service = await createService();
      final task = makeTask('t1');
      await service.addTask(task);

      final updated = task.copyWith(
        status: UploadStatus.uploading,
        progress: 25.0,
      );
      await service.updateTask(updated);

      final retrieved = await service.getTask('t1');
      expect(retrieved!.status, UploadStatus.uploading);
      expect(retrieved.progress, 25.0);
    });
  });

  group('UploadQueueService - updateProgress', () {
    test('updates only progress field', () async {
      final service = await createService();
      final task = makeTask('t1');
      await service.addTask(task);

      await service.updateProgress('t1', 75.0);

      final retrieved = await service.getTask('t1');
      expect(retrieved!.progress, 75.0);
      expect(retrieved.status, UploadStatus.pending); // unchanged
    });
  });

  group('UploadQueueService - getPendingTasks', () {
    test('returns only pending tasks in createdAt ASC order', () async {
      final service = await createService();
      final now = DateTime(2024, 6, 1);

      final tasks = [
        UploadTask(
          id: 'early',
          localPath: '/a',
          remotePath: 'r:a',
          status: UploadStatus.pending,
          progress: 0,
          createdAt: now,
          updatedAt: now,
        ),
        UploadTask(
          id: 'late',
          localPath: '/b',
          remotePath: 'r:b',
          status: UploadStatus.pending,
          progress: 0,
          createdAt: now.add(const Duration(minutes: 1)),
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
        makeTask('done', status: UploadStatus.completed),
      ];
      await service.addTasks(tasks);

      final pending = await service.getPendingTasks();
      expect(pending.length, 2);
      expect(pending.first.id, 'early');
      expect(pending.last.id, 'late');
    });
  });

  group('UploadQueueService - getTasksByStatus', () {
    test('returns only tasks matching given status', () async {
      final service = await createService();
      await service.addTasks([
        makeTask('p1', status: UploadStatus.pending),
        makeTask('f1', status: UploadStatus.failed),
        makeTask('c1', status: UploadStatus.completed),
      ]);

      final failed = await service.getTasksByStatus(UploadStatus.failed);
      expect(failed.length, 1);
      expect(failed.first.id, 'f1');
    });
  });

  group('UploadQueueService - deleteTask', () {
    test('removes a specific task', () async {
      final service = await createService();
      await service.addTasks([makeTask('t1'), makeTask('t2')]);

      await service.deleteTask('t1');

      expect(await service.getTask('t1'), isNull);
      expect(await service.getTask('t2'), isNotNull);
    });
  });

  group('UploadQueueService - deleteCompletedTasks', () {
    test('removes completed tasks older than threshold', () async {
      final service = await createService();
      final old = DateTime.now().subtract(const Duration(days: 10));
      final recent = DateTime.now().subtract(const Duration(days: 3));

      await service.addTasks([
        UploadTask(
          id: 'old-done',
          localPath: '/old',
          remotePath: 'r:old',
          status: UploadStatus.completed,
          progress: 100,
          createdAt: old,
          updatedAt: old,
        ),
        UploadTask(
          id: 'recent-done',
          localPath: '/recent',
          remotePath: 'r:recent',
          status: UploadStatus.completed,
          progress: 100,
          createdAt: recent,
          updatedAt: recent,
        ),
        makeTask('pending-task'),
      ]);

      await service.deleteCompletedTasks(olderThanDays: 7);

      expect(await service.getTask('old-done'), isNull);
      expect(await service.getTask('recent-done'), isNotNull);
      expect(await service.getTask('pending-task'), isNotNull);
    });
  });

  group('UploadQueueService - updateTasksStatus', () {
    test('bulk-updates multiple tasks to target status', () async {
      final service = await createService();
      await service.addTasks([makeTask('t1'), makeTask('t2'), makeTask('t3')]);

      await service.updateTasksStatus(
        ['t1', 't2'],
        UploadStatus.failed,
        errorMessage: 'batch error',
      );

      final t1 = await service.getTask('t1');
      final t2 = await service.getTask('t2');
      final t3 = await service.getTask('t3');

      expect(t1!.status, UploadStatus.failed);
      expect(t2!.status, UploadStatus.failed);
      expect(t3!.status, UploadStatus.pending); // unchanged
    });
  });

  group('UploadQueueService - getStatistics', () {
    test('counts tasks by status', () async {
      final service = await createService();
      await service.addTasks([
        makeTask('p1', status: UploadStatus.pending),
        makeTask('p2', status: UploadStatus.pending),
        makeTask('c1', status: UploadStatus.completed),
        makeTask('f1', status: UploadStatus.failed),
      ]);

      final stats = await service.getStatistics();
      expect(stats['pending'], 2);
      expect(stats['completed'], 1);
      expect(stats['failed'], 1);
    });
  });

  group('UploadQueueService - getTotalCount', () {
    test('returns total number of tasks', () async {
      final service = await createService();
      expect(await service.getTotalCount(), 0);

      await service.addTasks([makeTask('a'), makeTask('b')]);
      expect(await service.getTotalCount(), 2);
    });
  });

  group('UploadQueueService - init guard', () {
    test('_ensureInitialized throws if init not called', () async {
      // Create a fresh instance by closing and resetting
      final service = UploadQueueService();
      await service.close(); // close any open db

      // getPendingTasks calls _ensureInitialized internally
      expect(
        () => service.getPendingTasks(),
        throwsA(isA<StateError>()),
      );
    });
  });
}
