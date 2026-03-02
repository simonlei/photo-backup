package com.example.photo_backup_app

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.util.Log
import kotlin.concurrent.thread

/**
 * 定期清理僵尸进程的后台任务
 * 每 6 小时运行一次
 */
class ProcessCleanupJob : JobService() {
    
    companion object {
        private const val JOB_ID = 1001
        private const val TAG = "ProcessCleanupJob"
        private const val CLEANUP_INTERVAL_MS = 6 * 60 * 60 * 1000L // 6 小时
        
        /**
         * 调度定期清理任务
         */
        fun schedule(context: Context) {
            val jobScheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
            
            // 检查是否已经调度
            val existingJob = jobScheduler.getPendingJob(JOB_ID)
            if (existingJob != null) {
                Log.i(TAG, "Cleanup job already scheduled")
                return
            }
            
            val jobInfo = JobInfo.Builder(
                JOB_ID,
                ComponentName(context, ProcessCleanupJob::class.java)
            )
                .setPeriodic(CLEANUP_INTERVAL_MS) // 6 小时
                .setRequiresDeviceIdle(false)
                .setRequiresCharging(false)
                .setPersisted(true) // 重启后保持
                .build()
            
            val result = jobScheduler.schedule(jobInfo)
            if (result == JobScheduler.RESULT_SUCCESS) {
                Log.i(TAG, "Scheduled periodic process cleanup (every 6 hours)")
            } else {
                Log.e(TAG, "Failed to schedule process cleanup job")
            }
        }
        
        /**
         * 取消定期清理任务
         */
        fun cancel(context: Context) {
            val jobScheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
            jobScheduler.cancel(JOB_ID)
            Log.i(TAG, "Cancelled periodic process cleanup")
        }
    }
    
    override fun onStartJob(params: JobParameters): Boolean {
        Log.i(TAG, "Starting process cleanup job")
        
        // 异步执行清理
        thread {
            try {
                val processManager = RcloneProcessManager(applicationContext)
                processManager.cleanupZombieProcesses()
                
                Log.i(TAG, "Process cleanup completed successfully")
            } catch (e: Exception) {
                Log.e(TAG, "Process cleanup failed", e)
            } finally {
                // 通知系统任务完成
                jobFinished(params, false)
            }
        }
        
        // 返回 true 表示异步执行
        return true
    }
    
    override fun onStopJob(params: JobParameters): Boolean {
        Log.w(TAG, "Job stopped by system (resource constraints)")
        // 返回 true 表示需要重新调度
        return true
    }
}
