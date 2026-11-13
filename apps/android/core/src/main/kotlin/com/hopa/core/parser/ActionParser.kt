package com.hopa.core.parser

import com.hopa.core.contracts.Action

class ActionParser(
    private val decisionParser: DecisionParser = DecisionParser(),
) {
    fun parse(text: String): Action? = decisionParser.parse(text).decision?.action
}
