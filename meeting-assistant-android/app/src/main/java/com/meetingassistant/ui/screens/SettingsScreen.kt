package com.meetingassistant.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.*
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import com.meetingassistant.ui.theme.*
import com.meetingassistant.viewmodel.SettingsStore
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(nav: NavController) {
    val context = LocalContext.current
    val store = remember { SettingsStore(context) }
    val scope = rememberCoroutineScope()

    var anthropicKey by remember { mutableStateOf("") }
    var deepgramKey  by remember { mutableStateOf("") }
    var obsidianUrl  by remember { mutableStateOf("") }
    var obsidianKey  by remember { mutableStateOf("") }
    var vaultFolder  by remember { mutableStateOf("Meetings") }
    var saved        by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        anthropicKey = store.anthropicApiKey.first()
        deepgramKey  = store.deepgramApiKey.first()
        obsidianUrl  = store.obsidianApiUrl.first()
        obsidianKey  = store.obsidianApiKey.first()
        vaultFolder  = store.obsidianVaultFolder.first()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Settings", fontWeight = FontWeight.SemiBold) },
                navigationIcon = {
                    IconButton(onClick = { nav.popBackStack() }) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
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
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            SectionHeader("AI APIs")

            SecretField("Anthropic API Key", "sk-ant-...", anthropicKey) { anthropicKey = it }
            SecretField("Deepgram API Key", "...", deepgramKey) { deepgramKey = it }

            Divider(color = DarkCard)
            SectionHeader("Obsidian Sync")

            HelpText("1. Install 'Local REST API' plugin in Obsidian on your Mac\n2. Enable the plugin → Settings → Local REST API → note the port (default 27123)\n3. Find your Mac's IP: System Settings → Wi-Fi → Details\n4. Enter: http://192.168.x.x:27123")

            PlainField("Obsidian API URL", "http://192.168.1.x:27123", obsidianUrl) { obsidianUrl = it }
            SecretField("Obsidian API Key", "From plugin settings", obsidianKey) { obsidianKey = it }
            PlainField("Vault Folder", "Meetings", vaultFolder) { vaultFolder = it }

            Spacer(Modifier.height(8.dp))

            Button(
                onClick = {
                    scope.launch {
                        store.save(anthropicKey, deepgramKey, obsidianUrl, obsidianKey, vaultFolder)
                        saved = true
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = AccentCyan)
            ) {
                Text(if (saved) "✓ Saved" else "Save Settings",
                    color = DarkBackground, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

@Composable
private fun SectionHeader(text: String) {
    Text(text, style = MaterialTheme.typography.labelLarge,
        color = AccentCyan, fontWeight = FontWeight.SemiBold)
}

@Composable
private fun HelpText(text: String) {
    Surface(color = DarkCard, shape = MaterialTheme.shapes.small) {
        Text(text, modifier = Modifier.padding(10.dp), fontSize = 11.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant, lineHeight = 16.sp)
    }
}

@Composable
private fun SecretField(label: String, placeholder: String, value: String, onValueChange: (String) -> Unit) {
    var visible by remember { mutableStateOf(false) }
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label, fontSize = 12.sp) },
        placeholder = { Text(placeholder, fontSize = 12.sp) },
        modifier = Modifier.fillMaxWidth(),
        visualTransformation = if (visible) VisualTransformation.None else PasswordVisualTransformation(),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
        trailingIcon = {
            IconButton(onClick = { visible = !visible }) {
                Icon(if (visible) Icons.Default.VisibilityOff else Icons.Default.Visibility, null)
            }
        },
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = AccentCyan,
            unfocusedBorderColor = DarkCard
        )
    )
}

@Composable
private fun PlainField(label: String, placeholder: String, value: String, onValueChange: (String) -> Unit) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label, fontSize = 12.sp) },
        placeholder = { Text(placeholder, fontSize = 12.sp) },
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = AccentCyan,
            unfocusedBorderColor = DarkCard
        )
    )
}
