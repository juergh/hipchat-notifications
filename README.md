hipchat-notifications
=====================

A simple Pidgin plugin for personalized HipChat room notifications.

All it does is look for messages that contain '@all' or '@\<your alias\>' and,
when it finds one:
  - highlight the message (color it green)
  - update the conversation title to show the number of unread messages
  - bark to get your attention.

To install the plugin, copy it to ~/.purple/plugins and enable it in
Pidgin's plugin dialog.
