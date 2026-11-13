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
}
