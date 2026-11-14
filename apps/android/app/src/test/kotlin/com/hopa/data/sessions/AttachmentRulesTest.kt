package com.hopa.data.sessions

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AttachmentRulesTest {
    @Test
    fun one_attachment_is_capped_at_four_mebibytes() {
        assertEquals(4L * 1024 * 1024, AttachmentRules.MAX_BYTES)
    }

    @Test
    fun only_image_types_get_a_thumbnail() {
        assertTrue(AttachmentRules.isImage("image/png"))
        assertTrue(AttachmentRules.isImage("image/jpeg"))
        assertFalse(AttachmentRules.isImage("application/pdf"))
    }

    @Test
    fun a_captionless_message_says_what_was_shared() {
        val image = Attachment("cat.png", "image/png", 1024, "/tmp/cat.png")
        val file = Attachment("lease.pdf", "application/pdf", 2048, "/tmp/lease.pdf")

        assertEquals("Shared an image: cat.png", AttachmentRules.describe(image))
        assertEquals("Shared a file: lease.pdf", AttachmentRules.describe(file))
    }

    @Test
    fun sizes_are_short_and_rounded() {
        assertEquals("512 B", AttachmentRules.humanSize(512))
        assertEquals("2 KB", AttachmentRules.humanSize(2048))
        assertEquals("1.5 MB", AttachmentRules.humanSize(1_572_864))
    }
}
