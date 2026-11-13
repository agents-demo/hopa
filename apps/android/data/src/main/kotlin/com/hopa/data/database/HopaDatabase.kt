package com.hopa.data.database

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import com.hopa.data.database.dao.RunRecordDao
import com.hopa.data.database.dao.SessionDao
import com.hopa.data.database.dao.TurnDao
import com.hopa.data.database.entity.RunRecordEntity
import com.hopa.data.database.entity.SessionEntity
import com.hopa.data.database.entity.TurnEntity

@Database(
    entities = [SessionEntity::class, TurnEntity::class, RunRecordEntity::class],
    version = 1,
    exportSchema = false,
)
abstract class HopaDatabase : RoomDatabase() {
    abstract fun sessionDao(): SessionDao

    abstract fun turnDao(): TurnDao

    abstract fun runRecordDao(): RunRecordDao

    companion object {
        fun build(context: Context): HopaDatabase =
            Room.databaseBuilder(context, HopaDatabase::class.java, "hopa.db").build()
    }
}
