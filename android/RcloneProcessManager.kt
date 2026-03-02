package com.example.photo_backup_app

import android.content.Context
import android.util.Log
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

/**
 * rclone 进程管理器
 * 功能：
 * - 启动/停止 rclone 进程
 * - 追踪 PID 防止泄漏
 * - 清理僵尸进程
 * - 解析上传进度
 */
class RcloneProcessManager(private val context: Context) {
    
    companion object {
        private const val PID_FILE = "rclone_processes.txt"
        private const val TAG = "RcloneProcessManager"
    }
    
    private val activeProcesses = ConcurrentHashMap<String, ProcessInfo>()
    private val pidFile = File(context.filesDir, PID_FILE)
    
    data class ProcessInfo(
        val process: Process,
        val uploadId: String,
        val startTime: Long,
        val pid: Long
    )
    
    init {
        // 启动时自动清理僵尸进程
        cleanupZombieProcesses()
    }
    
    /**
     * 清理所有僵尸进程（App 启动时调用）
     */
    fun cleanupZombieProcesses() {
        if (!pidFile.exists()) {
            Log.i(TAG, "No PID file found, skipping cleanup")
            return
        }
        
        try {
            val pids = pidFile.readLines()
                .mapNotNull { it.toLongOrNull() }
            
            Log.i(TAG, "Found ${pids.size} PIDs to check")
            
            pids.forEach { pid ->
                try {
                    if (isProcessRunning(pid)) {
                        Log.w(TAG, "Found zombie rclone process: $pid, killing...")
                        killProcess(pid)
                    } else {
                        Log.d(TAG, "Process $pid already dead")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to kill zombie process $pid", e)
                }
            }
            
            // 清空 PID 文件
            pidFile.delete()
            Log.i(TAG, "Zombie process cleanup complete")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read PID file", e)
        }
    }
    
    /**
     * 启动 rclone 上传进程
     */
    fun startUpload(
        uploadId: String,
        localPath: String,
        remotePath: String,
        configPath: String,
        progressCallback: ((UploadProgress) -> Unit)? = null
    ): Process {
        val rclonePath = "${context.applicationInfo.nativeLibraryDir}/librclone.so"
        
        // 检查 rclone 二进制是否存在
        if (!File(rclonePath).exists()) {
            throw IllegalStateException("rclone binary not found at $rclonePath")
        }
        
        // 检查配置文件
        if (!File(configPath).exists()) {
            throw IllegalStateException("rclone config not found at $configPath")
        }
        
        val processBuilder = ProcessBuilder(
            rclonePath,
            "copy",
            localPath,
            remotePath,
            "--config", configPath,
            "--progress",
            "--stats", "1s",
            "--log-level", "INFO",
            "--timeout", "1800s",
            "--retries", "3",
            "--low-level-retries", "10",
            "--stats-one-line"
        )
        
        processBuilder.redirectErrorStream(false)
        val process = processBuilder.start()
        
        // 获取 PID
        val pid = process.pid()
        
        // 记录到内存
        activeProcesses[uploadId] = ProcessInfo(
            process = process,
            uploadId = uploadId,
            startTime = System.currentTimeMillis(),
            pid = pid
        )
        
        // 持久化 PID 到文件
        savePid(pid)
        
        Log.i(TAG, "Started rclone process: uploadId=$uploadId, pid=$pid")
        
        // 启动进度解析线程
        if (progressCallback != null) {
            startProgressMonitor(process, uploadId, progressCallback)
        }
        
        return process
    }
    
    /**
     * 监控上传进度
     */
    private fun startProgressMonitor(
        process: Process,
        uploadId: String,
        callback: (UploadProgress) -> Unit
    ) {
        thread {
            try {
                val reader = BufferedReader(InputStreamReader(process.errorStream))
                var line: String?
                
                while (reader.readLine().also { line = it } != null) {
                    line?.let { 
                        parseProgress(it, uploadId)?.let(callback)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Progress monitor error for $uploadId", e)
            }
        }
    }
    
    /**
     * 解析 rclone 进度输出
     * 示例: "Transferred:   	    5.123 MiB / 10.456 MiB, 49%, 1.234 MiB/s, ETA 4s"
     */
    private fun parseProgress(line: String, uploadId: String): UploadProgress? {
        try {
            // 匹配: "Transferred: X MiB / Y MiB, Z%, A MiB/s, ETA Bs"
            val regex = """Transferred:\s+[\d.]+\s+\w+\s+/\s+([\d.]+)\s+(\w+),\s+([\d.]+)%,\s+([\d.]+)\s+\w+/s,\s+ETA\s+([\d.]+)""".toRegex()
            val match = regex.find(line) ?: return null
            
            val totalSize = match.groupValues[1].toDouble()
            val unit = match.groupValues[2]
            val percent = match.groupValues[3].toDouble()
            val speed = match.groupValues[4].toDouble()
            val eta = match.groupValues[5].toDouble()
            
            // 转换为字节
            val totalBytes = convertToBytes(totalSize, unit)
            val bytesTransferred = (totalBytes * percent / 100).toLong()
            
            return UploadProgress(
                percent = percent,
                bytesTransferred = bytesTransferred,
                totalBytes = totalBytes,
                speedMBps = speed,
                etaSeconds = eta.toInt(),
                status = UploadStatus.UPLOADING
            )
            
        } catch (e: Exception) {
            Log.w(TAG, "Failed to parse progress: $line", e)
            return null
        }
    }
    
    /**
     * 转换单位到字节
     */
    private fun convertToBytes(value: Double, unit: String): Long {
        return when (unit.uppercase()) {
            "B" -> value.toLong()
            "KIB", "KB" -> (value * 1024).toLong()
            "MIB", "MB" -> (value * 1024 * 1024).toLong()
            "GIB", "GB" -> (value * 1024 * 1024 * 1024).toLong()
            else -> value.toLong()
        }
    }
    
    /**
     * 取消上传并清理进程
     */
    fun cancelUpload(uploadId: String): Boolean {
        val info = activeProcesses[uploadId] ?: return false
        
        return try {
            Log.i(TAG, "Cancelling upload: $uploadId (pid=${info.pid})")
            
            // 1. 尝试优雅关闭 (SIGTERM)
            info.process.destroy()
            
            // 2. 等待最多 5 秒
            val exited = info.process.waitFor(5, TimeUnit.SECONDS)
            
            // 3. 强制杀死 (SIGKILL)
            if (!exited) {
                Log.w(TAG, "Process didn't exit gracefully, forcing kill")
                info.process.destroyForcibly()
                info.process.waitFor(2, TimeUnit.SECONDS)
            }
            
            // 4. 从记录中移除
            activeProcesses.remove(uploadId)
            removePid(info.pid)
            
            Log.i(TAG, "Upload cancelled successfully: $uploadId")
            true
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to cancel upload: $uploadId", e)
            
            // 强制清理
            try {
                info.process.destroyForcibly()
                activeProcesses.remove(uploadId)
                removePid(info.pid)
            } catch (e2: Exception) {
                Log.e(TAG, "Force cleanup failed", e2)
            }
            
            false
        }
    }
    
    /**
     * 清理所有活跃进程（App 关闭时调用）
     */
    fun cleanup() {
        Log.i(TAG, "Cleaning up ${activeProcesses.size} active processes")
        
        activeProcesses.values.forEach { info ->
            try {
                info.process.destroyForcibly()
                removePid(info.pid)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to cleanup process ${info.pid}", e)
            }
        }
        
        activeProcesses.clear()
        pidFile.delete()
    }
    
    /**
     * 保存 PID 到文件（追加模式）
     */
    private fun savePid(pid: Long) {
        try {
            pidFile.appendText("$pid\n")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save PID: $pid", e)
        }
    }
    
    /**
     * 从文件中移除 PID
     */
    private fun removePid(pid: Long) {
        try {
            if (!pidFile.exists()) return
            
            val pids = pidFile.readLines()
                .filter { it != pid.toString() }
            
            if (pids.isEmpty()) {
                pidFile.delete()
            } else {
                pidFile.writeText(pids.joinToString("\n") + "\n")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to remove PID: $pid", e)
        }
    }
    
    /**
     * 检查进程是否还在运行
     */
    private fun isProcessRunning(pid: Long): Boolean {
        return try {
            // Linux: /proc/[pid] 存在表示进程存在
            File("/proc/$pid").exists()
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * 杀死指定 PID 的进程
     */
    private fun killProcess(pid: Long) {
        try {
            // 使用 kill 命令
            val killProcess = Runtime.getRuntime().exec("kill -9 $pid")
            killProcess.waitFor(2, TimeUnit.SECONDS)
            
            Log.i(TAG, "Killed process: $pid")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to kill process: $pid", e)
        }
    }
    
    /**
     * 获取活跃上传数量
     */
    fun getActiveUploadCount(): Int = activeProcesses.size
    
    /**
     * 获取所有活跃上传的 ID
     */
    fun getActiveUploadIds(): List<String> = activeProcesses.keys.toList()
}
