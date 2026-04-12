package com.meetingassistant.ui.screens

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import com.meetingassistant.ui.theme.*
import com.meetingassistant.viewmodel.*
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SessionScreen(nav: NavController, vm: SessionViewModel = viewModel()) {
    val state by vm.uiState.collectAsState()
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (!granted) vm.stopSession()
    }

    LaunchedEffect(Unit) {
        permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(state.scenario.emoji)
                        Text(state.scenario.displayName, fontWeight = FontWeight.SemiBold)
                        AudioLevelIndicator(state.audioLevel, state.isRecording)
                    }
                },
                actions = {
                    if (state.isRecording) {
                        // Save to Obsidian
                        IconButton(onClick = { vm.saveToObsidian() }, enabled = !state.isSavingToObsidian) {
                            if (state.isSavingToObsidian)
                                CircularProgressIndicator(Modifier.size(20.dp), color = AccentCyan, strokeWidth = 2.dp)
                            else
                                Icon(Icons.Default.Save, contentDescription = "Save to Obsidian", tint = AccentCyan)
                        }
                        // Stop
                        IconButton(onClick = { vm.stopSession(); nav.popBackStack() }) {
                            Icon(Icons.Default.StopCircle, contentDescription = "Stop", tint = AccentRed)
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = DarkSurface)
            )
        },
        containerColor = DarkBackground
    ) { padding ->
        Column(Modifier.padding(padding).fillMaxSize()) {
            // Error banner
            state.error?.let { error ->
                Surface(color = AccentRed.copy(alpha = 0.15f), modifier = Modifier.fillMaxWidth()) {
                    Text(error, modifier = Modifier.padding(12.dp), color = AccentRed, fontSize = 12.sp)
                }
            }

            // Obsidian save result
            state.obsidianSaveResult?.let { result ->
                Surface(
                    color = if (result.startsWith("✓")) AccentGreen.copy(alpha = 0.15f) else AccentYellow.copy(alpha = 0.15f),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        Modifier.padding(12.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(result, color = if (result.startsWith("✓")) AccentGreen else AccentYellow,
                            fontSize = 12.sp, modifier = Modifier.weight(1f))
                        IconButton(onClick = { vm.dismissObsidianResult() }, modifier = Modifier.size(24.dp)) {
                            Icon(Icons.Default.Close, contentDescription = null, modifier = Modifier.size(16.dp))
                        }
                    }
                }
            }

            // Tab row
            val tabs = SessionTab.entries
            TabRow(
                selectedTabIndex = tabs.indexOf(state.selectedTab),
                containerColor = DarkSurface,
                contentColor = AccentCyan
            ) {
                tabs.forEach { tab ->
                    Tab(
                        selected = state.selectedTab == tab,
                        onClick = { vm.selectTab(tab) },
                        text = {
                            Text(tab.name.lowercase().replaceFirstChar { it.uppercase() },
                                fontSize = 12.sp, fontWeight = FontWeight.Medium)
                        }
                    )
                }
            }

            // Panel content
            when (state.selectedTab) {
                SessionTab.ANSWERS    -> AnswerPanel(state.answerEntries)
                SessionTab.TERMS      -> TermsPanel(state.wordEntries)
                SessionTab.QUESTIONS  -> QuestionsPanel(state.questions, onRefresh = { vm.generateQuestions() }, state.isRecording)
                SessionTab.TRANSCRIPT -> TranscriptPanel(state.transcript)
            }
        }
    }
}

// ─── Panels ──────────────────────────────────────────────────────────────────

@Composable
private fun AnswerPanel(entries: List<AnswerEntry>) {
    if (entries.isEmpty()) {
        EmptyHint("When someone asks a question, answers appear here automatically")
        return
    }
    LazyColumn(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        items(entries.take(3)) { entry ->
            AiCard {
                Text("Q: ${entry.question}", fontSize = 11.sp, color = AccentYellow, lineHeight = 15.sp)
                Spacer(Modifier.height(6.dp))
                StreamingText(entry.answer.ifBlank { "Thinking…" }, entry.isStreaming)
                CopyButton(entry.answer)
            }
        }
    }
}

@Composable
private fun TermsPanel(entries: List<WordEntry>) {
    if (entries.isEmpty()) {
        EmptyHint("Technical terms will be researched automatically during the conversation")
        return
    }
    LazyColumn(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        items(entries.take(10)) { entry ->
            AiCard {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(entry.term, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = AccentCyan)
                    CopyButton("${entry.term}: ${entry.definition}")
                }
                Spacer(Modifier.height(4.dp))
                StreamingText(entry.definition.ifBlank { "Researching…" }, entry.isStreaming)
            }
        }
    }
}

@Composable
private fun QuestionsPanel(suggestions: List<QuestionSuggestion>, onRefresh: () -> Unit, isRecording: Boolean) {
    Column(Modifier.padding(12.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
            Text("Suggested Questions", style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant)
            IconButton(onClick = onRefresh, enabled = isRecording) {
                Icon(Icons.Default.Refresh, contentDescription = "Refresh", tint = if (isRecording) AccentCyan else Color.Gray, modifier = Modifier.size(18.dp))
            }
        }
        if (suggestions.isEmpty()) {
            EmptyHint("Questions suggested after ~30s of conversation. Tap ↺ to generate now.")
        } else {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(suggestions) { q ->
                    val clipboard = LocalClipboardManager.current
                    AiCard {
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.Top) {
                            Text(q.text, fontSize = 13.sp,
                                color = if (q.isCopied) Color.White.copy(alpha = 0.4f) else Color.White,
                                modifier = Modifier.weight(1f))
                            IconButton(onClick = {
                                clipboard.setText(AnnotatedString(q.text))
                            }, modifier = Modifier.size(32.dp)) {
                                Icon(
                                    if (q.isCopied) Icons.Default.Check else Icons.Default.ContentCopy,
                                    contentDescription = null,
                                    modifier = Modifier.size(16.dp),
                                    tint = if (q.isCopied) AccentGreen else Color.White.copy(0.5f)
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun TranscriptPanel(transcript: List<String>) {
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()

    LaunchedEffect(transcript.size) {
        if (transcript.isNotEmpty()) scope.launch { listState.animateScrollToItem(transcript.size - 1) }
    }

    if (transcript.isEmpty()) {
        EmptyHint("Live transcript will appear here once recording starts")
        return
    }

    LazyColumn(state = listState, modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
        items(transcript) { line ->
            Text(line, fontSize = 12.sp, color = Color.White.copy(alpha = 0.85f), lineHeight = 17.sp)
        }
    }
}

// ─── Components ──────────────────────────────────────────────────────────────

@Composable
private fun AiCard(content: @Composable ColumnScope.() -> Unit) {
    Surface(
        color = DarkCard,
        shape = MaterialTheme.shapes.small,
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(Modifier.padding(12.dp), content = content)
    }
}

@Composable
private fun StreamingText(text: String, isStreaming: Boolean) {
    val cursor by produceState(initialValue = true) {
        while (true) {
            kotlinx.coroutines.delay(500)
            value = !value
        }
    }
    Text(
        text = if (isStreaming) "$text${if (cursor) "▋" else " "}" else text,
        fontSize = 13.sp,
        color = Color.White.copy(alpha = 0.9f),
        lineHeight = 18.sp
    )
}

@Composable
private fun CopyButton(text: String) {
    val clipboard = LocalClipboardManager.current
    var copied by remember { mutableStateOf(false) }
    IconButton(onClick = {
        clipboard.setText(AnnotatedString(text))
        copied = true
    }, modifier = Modifier.size(28.dp)) {
        Icon(
            if (copied) Icons.Default.Check else Icons.Default.ContentCopy,
            contentDescription = "Copy",
            modifier = Modifier.size(14.dp),
            tint = if (copied) AccentGreen else Color.White.copy(0.4f)
        )
    }
}

@Composable
private fun AudioLevelIndicator(level: Float, active: Boolean) {
    if (!active) return
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
        repeat(5) { i ->
            val threshold = (i + 1) / 5f
            Box(
                Modifier
                    .width(3.dp)
                    .height((8 + i * 3).dp)
                    .background(
                        if (level >= threshold) AccentGreen else Color.White.copy(0.15f),
                        MaterialTheme.shapes.extraSmall
                    )
            )
        }
    }
}

@Composable
private fun EmptyHint(text: String) {
    Box(Modifier.fillMaxWidth().padding(32.dp), contentAlignment = Alignment.Center) {
        Text(text, color = Color.White.copy(0.35f), fontSize = 12.sp, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
    }
}
