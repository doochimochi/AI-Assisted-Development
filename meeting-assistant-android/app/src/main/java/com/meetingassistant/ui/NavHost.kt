package com.meetingassistant.ui

import androidx.compose.runtime.Composable
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.meetingassistant.ui.screens.HomeScreen
import com.meetingassistant.ui.screens.SessionScreen
import com.meetingassistant.ui.screens.SettingsScreen

@Composable
fun MeetingAssistantNavHost() {
    val nav = rememberNavController()
    NavHost(navController = nav, startDestination = "home") {
        composable("home")     { HomeScreen(nav) }
        composable("session")  { SessionScreen(nav) }
        composable("settings") { SettingsScreen(nav) }
    }
}
