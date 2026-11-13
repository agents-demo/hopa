package com.hopa.data.database

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import com.hopa.data.database.dao.PendingApprovalDao
import com.hopa.data.database.dao.RunRecordDao
import com.hopa.data.database.dao.SessionDao
import com.hopa.data.database.dao.TurnDao
import com.hopa.data.database.entity.PendingApprovalEntity
import com.hopa.data.database.entity.RunRecordEntity
import com.hopa.data.database.entity.SessionEntity
import com.hopa.data.database.entity.TurnEntity

@Database(
    entities = [
        SessionEntity::class,
        TurnEntity::class,
        RunRecordEntity::class,
        PendingApprovalEntity::class,
    ],
    version = 3,
    exportSchema = false,
)
abstract class HopaDatabase : RoomDatabase() {
    abstract fun sessionDao(): SessionDao

    abstract fun turnDao(): TurnDao

    abstract fun runRecordDao(): RunRecordDao

    abstract fun pendingApprovalDao(): PendingApprovalDao

    companion object {
        fun build(context: Context): HopaDatabase =
            Room.databaseBuilder(context, HopaDatabase::class.java, "hopa.db")
                .addMigrations(Migrations.MIGRATION_1_2, Migrations.MIGRATION_2_3)
                .build()
    }
}
