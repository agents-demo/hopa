package com.hopa.sidecar.backend

import com.google.zxing.BarcodeFormat
import com.google.zxing.common.BitMatrix
import com.google.zxing.qrcode.QRCodeWriter
import java.awt.image.BufferedImage
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.attribute.PosixFileAttributeView
import java.nio.file.attribute.PosixFilePermissions
import javax.imageio.ImageIO

/**
 * Renders the admission QR twice: as Unicode half-blocks for a terminal and as
 * a PNG a person can scan from another screen. zxing's core module produces the
 * matrix; the PNG goes through the JDK's ImageIO, so no zxing-javase dependency
 * is needed.
 */
object QrRender {
    /** A QR matrix with zxing's default quiet zone; 0 means the minimal size. */
    fun matrix(text: String): BitMatrix =
        QRCodeWriter().encode(text, BarcodeFormat.QR_CODE, 0, 0)

    /**
     * Two matrix rows per terminal row: upper half block, lower half block, both
     * or neither. Wide terminals should keep the default font so cells stay
     * roughly square.
     */
    fun blocks(matrix: BitMatrix): String = buildString {
        var y = 0
        while (y < matrix.height) {
            for (x in 0 until matrix.width) {
                val top = matrix[x, y]
                val bottom = y + 1 < matrix.height && matrix[x, y + 1]
                append(
                    when {
                        top && bottom -> '█'
                        top -> '▀'
                        bottom -> '▄'
                        else -> ' '
                    },
                )
            }
            append('\n')
            y += 2
        }
    }

    /** Writes the matrix as a black-on-white PNG, scaled for screen scanning. */
    fun writePng(matrix: BitMatrix, path: Path, scale: Int = 8) {
        require(scale > 0) { "scale must be positive" }
        val image = BufferedImage(
            matrix.width * scale,
            matrix.height * scale,
            BufferedImage.TYPE_INT_RGB,
        )
        for (y in 0 until image.height) {
            for (x in 0 until image.width) {
                val dark = matrix[x / scale, y / scale]
                image.setRGB(x, y, if (dark) BLACK else WHITE)
            }
        }
        path.parent?.let { Files.createDirectories(it) }
        ImageIO.write(image, "png", path.toFile())
        ownerOnly(path)
    }

    /** The PNG carries the live pairing secret, so keep it to the owner where possible. */
    private fun ownerOnly(path: Path) {
        runCatching {
            Files.getFileAttributeView(path, PosixFileAttributeView::class.java)
                ?.setPermissions(PosixFilePermissions.fromString("rw-------"))
        }
    }

    private const val BLACK = 0x000000
    private const val WHITE = 0xFFFFFF
}
