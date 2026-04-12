package com.meetingassistant.memory

import android.content.Context
import androidx.room.*
import java.text.SimpleDateFormat
import java.util.*

@Entity(tableName = "sessions")
data class SessionEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val scenarioName: String,
    val durationSeconds: Long,
    val summary: String,
    val keyTermsJson: String,       // "term1:def1|term2:def2"
    val transcriptExcerpt: String,
    val createdAt: Long             // epoch millis
) {
    val formattedDate: String get() {
        val sdf = SimpleDateFormat("MMM d, yyyy HH:mm", Locale.getDefault())
        return sdf.format(Date(createdAt))
    }
    val formattedDuration: String get() {
        val m = durationSeconds / 60; val s = durationSeconds % 60
        return if (m > 0) "${m}m ${s}s" else "${s}s"
    }
}

@Dao
interface SessionDao {
    @Insert suspend fun insert(session: SessionEntity): Long
    @Query("SELECT * FROM sessions ORDER BY createdAt DESC LIMIT 20") suspend fun getRecent(): List<SessionEntity>
    @Query("SELECT * FROM sessions WHERE scenarioName = :scenario ORDER BY createdAt DESC LIMIT 1")
    suspend fun getLatestByScenario(scenario: String): SessionEntity?
}

@Database(entities = [SessionEntity::class], version = 1, exportSchema = false)
abstract class SessionDatabase : RoomDatabase() {
    abstract fun sessionDao(): SessionDao
    companion object {
        fun create(context: Context) = Room.databaseBuilder(
            context, SessionDatabase::class.java, "sessions.db"
        ).build()
    }
}
