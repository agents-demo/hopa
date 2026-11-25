package com.hopa.app.pair

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.common.InputImage
import com.hopa.app.di.AppContainer
import com.hopa.backend.pairing.AdmissionLink
import com.hopa.backend.pairing.AdmissionLinks
import com.hopa.ui.component.HopaPageHeader
import com.hopa.ui.theme.HopaColor

/**
 * The PC-admission surface: scan the PC's QR or paste its code, confirm the PC
 * by name and fingerprint, and vouch. Camera is additive — the paste field is
 * always there — so a denied permission, a missing camera or a failed analyzer
 * falls back to paste with a hint, never a dead end.
 */
@Composable
fun ScanRoute(
    container: AppContainer,
    onBack: () -> Unit,
    onVouched: () -> Unit,
) {
    val viewModel = remember { VouchViewModel(container.settings) }
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(state.vouched) {
        if (state.vouched) {
            onVouched()
        }
    }

    val confirm = state.confirm
    if (confirm != null) {
        ConfirmScreen(
            name = confirm.name,
            fingerprint = confirm.fingerprint,
            busy = state.busy,
            error = state.error,
            onConfirm = viewModel::confirm,
            onBack = onBack,
        )
    } else {
        ScanScreen(
            busy = state.busy,
            error = state.error,
            onScanned = viewModel::resolve,
            onPaste = viewModel::resolvePasted,
            onBack = onBack,
        )
    }
}

@Composable
private fun ScanScreen(
    busy: Boolean,
    error: String?,
    onScanned: (AdmissionLink) -> Unit,
    onPaste: (String) -> Unit,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    var paste by rememberSaveable { mutableStateOf("") }
    var cameraGranted by remember { mutableStateOf(false) }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        cameraGranted = granted
    }

    LaunchedEffect(Unit) {
        val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
        if (granted) {
            cameraGranted = true
        } else {
            permissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    Scaffold(
        containerColor = HopaColor.Bg,
        topBar = { HopaPageHeader(title = "Pair this PC", onBack = onBack) },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 4.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                "Point the camera at the PC's pairing QR, or paste the code it shows.",
                fontSize = 13.sp,
                color = HopaColor.TextSecondary,
            )
            if (cameraGranted) {
                CameraPreview(
                    onScanned = onScanned,
                    onUnavailable = { cameraGranted = false },
                )
            } else {
                Text(
                    "The camera is not available — paste the pairing code below instead.",
                    fontSize = 12.sp,
                    color = HopaColor.TextHint,
                )
            }
            OutlinedTextField(
                value = paste,
                onValueChange = { paste = it },
                label = { Text("Pairing code from the PC") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            Button(
                onClick = { onPaste(paste.trim()) },
                enabled = !busy && paste.isNotBlank(),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp),
            ) {
                Text(if (busy) "Reading\u2026" else "Use this code")
            }
            error?.let { message ->
                Text(message, fontSize = 13.sp, color = HopaColor.Danger)
            }
        }
    }
}

/** CameraX preview + ML Kit barcode scan, firing once on the first `hopa://` code. */
@Composable
private fun CameraPreview(
    onScanned: (AdmissionLink) -> Unit,
    onUnavailable: () -> Unit,
) {
    val context = LocalContext.current
    val lifecycleOwner: LifecycleOwner = LocalLifecycleOwner.current
    val previewView = remember { PreviewView(context) }

    DisposableEffect(lifecycleOwner) {
        val executor = ContextCompat.getMainExecutor(context)
        var provider: ProcessCameraProvider? = null
        val scanner = BarcodeScanning.getClient()
        var delivered = false

        val analyzer = object : ImageAnalysis.Analyzer {
            override fun analyze(imageProxy: ImageProxy) {
                val mediaImage = imageProxy.image
                if (mediaImage == null) {
                    imageProxy.close()
                    return
                }
                val input = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
                scanner.process(input)
                    .addOnSuccessListener { barcodes ->
                        for (barcode in barcodes) {
                            val link = barcode.rawValue?.let(AdmissionLinks::parse)
                            if (link != null && !delivered) {
                                delivered = true
                                onScanned(link)
                                break
                            }
                        }
                    }
                    .addOnCompleteListener { imageProxy.close() }
            }
        }

        val future = ProcessCameraProvider.getInstance(context)
        future.addListener({
            val cameraProvider = runCatching { future.get() }.getOrNull()
            if (cameraProvider == null) {
                onUnavailable()
                return@addListener
            }
            provider = cameraProvider
            val preview = Preview.Builder().build().also {
                it.surfaceProvider = previewView.surfaceProvider
            }
            val analysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()
            analysis.setAnalyzer(executor, analyzer)
            try {
                cameraProvider.unbindAll()
                cameraProvider.bindToLifecycle(
                    lifecycleOwner,
                    CameraSelector.DEFAULT_BACK_CAMERA,
                    preview,
                    analysis,
                )
            } catch (error: Exception) {
                onUnavailable()
            }
        }, executor)

        onDispose {
            provider?.unbindAll()
        }
    }

    AndroidView(
        factory = { previewView },
        modifier = Modifier
            .fillMaxWidth()
            .height(300.dp),
    )
}

@Composable
private fun ConfirmScreen(
    name: String,
    fingerprint: String,
    busy: Boolean,
    error: String?,
    onConfirm: () -> Unit,
    onBack: () -> Unit,
) {
    Scaffold(
        containerColor = HopaColor.Bg,
        topBar = { HopaPageHeader(title = "Pair this PC", onBack = onBack) },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 4.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                "Let this computer connect?",
                fontSize = 19.sp,
                fontWeight = FontWeight.SemiBold,
                color = HopaColor.TextPrimary,
            )
            Text(
                name,
                fontSize = 15.sp,
                color = HopaColor.TextPrimary,
            )
            Text(
                "Fingerprint $fingerprint",
                fontSize = 12.sp,
                color = HopaColor.TextHint,
            )
            Text(
                "This lets the computer read the screen and run tasks for you. " +
                    "Only continue if the name and fingerprint match the computer you expect.",
                fontSize = 12.sp,
                color = HopaColor.TextSecondary,
            )
            Button(
                onClick = onConfirm,
                enabled = !busy,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp),
            ) {
                Text(if (busy) "Connecting\u2026" else "Confirm this computer")
            }
            error?.let { message ->
                Text(message, fontSize = 13.sp, color = HopaColor.Danger)
            }
        }
    }
}
