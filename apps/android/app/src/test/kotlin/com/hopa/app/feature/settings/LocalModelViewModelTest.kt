package com.hopa.app.feature.settings

import android.net.Uri
import com.hopa.app.di.LocalModelHost
import com.hopa.inference.local.ImportOutcome
import com.hopa.inference.local.InstalledModel
import com.hopa.inference.local.LocalModelCatalogue
import com.hopa.inference.local.ModelSpec
import com.hopa.engine.llama.LocalModelStore
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.setMain
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test

@OptIn(ExperimentalCoroutinesApi::class)
class LocalModelViewModelTest {
    private val dispatcher = StandardTestDispatcher()

    @BeforeEach
    fun setUp() {
        Dispatchers.setMain(dispatcher)
    }

    @AfterEach
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun the_first_visit_recommends_a_model_for_the_phone() = runTest(dispatcher) {
        val viewModel = LocalModelViewModel(host(ramGb = 8, freeBytes = 20_000_000_000L))

        advanceUntilIdle()

        assertEquals("qwen3-4b", viewModel.state.value.recommended?.id)
        assertEquals(0L, viewModel.state.value.totalBytes)
    }

    @Test
    fun installed_models_are_counted_in_the_total() = runTest(dispatcher) {
        val installed = InstalledModel("qwen3-1.7b", File("qwen3-1.7b-1234.gguf"), 1_100_000_000L)
        val viewModel = LocalModelViewModel(
            host(ramGb = 8, freeBytes = 20_000_000_000L, installed = listOf(installed)),
        )

        advanceUntilIdle()

        assertEquals(1, viewModel.state.value.installed.size)
        assertEquals(1_100_000_000L, viewModel.state.value.totalBytes)
        assertNotNull(viewModel.state.value.installedSpecs["qwen3-1.7b"])
    }

    @Test
    fun delete_removes_the_file_and_refreshes_the_total() = runTest(dispatcher) {
        val store = FakeStore(
            installed = listOf(
                InstalledModel("qwen3-1.7b", File("qwen3-1.7b-1234.gguf"), 1_100_000_000L),
            ),
        )
        val viewModel = LocalModelViewModel(
            host(ramGb = 8, freeBytes = 20_000_000_000L, store = store),
        )
        advanceUntilIdle()

        viewModel.delete("qwen3-1.7b")
        advanceUntilIdle()

        assertEquals(listOf("qwen3-1.7b"), store.deleted)
        assertEquals(0L, viewModel.state.value.totalBytes)
        assertEquals("Model removed.", viewModel.state.value.notice)
    }

    @Test
    fun a_download_asks_for_the_licence_first() = runTest(dispatcher) {
        val store = FakeStore()
        val viewModel = LocalModelViewModel(host(ramGb = 8, freeBytes = 20_000_000_000L, store = store))
        advanceUntilIdle()
        val spec = com.hopa.inference.local.LocalModelCatalogue.models.first { it.id == "qwen3-4b" }

        viewModel.download(spec)
        advanceUntilIdle()

        assertEquals(spec, viewModel.state.value.licenceFor)
        assertEquals(emptyList<String>(), store.downloads)
    }

    @Test
    fun accepting_the_licence_downloads_and_remembers_it() = runTest(dispatcher) {
        val store = FakeStore()
        val settings = fakeSettings()
        val viewModel = LocalModelViewModel(
            host(ramGb = 8, freeBytes = 20_000_000_000L, store = store, settings = settings),
        )
        advanceUntilIdle()
        val spec = com.hopa.inference.local.LocalModelCatalogue.models.first { it.id == "qwen3-4b" }
        viewModel.download(spec)
        advanceUntilIdle()

        viewModel.acceptLicenceAndDownload()
        advanceUntilIdle()

        assertEquals(listOf("qwen3-4b"), store.downloads)
        val accepted = settings.settings.first().acceptedModelLicences
        assertEquals(setOf("qwen3-4b:${spec.sha256}"), accepted)
        assertEquals(null, viewModel.state.value.licenceFor)
    }

    @Test
    fun the_quota_stops_a_model_that_does_not_fit() = runTest(dispatcher) {
        val installed = InstalledModel("qwen3-1.7b", File("qwen3-1.7b-1234.gguf"), 7_900_000_000L)
        val store = FakeStore(listOf(installed))
        val viewModel = LocalModelViewModel(
            host(ramGb = 8, freeBytes = 20_000_000_000L, store = store, installed = listOf(installed)),
        )
        advanceUntilIdle()
        val spec = com.hopa.inference.local.LocalModelCatalogue.models.first { it.id == "qwen3-4b" }

        viewModel.download(spec)
        advanceUntilIdle()

        assertEquals(emptyList<String>(), store.downloads)
        assertNotNull(viewModel.state.value.error)
        assertEquals(true, viewModel.state.value.error!!.contains("Models already use"))
    }

    @Test
    fun a_phone_with_no_room_gets_no_offer() = runTest(dispatcher) {
        val viewModel = LocalModelViewModel(host(ramGb = 8, freeBytes = 10_000_000L))

        advanceUntilIdle()

        assertEquals(null, viewModel.state.value.recommended)
    }

    private fun host(
        ramGb: Int,
        freeBytes: Long,
        installed: List<InstalledModel> = emptyList(),
        store: FakeStore = FakeStore(installed),
        settings: com.hopa.stores.SettingsRepository = fakeSettings(),
    ): LocalModelHost = object : LocalModelHost {
        override val localModels: LocalModelStore = store
        override val ramGb: Int = ramGb
        override val freeBytes: Long = freeBytes
        override val settings: com.hopa.stores.SettingsRepository = settings
    }

    private fun fakeSettings(): com.hopa.stores.SettingsRepository =
        object : com.hopa.stores.SettingsRepository {
            private val flow = kotlinx.coroutines.flow.MutableStateFlow(com.hopa.stores.AppSettings())
            override val settings: kotlinx.coroutines.flow.Flow<com.hopa.stores.AppSettings> = flow

            override suspend fun update(transform: (com.hopa.stores.AppSettings) -> com.hopa.stores.AppSettings) {
                flow.value = transform(flow.value)
            }

            override suspend fun modelKey(): String = ""
            override suspend fun hasModelKey(): Boolean = false
            override suspend fun setModelKey(value: String) = Unit
            override suspend fun bridgeToken(): String = ""
            override suspend fun setBridgeToken(value: String) = Unit
            override suspend fun bridgeRefresh(): String = ""
            override suspend fun setBridgeRefresh(value: String) = Unit
            override suspend fun backendAccessToken(): String = ""
            override suspend fun setBackendAccessToken(value: String) = Unit
            override suspend fun backendRefreshToken(): String = ""
            override suspend fun setBackendRefreshToken(value: String) = Unit
            override suspend fun backendPrivateKey(): String = ""
            override suspend fun setBackendPrivateKey(value: String) = Unit
            override suspend fun clearBackend() = Unit
        }

    private class FakeStore(
        var installed: List<InstalledModel> = emptyList(),
    ) : LocalModelStore {
        val deleted = mutableListOf<String>()
        val downloads = mutableListOf<String>()

        override suspend fun installed(): List<InstalledModel> = installed

        override suspend fun totalBytes(): Long = installed.sumOf { it.bytes }

        override suspend fun import(uri: Uri, spec: ModelSpec): ImportOutcome = ImportOutcome.Empty

        override suspend fun download(spec: ModelSpec, onProgress: (Long, Long) -> Unit): ImportOutcome {
            downloads += spec.id
            return ImportOutcome.Empty
        }

        override suspend fun delete(id: String): Boolean {
            deleted += id
            installed = installed.filterNot { it.id == id }
            return true
        }

        override suspend fun cleanup(keep: Set<String>): Int {
            val size = installed.size
            installed = installed.filter { it.id in keep }
            return size - installed.size
        }
    }
}
