package com.hopa.core.validation

data class ValidationResult(
    val valid: Boolean,
    val errorCode: String? = null,
    val message: String? = null,
) {
    companion object {
        fun ok(): ValidationResult = ValidationResult(valid = true)

        fun fail(code: String, message: String): ValidationResult =
            ValidationResult(valid = false, errorCode = code, message = message)
    }
}
