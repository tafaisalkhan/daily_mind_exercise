package com.godot.game;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public final class DailyReminderReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent == null ? null : intent.getAction();
        if (DailyReminder.ACTION_REMIND.equals(action)) {
            DailyReminder.remindAndScheduleNext(context);
        } else if (Intent.ACTION_BOOT_COMPLETED.equals(action)
                || Intent.ACTION_MY_PACKAGE_REPLACED.equals(action)
                || Intent.ACTION_TIME_CHANGED.equals(action)
                || Intent.ACTION_TIMEZONE_CHANGED.equals(action)) {
            DailyReminder.scheduleIfEnabled(context);
        }
    }
}
