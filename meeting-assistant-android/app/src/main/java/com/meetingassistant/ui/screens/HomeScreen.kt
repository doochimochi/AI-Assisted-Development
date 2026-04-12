package com.meetingassistant.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import com.meetingassistant.memory.SessionEntity
import com.meetingassistant.ui.theme.*
import com.meetingassistant.viewmodel.ScenarioType
import com.meetingassistant.viewmodel.SessionViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(nav: NavController, vm: SessionViewModel = viewModel()) {
    var selectedScenario by remember { mutableStateOf(ScenarioType.TEAM) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Meeting Assistant", fontWeight = FontWeight.SemiBold) },
                actions = {
                    IconButton(onClick = { nav.navigate("settings") }) {
                        Icon(Icons.Default.Settings, contentDescription = "Settings")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = DarkSurface)
            )
        },
        containerColor = DarkBackground
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .padding(16.dp)
                .fillMaxSize()
        ) {
            // Scenario selector
            Text("Select Scenario", style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(Modifier.height(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                ScenarioType.entries.forEach { scenario ->
                    ScenarioChip(
                        scenario = scenario,
                        selected = selectedScenario == scenario,
                        onClick = { selectedScenario = scenario },
                        modifier = Modifier.weight(1f)
                    )
                }
            }

            Spacer(Modifier.height(20.dp))

            // Start button
            Button(
                onClick = {
                    vm.startSession(selectedScenario)
                    nav.navigate("session")
                },
                modifier = Modifier.fillMaxWidth().height(52.dp),
                colors = ButtonDefaults.buttonColors(containerColor = AccentGreen)
            ) {
                Text("Start ${selectedScenario.displayName}", color = DarkBackground,
                    fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
            }

            Spacer(Modifier.height(28.dp))

            // Recent sessions
            Text("Recent Sessions", style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun ScenarioChip(
    scenario: ScenarioType,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val bg = if (selected) AccentCyan else DarkCard
    val textColor = if (selected) DarkBackground else MaterialTheme.colorScheme.onSurfaceVariant
    ElevatedButton(
        onClick = onClick,
        modifier = modifier,
        colors = ButtonDefaults.elevatedButtonColors(containerColor = bg)
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(scenario.emoji, fontSize = 18.sp)
            Text(scenario.displayName, fontSize = 10.sp, color = textColor, fontWeight = FontWeight.Medium)
        }
    }
}
