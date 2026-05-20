package com.game.mergemogul

import org.godotengine.godot.GodotApplication

class GodotApp : GodotApplication() {
    override fun getGodotGameClassName(): String = "com.game.mergemogul.GodotGame"
}