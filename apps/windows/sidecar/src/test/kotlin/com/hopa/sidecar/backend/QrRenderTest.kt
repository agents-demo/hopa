package com.hopa.sidecar.backend

import com.google.zxing.BarcodeFormat
import com.google.zxing.BinaryBitmap
import com.google.zxing.DecodeHintType
import com.google.zxing.MultiFormatReader
import com.google.zxing.RGBLuminanceSource
import com.google.zxing.common.HybridBinarizer
import java.nio.file.Files
import java.nio.file.attribute.PosixFilePermissions
import javax.imageio.ImageIO
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class QrRenderTest {
    private val text = "hopa://pair?v=1&s=secret-1&u=wss://example.test/v1/gateway"

    @Test
    fun `the png decodes back to the exact text`() {
        val path = Files.createTempDirectory("hopa-qr").resolve("pair-qr.png")
        QrRender.writePng(QrRender.matrix(text), path)

        val image = ImageIO.read(path.toFile())
        val pixels = IntArray(image.width * image.height)
        image.getRGB(0, 0, image.width, image.height, pixels, 0, image.width)
        val bitmap = BinaryBitmap(HybridBinarizer(RGBLuminanceSource(image.width, image.height, pixels)))
        val reader = MultiFormatReader().apply {
            setHints(mapOf(DecodeHintType.POSSIBLE_FORMATS to listOf(BarcodeFormat.QR_CODE)))
        }
        assertEquals(text, reader.decode(bitmap).text)
    }

    @Test
    fun `the png is owner-only where posix permissions exist`() {
        val path = Files.createTempDirectory("hopa-qr-mode").resolve("pair-qr.png")
        QrRender.writePng(QrRender.matrix(text), path)

        if (Files.getFileStore(path).supportsFileAttributeView("posix")) {
            assertEquals("rw-------", PosixFilePermissions.toString(Files.getPosixFilePermissions(path)))
        }
    }
}
