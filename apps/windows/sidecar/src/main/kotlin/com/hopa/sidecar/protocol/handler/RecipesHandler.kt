package com.hopa.sidecar.protocol.handler

import com.hopa.agent.recipe.RecipeStore
import com.hopa.sidecar.protocol.Protocol
import com.hopa.sidecar.protocol.Protocol.text
import com.hopa.sidecar.protocol.Stdio
import kotlinx.serialization.json.JsonObject

/** The saved repetitions: the goal, the app and whether a replay is safe. */
internal class RecipesHandler(
    private val io: Stdio,
    private val recipes: RecipeStore,
) : MessageHandler {
    override fun handle(type: String, message: JsonObject): Boolean {
        if (!type.startsWith("recipes.")) {
            return false
        }
        val id = message.text("id")
        when (type) {
            "recipes.list" -> list(id)
            "recipes.delete" -> {
                val goal = message.text("goal").trim()
                if (goal.isEmpty()) {
                    io.send(Protocol.dataError(id, "recipes", "E_SCHEMA", "recipes.delete needs a goal"))
                } else {
                    recipes.delete(goal)
                    list(id)
                }
            }

            "recipes.clear" -> {
                recipes.clear()
                list(id)
            }

            else -> io.send(Protocol.dataError(id, "recipes", "E_UNSUPPORTED", "unknown recipes command $type"))
        }
        return true
    }

    private fun list(id: String) {
        io.send(Protocol.recipeList(id, recipes.all()))
    }
}
