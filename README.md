hipchat-notifications
=====================

A simple Pidgin plugin for personalized HipChat room notifications.

All it does is look for messages that contain '@all', '@here' or
'@\<your alias\>' and, when it finds one:
  - colors the message (only if you are available for '@here')
  - updates the conversation title to show the number of unread messages
  - plays a sound to get your attention.

To install the plugin, copy it to ~/.purple/plugins/ and configure and enable
it in Pidgin's plugin dialog (Tools -> Plugins).
