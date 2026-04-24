package ai.gidar.app.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val GidarOriginalScheme = darkColorScheme(
    primary = GidarPrimary,
    secondary = GidarSecondary,
    background = GidarBackground,
    surface = GidarSurface,
    onPrimary = Color.Black,
    onSecondary = Color.White,
    onBackground = Color.White,
    onSurface = GidarOnSurface,
    surfaceVariant = GidarMessageUser,
    outline = GidarAccent
)

private val DeepOceanScheme = darkColorScheme(
    primary = OceanPrimary,
    secondary = OceanSecondary,
    background = OceanBackground,
    surface = OceanSurface
)

private val MidnightForestScheme = darkColorScheme(
    primary = ForestPrimary,
    secondary = ForestSecondary,
    background = ForestBackground,
    surface = ForestSurface
)

private val SunsetGlowScheme = darkColorScheme(
    primary = SunsetPrimary,
    secondary = SunsetSecondary,
    background = SunsetBackground,
    surface = SunsetSurface
)

private val NeonCyberpunkScheme = darkColorScheme(
    primary = NeonPrimary,
    secondary = NeonSecondary,
    background = NeonBackground,
    surface = NeonSurface
)

private val LavenderMistScheme = darkColorScheme(
    primary = LavenderPrimary,
    secondary = LavenderSecondary,
    background = LavenderBackground,
    surface = LavenderSurface
)

private val PaperInkScheme = lightColorScheme(
    primary = PaperPrimary,
    secondary = PaperSecondary,
    background = PaperBackground,
    surface = PaperSurface
)

enum class GidarTheme {
    ORIGINAL, DEEP_OCEAN, MIDNIGHT_FOREST, SUNSET_GLOW, NEON_CYBERPUNK, LAVENDER_MIST, PAPER_INK
}

@Composable
fun GidarAITheme(
    theme: GidarTheme = GidarTheme.ORIGINAL,
    content: @Composable () -> Unit
) {
    val colorScheme = when (theme) {
        GidarTheme.ORIGINAL -> GidarOriginalScheme
        GidarTheme.DEEP_OCEAN -> DeepOceanScheme
        GidarTheme.MIDNIGHT_FOREST -> MidnightForestScheme
        GidarTheme.SUNSET_GLOW -> SunsetGlowScheme
        GidarTheme.NEON_CYBERPUNK -> NeonCyberpunkScheme
        GidarTheme.LAVENDER_MIST -> LavenderMistScheme
        GidarTheme.PAPER_INK -> PaperInkScheme
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
