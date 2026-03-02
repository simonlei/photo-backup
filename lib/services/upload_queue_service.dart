import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:synchronized/synchronized.dart';
import '../models/upload_task.dart';

/// 上传队列服务
/// 使用 SQLite 持久化上传任务，支持并发安全
class UploadQueueService {
  // 单例模式
  static final UploadQueueService _instance = UploadQueueService._internal();
  factory UploadQueueService() => _instance;
  UploadQueueService._internal();
  
  Database? _database;
  
  // ✅ 互斥锁保护所有数据库操作
  final _lock = Lock();
  
  /// 初始化数据库
  Future<void> init() async {
    if (_database != null) return;
    
    await _lock.synchronized(() async {
      if (_database != null) return; // Double-check
      
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'upload_queue.db');
      
      _database = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE upload_tasks (
              id TEXT PRIMARY KEY,
              localPath TEXT NOT NULL,
              remotePath TEXT NOT NULL,
              status INTEGER NOT NULL,
              progress REAL NOT NULL DEFAULT 0,
              errorMessage TEXT,
              createdAt TEXT NOT NULL,
              updatedAt TEXT NOT NULL
            )
          ''');
          
          // 添加索引提高查询性能
          await db.execute(
            'CREATE INDEX idx_status ON upload_tasks(status)'
          );
          await db.execute(
            'CREATE INDEX idx_createdAt ON upload_tasks(createdAt)'
          );
        },
      );
    });
  }
  
  /// 添加任务（线程安全）
  Future<void> addTask(UploadTask task) async {
    await _lock.synchronized(() async {
      await _ensureInitialized();
      
      await _database!.insert(
        'upload_tasks',
        task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }
  
  /// 批量添加任务（原子操作）
  Future<void> addTasks(List<UploadTask> tasks) async {
    await _lock.synchronized(() async {
      await _ensureInitialized();
      
      // 使用事务确保原子性
      await _database!.transaction((txn) async {
        for (final task in tasks) {
          await txn.insert(
            'upload_tasks',
            task.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    });
  }
  
  /// 更新任务（线程安全）
  Future<void> updateTask(UploadTask task) async {
    await _lock.synchronized(() async {
      await _ensureInitialized();
      
      final updatedTask = task.copyWith(
        updatedAt: DateTime.now(),
      );
      
      await _database!.update(
        'upload_tasks',
        updatedTask.toMap(),
        where: 'id = ?',
        whereArgs: [task.id],
      );
    });
  }
  
  /// 更新任务进度
  Future<void> updateProgress(String taskId, double progress) async {
    await _lock.synchronized(() async {
      await _ensureInitialized();
      
      await _database!.update(
        'upload_tasks',
        {
          'progress': progress,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [taskId],
      );
    });
  }
  
  /// 批量更新任务状态
  Future<void> updateTasksStatus(
    List<String> taskIds,
    UploadStatus status, {
    String? errorMessage,
  }) async {
    await _lock.synchronized(() async {
      await _ensureInitialized();
      
      await _database!.transaction((txn) async {
        for (final taskId in taskIds) {
          await txn.update(
            'upload_tasks',
            {
              'status': status.index,
              'errorMessage': errorMessage,
              'updatedAt': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [taskId],
          );
        }
      });
    });
  }
  
  /// 获取待处理任务
  Future<List<UploadTask>> getPendingTasks() async {
    return await _lock.synchronized(() async {
      await _ensureInitialized();
      
      final maps = await _database!.query(
        'upload_tasks',
        where: 'status = ?',
        whereArgs: [UploadStatus.pending.index],
        orderBy: 'createdAt ASC',
      );
      
      return maps.map((map) => UploadTask.fromMap(map)).toList();
    });
  }
  
  /// 获取所有任务（分页）
  Future<List<UploadTask>> getAllTasks({
    int limit = 50,
    int offset = 0,
  }) async {
    return await _lock.synchronized(() async {
      await _ensureInitialized();
      
      final maps = await _database!.query(
        'upload_tasks',
        orderBy: 'createdAt DESC',
        limit: limit,
        offset: offset,
      );
      
      return maps.map((map) => UploadTask.fromMap(map)).toList();
    });
  }
  
  /// 根据状态获取任务
  Future<List<UploadTask>> getTasksByStatus(UploadStatus status) async {
    return await _lock.synchronized(() async {
      await _ensureInitialized();
      
      final maps = await _database!.query(
        'upload_tasks',
        where: 'status = ?',
        whereArgs: [status.index],
        orderBy: 'createdAt DESC',
      );
      
      return maps.map((map) => UploadTask.fromMap(map)).toList();
    });
  }
  
  /// 获取单个任务
  Future<UploadTask?> getTask(String taskId) async {
    return await _lock.synchronized(() async {
      await _ensureInitialized();
      
      final maps = await _database!.query(
        'upload_tasks',
        where: 'id = ?',
        whereArgs: [taskId],
        limit: 1,
      );
      
      if (maps.isEmpty) return null;
      return UploadTask.fromMap(maps.first);
    });
  }
  
  /// 删除任务
  Future<void> deleteTask(String taskId) async {
    await _lock.synchronized(() async {
      await _ensureInitialized();
      
      await _database!.delete(
        'upload_tasks',
        where: 'id = ?',
        whereArgs: [taskId],
      );
    });
  }
  
  /// 删除已完成的旧任务
  Future<void> deleteCompletedTasks({int olderThanDays = 7}) async {
    await _lock.synchronized(() async {
      await _ensureInitialized();
      
      final cutoff = DateTime.now().subtract(Duration(days: olderThanDays));
      
      await _database!.delete(
        'upload_tasks',
        where: 'status = ? AND createdAt < ?',
        whereArgs: [
          UploadStatus.completed.index,
          cutoff.toIso8601String(),
        ],
      );
    });
  }
  
  /// 清空所有任务（危险操作）
  Future<void> deleteAllTasks() async {
    await _lock.synchronized(() async {
      await _ensureInitialized();
      
      await _database!.delete('upload_tasks');
    });
  }
  
  /// 获取统计信息
  Future<Map<String, int>> getStatistics() async {
    return await _lock.synchronized(() async {
      await _ensureInitialized();
      
      final result = await _database!.rawQuery('''
        SELECT 
          status,
          COUNT(*) as count
        FROM upload_tasks
        GROUP BY status
      ''');
      
      final stats = <String, int>{};
      for (final row in result) {
        final statusIndex = row['status'] as int;
        final count = row['count'] as int;
        final status = UploadStatus.values[statusIndex];
        stats[status.name] = count;
      }
      
      return stats;
    });
  }
  
  /// 获取总任务数
  Future<int> getTotalCount() async {
    return await _lock.synchronized(() async {
      await _ensureInitialized();
      
      final result = await _database!.rawQuery(
        'SELECT COUNT(*) as count FROM upload_tasks'
      );
      
      return Sqflite.firstIntValue(result) ?? 0;
    });
  }
  
  /// 确保数据库已初始化
  Future<void> _ensureInitialized() async {
    if (_database == null) {
      throw StateError('Database not initialized. Call init() first.');
    }
  }
  
  /// 关闭数据库
  Future<void> close() async {
    await _lock.synchronized(() async {
      await _database?.close();
      _database = null;
    });
  }
}
