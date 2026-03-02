package com.example.photo_backup_app

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.EventChannel
import kotlin.concurrent.thread

class MainActivity: FlutterActivity() {
    
    private val METHOD_CHANNEL = "com.example.photobackup/rclone"
    private val EVENT_CHANNEL = "com.example.photobackup/rclone_progress"
    
    private lateinit var processManager: RcloneProcessManager
    private val mainHandler = Handler(Looper.getMainLooper())
    
    private var progressEventSink: EventChannel.EventSink? = null
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 初始化进程管理器（自动清理僵尸进程）
        processManager = RcloneProcessManager(applicationContext)
        
        // 调度定期清理任务
        ProcessCleanupJob.schedule(applicationContext)
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // MethodChannel - 命令通道
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "uploadFile" -> handleUpload(call, result)
                    "cancelUpload" -> handleCancel(call, result)
                    "getActiveUploads" -> handleGetActiveUploads(result)
                    "testConnection" -> handleTestConnection(call, result)
                    "saveRcloneConfig" -> handleSaveConfig(call, result)
                    "obscurePassword" -> handleObscurePassword(call, result)  // 🔒 新增密码混淆
                    else -> result.notImplemented()
                }
            }
        
        // EventChannel - 进度流
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    progressEventSink = events
                }
                
                override fun onCancel(arguments: Any?) {
                    progressEventSink = null
                }
            })
    }
    
    private fun handleUpload(call: MethodCall, result: MethodChannel.Result) {
        val uploadId = call.argument<String>("uploadId") ?: run {
            result.error("INVALID_ARGUMENT", "uploadId is required", null)
            return
        }
        
        val localPath = call.argument<String>("localPath") ?: run {
            result.error("INVALID_ARGUMENT", "localPath is required", null)
            return
        }
        
        val remotePath = call.argument<String>("remotePath") ?: run {
            result.error("INVALID_ARGUMENT", "remotePath is required", null)
            return
        }
        
        val configPath = "${filesDir}/rclone.conf"
        
        // 后台线程执行上传
        thread {
            try {
                val process = processManager.startUpload(
                    uploadId = uploadId,
                    localPath = localPath,
                    remotePath = remotePath,
                    configPath = configPath,
                    progressCallback = { progress ->
                        // 发送进度到 Flutter
                        mainHandler.post {
                            progressEventSink?.success(mapOf(
                                "uploadId" to uploadId,
                                "percent" to progress.percent,
                                "bytesTransferred" to progress.bytesTransferred,
                                "totalBytes" to progress.totalBytes,
                                "speedMBps" to progress.speedMBps,
                                "etaSeconds" to progress.etaSeconds,
                                "status" to progress.status.ordinal,
                            ))
                        }
                    }
                )
                
                // 等待完成
                val exitCode = process.waitFor()
                
                mainHandler.post {
                    if (exitCode == 0) {
                        result.success(null)
                    } else {
                        result.error("UPLOAD_FAILED", "Exit code: $exitCode", null)
                    }
                }
                
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("EXCEPTION", e.message, null)
                }
            }
        }
    }
    
    private fun handleCancel(call: MethodCall, result: MethodChannel.Result) {
        val uploadId = call.argument<String>("uploadId") ?: run {
            result.error("INVALID_ARGUMENT", "uploadId is required", null)
            return
        }
        
        val success = processManager.cancelUpload(uploadId)
        result.success(success)
    }
    
    private fun handleGetActiveUploads(result: MethodChannel.Result) {
        val activeIds = processManager.getActiveUploadIds()
        result.success(activeIds)
    }
    
    private fun handleTestConnection(call: MethodCall, result: MethodChannel.Result) {
        // TODO: 实现连接测试
        result.success(true)
    }
    
    private fun handleSaveConfig(call: MethodCall, result: MethodChannel.Result) {
        val config = call.argument<String>("config") ?: run {
            result.error("INVALID_ARGUMENT", "config is required", null)
            return
        }
        
        try {
            val configFile = java.io.File(filesDir, "rclone.conf")
            configFile.writeText(config)
            
            // ✅ 不在日志中记录配置内容（避免密码泄露）
            android.util.Log.d("MainActivity", "Config saved (${config.length} bytes)")
            result.success(null)
        } catch (e: Exception) {
            result.error("IO_ERROR", e.message, null)
        }
    }
    
    /**
     * 🔒 混淆密码（调用 rclone obscure 命令）
     * 用于在存储和传输前保护密码安全
     */
    private fun handleObscurePassword(call: MethodCall, result: MethodChannel.Result) {
        val password = call.argument<String>("password") ?: run {
            result.error("INVALID_ARGUMENT", "password is required", null)
            return
        }
        
        thread {
            try {
                val rclonePath = "${applicationInfo.nativeLibraryDir}/librclone.so"
                
                // 调用 rclone obscure
                val process = ProcessBuilder(rclonePath, "obscure", password)
                    .redirectErrorStream(true)
                    .start()
                
                val reader = java.io.BufferedReader(
                    java.io.InputStreamReader(process.inputStream)
                )
                
                val obscured = reader.use { it.readLine() }
                    ?: throw Exception("rclone obscure returned empty result")
                
                val exitCode = process.waitFor()
                
                if (exitCode != 0) {
                    throw Exception("rclone obscure failed with exit code $exitCode")
                }
                
                mainHandler.post {
                    result.success(obscured)
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("OBSCURE_ERROR", "Failed to obscure password: ${e.message}", null)
                }
            }
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        // 清理所有活跃进程
        processManager.cleanup()
    }
}

// 进度数据类
data class UploadProgress(
    val percent: Double,
    val bytesTransferred: Long,
    val totalBytes: Long,
    val speedMBps: Double,
    val etaSeconds: Int,
    val status: UploadStatus
)

enum class UploadStatus {
    PENDING,
    UPLOADING,
    COMPLETED,
    FAILED,
    CANCELLED
}
