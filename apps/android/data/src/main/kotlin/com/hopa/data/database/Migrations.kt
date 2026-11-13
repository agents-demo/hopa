package com.hopa.data.database

import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

object Migrations {
    val MIGRATION_1_2: Migration = object : Migration(1, 2) {
        override fun migrate(database: SupportSQLiteDatabase) {
            database.execSQL(
                "ALTER TABLE sessions ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0",
            )
            database.execSQL(
                "ALTER TABLE sessions ADD COLUMN archivedAt INTEGER NOT NULL DEFAULT 0",
            )
        }
    }

    val MIGRATION_2_3: Migration = object : Migration(2, 3) {
        override fun migrate(database: SupportSQLiteDatabase) {
            database.execSQL(
                "CREATE TABLE IF NOT EXISTS `pending_approvals` (" +
                    "`id` TEXT NOT NULL, `title` TEXT NOT NULL, `body` TEXT NOT NULL, " +
                    "`amount` TEXT NOT NULL, `merchant` TEXT NOT NULL, " +
                    "`consequence` TEXT NOT NULL, `isPayment` INTEGER NOT NULL, " +
                    "`actionJson` TEXT NOT NULL, `createdAt` INTEGER NOT NULL, " +
                    "PRIMARY KEY(`id`))",
            )
        }
    }
}
