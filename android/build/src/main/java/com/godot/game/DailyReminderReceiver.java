package com.godot.game;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public final class DailyReminderReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (DailyReminder.ACTION_REMIND.equals(intent.getAction())) {
            DailyReminder.show(context);
        } else {
            DailyReminder.scheduleIfEnabled(context);
        }
    }
}
