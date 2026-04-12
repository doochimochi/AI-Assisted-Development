package com.meetingassistant.ui.theme

import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val DarkBackground = Color(0xFF0F1117)
val DarkSurface    = Color(0xFF1A1D27)
val DarkCard       = Color(0xFF21242F)
val AccentCyan     = Color(0xFF00D4FF)
val AccentGreen    = Color(0xFF00E676)
val AccentYellow   = Color(0xFFFFD740)
val AccentRed      = Color(0xFFFF5252)

private val DarkColorScheme = darkColorScheme(
    primary          = AccentCyan,
    onPrimary        = Color.Black,
    secondary        = AccentGreen,
    background       = DarkBackground,
    surface          = DarkSurface,
    surfaceVariant   = DarkCard,
    onBackground     = Color.White,
    onSurface        = Color.White,
    onSurfaceVariant = Color.White.copy(alpha = 0.7f)
)

@Composable
fun MeetingAssistantTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = DarkColorScheme,
        typography = Typography(),
        content = content
    )
}
