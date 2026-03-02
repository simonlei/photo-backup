import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../blocs/upload_bloc.dart';
import '../models/upload_task.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('照片备份'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: BlocBuilder<UploadBloc, UploadState>(
        builder: (context, state) {
          if (state is UploadInitial) {
            return _buildEmptyState(context);
          } else if (state is UploadQueueLoaded) {
            return _buildQueueList(context, state);
          } else if (state is UploadInProgress) {
            return _buildUploadingState(context, state);
          } else if (state is UploadSuccess) {
            return _buildSuccessState(context, state);
          } else if (state is UploadFailure) {
            return _buildErrorState(context, state);
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _pickAndUploadPhotos(context),
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('选择照片'),
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 120,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            '还没有上传任务',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮选择照片开始备份',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }

  /// 队列列表
  Widget _buildQueueList(BuildContext context, UploadQueueLoaded state) {
    final allTasks = [
      ...state.uploading,
      ...state.pending,
      ...state.completed,
      ...state.failed,
    ];

    if (allTasks.isEmpty) {
      return _buildEmptyState(context);
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<UploadBloc>().add(const LoadUploadQueue());
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 统计卡片
          _buildStatisticsCard(context, state),
          const SizedBox(height: 16),

          // 上传中
          if (state.uploading.isNotEmpty) ...[
            _buildSectionHeader('上传中 (${state.uploading.length})'),
            ...state.uploading.map((task) => _buildTaskCard(context, task)),
            const SizedBox(height: 16),
          ],

          // 待上传
          if (state.pending.isNotEmpty) ...[
            _buildSectionHeader('待上传 (${state.pending.length})'),
            ...state.pending.map((task) => _buildTaskCard(context, task)),
            const SizedBox(height: 16),
          ],

          // 已完成
          if (state.completed.isNotEmpty) ...[
            _buildSectionHeader('已完成 (${state.completed.length})'),
            ...state.completed.map((task) => _buildTaskCard(context, task)),
            const SizedBox(height: 16),
          ],

          // 失败
          if (state.failed.isNotEmpty) ...[
            _buildSectionHeader('失败 (${state.failed.length})'),
            ...state.failed.map((task) => _buildTaskCard(context, task)),
          ],
        ],
      ),
    );
  }

  /// 统计卡片
  Widget _buildStatisticsCard(BuildContext context, UploadQueueLoaded state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                context,
                Icons.cloud_queue,
                '总任务',
                state.totalCount.toString(),
                Colors.blue,
              ),
              _buildStatItem(
                context,
                Icons.cloud_upload,
                '上传中',
                state.uploading.length.toString(),
                Colors.orange,
              ),
              _buildStatItem(
                context,
                Icons.cloud_done,
                '已完成',
                state.completed.length.toString(),
                Colors.green,
              ),
              _buildStatItem(
                context,
                Icons.error_outline,
                '失败',
                state.failed.length.toString(),
                Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 统计项
  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  /// 分组标题
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 任务卡片
  Widget _buildTaskCard(BuildContext context, UploadTask task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _buildTaskIcon(task),
        title: Text(
          task.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (task.isInProgress) ...[
              LinearProgressIndicator(value: task.progress / 100),
              const SizedBox(height: 4),
              Text('${task.progress.toStringAsFixed(1)}%'),
            ] else
              Text(_getTaskStatusText(task)),
            if (task.errorMessage != null)
              Text(
                task.errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: _buildTaskActions(context, task),
      ),
    );
  }

  /// 任务图标
  Widget _buildTaskIcon(UploadTask task) {
    IconData icon;
    Color color;

    switch (task.status) {
      case UploadStatus.pending:
        icon = Icons.schedule;
        color = Colors.grey;
        break;
      case UploadStatus.uploading:
        icon = Icons.cloud_upload;
        color = Colors.blue;
        break;
      case UploadStatus.completed:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case UploadStatus.failed:
        icon = Icons.error;
        color = Colors.red;
        break;
      case UploadStatus.cancelled:
        icon = Icons.cancel;
        color = Colors.orange;
        break;
    }

    return Icon(icon, color: color, size: 40);
  }

  /// 任务操作按钮
  Widget _buildTaskActions(BuildContext context, UploadTask task) {
    if (task.isInProgress) {
      return IconButton(
        icon: const Icon(Icons.close),
        onPressed: () {
          context.read<UploadBloc>().add(CancelUpload(task.id));
        },
      );
    } else if (task.canRetry) {
      return IconButton(
        icon: const Icon(Icons.refresh),
        onPressed: () {
          context.read<UploadBloc>().add(RetryUpload(task.id));
        },
      );
    }
    return const SizedBox.shrink();
  }

  /// 获取任务状态文本
  String _getTaskStatusText(UploadTask task) {
    switch (task.status) {
      case UploadStatus.pending:
        return '等待上传';
      case UploadStatus.uploading:
        return '上传中';
      case UploadStatus.completed:
        return '已完成';
      case UploadStatus.failed:
        return '失败';
      case UploadStatus.cancelled:
        return '已取消';
    }
  }

  /// 上传中状态
  Widget _buildUploadingState(BuildContext context, UploadInProgress state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: CircularProgressIndicator(
              value: state.progress / 100,
              strokeWidth: 8,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '${state.progress.toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${state.speedMBps.toStringAsFixed(1)} MB/s',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            '剩余时间: ${_formatEta(state.etaSeconds)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  /// 成功状态
  Widget _buildSuccessState(BuildContext context, UploadSuccess state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 120,
            color: Colors.green,
          ),
          const SizedBox(height: 24),
          Text(
            '上传成功！',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            state.task.fileName,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  /// 错误状态
  Widget _buildErrorState(BuildContext context, UploadFailure state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 120,
            color: Colors.red,
          ),
          const SizedBox(height: 24),
          Text(
            '上传失败',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              state.errorMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.red[700],
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          if (state.failedTask != null)
            ElevatedButton.icon(
              onPressed: () {
                context.read<UploadBloc>().add(RetryUpload(state.taskId));
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
        ],
      ),
    );
  }

  /// 选择并上传照片
  Future<void> _pickAndUploadPhotos(BuildContext context) async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();

    if (images.isEmpty) return;

    final uuid = const Uuid();
    final tasks = images.map((image) {
      return UploadTask.create(
        id: uuid.v4(),
        localPath: image.path,
        remotePath: 'nas:/photos/${image.name}',
      );
    }).toList();

    context.read<UploadBloc>().add(StartBatchUpload(tasks));
    
    // 显示提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已添加 ${tasks.length} 张照片到上传队列'),
        action: SnackBarAction(
          label: '查看',
          onPressed: () {
            context.read<UploadBloc>().add(const LoadUploadQueue());
          },
        ),
      ),
    );
  }

  /// 格式化剩余时间
  String _formatEta(int seconds) {
    if (seconds < 60) {
      return '$seconds 秒';
    } else if (seconds < 3600) {
      return '${(seconds / 60).floor()} 分钟';
    } else {
      return '${(seconds / 3600).floor()} 小时';
    }
  }
}
