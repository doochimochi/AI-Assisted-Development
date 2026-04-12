package com.meetingassistant

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.meetingassistant.ui.MeetingAssistantNavHost
import com.meetingassistant.ui.theme.MeetingAssistantTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MeetingAssistantTheme {
                MeetingAssistantNavHost()
            }
        }
    }
}
