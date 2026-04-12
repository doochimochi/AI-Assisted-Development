package com.meetingassistant

import android.app.Application
import com.meetingassistant.memory.SessionDatabase

class MeetingAssistantApp : Application() {
    val database: SessionDatabase by lazy { SessionDatabase.create(this) }
}
