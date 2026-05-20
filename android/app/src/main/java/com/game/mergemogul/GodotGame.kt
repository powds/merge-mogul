package com.game.mergemogul

import org.godotengine.godot.Godot

class GodotGame : Godot() {
    override fun getPlatform_config(): String = "Android"
}