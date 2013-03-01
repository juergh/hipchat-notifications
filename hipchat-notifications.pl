#!/usr/bin/perl
#
#    Copyright (C) 2013 Juerg Haefliger <juergh@gmail.com>
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License version 3, as
#    published by the Free Software Foundation.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

use Pidgin;
use Purple;

%PLUGIN_INFO = (
    perl_api_version => 2,
    name => "HipChat Notifications",
    version => "0.2.0",
    summary => "Customized notifications for HipChat rooms",
    description => "",
    author => "Juerg Haefliger <juergh\@gmail.com",
    url => "https://github.com/juergh/hipchat-notifications",
    load => "plugin_load",
    unload => "plugin_unload",
    prefs_info => "prefs_info_cb"
);

$PLUGIN_NAME = "hipchat-notifications";
$PLUGIN_PREFS = "/plugins/core/" . $PLUGIN_NAME;

%CONV_TITLE = ();
%CONV_COUNT = ();
%CONV_NOTIFY = ();

sub plugin_init {
    return %PLUGIN_INFO;
}

sub prefs_info_cb {
    my ($frame, $ppref);

    Purple::Debug::info($PLUGIN_NAME, "prefs_info_cb()\n");

    # Initialize the frame
    $frame = Purple::PluginPref::Frame->new();

    # Visual notifications
    $ppref = Purple::PluginPref->new_with_label("Visual Notifications");
    $frame->add($ppref);

    $ppref = Purple::PluginPref->new_with_name_and_label($PLUGIN_PREFS .
        "/visual-alias", "Color \@<alias> messages");
    $frame->add($ppref);

    $ppref = Purple::PluginPref->new_with_name_and_label($PLUGIN_PREFS .
        "/visual-alias-color", "Color");
    $ppref->set_type(2);
    $ppref->set_max_length(7);
    $frame->add($ppref);

    $ppref = Purple::PluginPref->new_with_name_and_label($PLUGIN_PREFS .
        "/visual-all", "Color \@all messages");
    $frame->add($ppref);

    $ppref = Purple::PluginPref->new_with_name_and_label($PLUGIN_PREFS .
        "/visual-all-color", "Color");
    $ppref->set_type(2);
    $ppref->set_max_length(7);
    $frame->add($ppref);

    # Audible notifications
    $ppref = Purple::PluginPref->new_with_label("Audible Notifications");
    $frame->add($ppref);

    $ppref = Purple::PluginPref->new_with_name_and_label($PLUGIN_PREFS .
        "/audible-alias", "Play sound for \@<alias> messages");
    $frame->add($ppref);

    $ppref = Purple::PluginPref->new_with_name_and_label($PLUGIN_PREFS .
        "/audible-alias-sound", "Sound file");
    $ppref->set_type(2);
    $ppref->set_max_length(64);
    $frame->add($ppref);

    $ppref = Purple::PluginPref->new_with_name_and_label($PLUGIN_PREFS .
        "/audible-all", "Play sound for \@all messages");
    $frame->add($ppref);

    $ppref = Purple::PluginPref->new_with_name_and_label($PLUGIN_PREFS .
        "/audible-all-sound", "Sound file");
    $ppref->set_type(2);
    $ppref->set_max_length(64);
    $frame->add($ppref);

    return $frame;
}

sub enable_notifications_cb {
    my ($conv) = @_;
    my $name = $conv->get_name();

    Purple::Debug::info($PLUGIN_NAME, "enable notifications for " . $name .
			"\n");

    $CONV_NOTIFY{$name} = 1;
    return false;
}

sub conversation_switched_cb {
    my ($conv) = @_;
    my $name = $conv->get_name();

    Purple::Debug::info($PLUGIN_NAME, "conversation switched to " . $name .
			"\n");

    # Reset the conversation title and count
    $conv->set_title($CONV_TITLE{$name});
    $CONV_COUNT{$name} = 0;
}

sub conversation_created_cb {
    my ($conv, $plugin) = @_;
    my $name = $conv->get_name();
    my $title = $conv->get_title();

    Purple::Debug::info($PLUGIN_NAME, "conversation " . $name . " (" . $title .
			") created\n");

    # Save the original conversation title and reset the count
    $CONV_TITLE{$name} = $title;
    $CONV_COUNT{$name} = 0;
    $CONV_NOTIFY{$name} = 0;

    # Enable notifications in 5 seconds
    Purple::timeout_add($plugin, 5, \&enable_notifications_cb, $conv);
}

sub receiving_chat_msg_cb {
    my ($account, $sender, $message, $conv, $flags, $plugin) = @_;
    my ($all, $nick, $quoted);
    my $name = $conv->get_name();
    my $color = 0;
    my $sound = 0;
    my $count = 0;

    # Check if this is a HipChat account
    if ($account->get_username() =~ m|chat.hipchat.com/xmpp$|) {

	# Check if the message was sent to all
	$all = "\@all";
	$quoted = quotemeta($all);
	if ($message =~ /(^|\s)$quoted($|\s)/) {
	    Purple::Debug::info($PLUGIN_NAME, "message for " . $quoted .
				" received\n");

	    if (Purple::Prefs::get_bool($PLUGIN_PREFS . "/visual-all")) {
		$color = Purple::Prefs::get_string($PLUGIN_PREFS .
						   "/visual-all-color");
	    }

	    if (Purple::Prefs::get_bool($PLUGIN_PREFS . "/audible-all")) {
		$sound = Purple::Prefs::get_string($PLUGIN_PREFS .
						   "/audible-all-sound");
	    }

	    $count = 1;

	    goto DONE;
	}

	# Check if the message was sent to me
	$alias = "\@" . $account->get_alias();
	$alias =~ s/\s//g;
	$quoted = quotemeta($alias);
	if ($message =~ /(^|\s)$quoted($|\s)/) {
	    Purple::Debug::info($PLUGIN_NAME, "message for " . $quoted .
				" received\n");

	    if (Purple::Prefs::get_bool($PLUGIN_PREFS . "/visual-alias")) {
		$color = Purple::Prefs::get_string($PLUGIN_PREFS .
						   "/visual-alias-color");
	    }

	    if (Purple::Prefs::get_bool($PLUGIN_PREFS . "/audible-alias")) {
		$sound = Purple::Prefs::get_string($PLUGIN_PREFS .
						   "/audible-alias-sound");
	    }

	    $count = 1;

	    goto DONE;
	}
    }

DONE:
    # Color the message
    if ($color) {
	$message = "<font color=" . $color . ">" . $message . "</font>";
    }

    # Update the conversation title and play a sound if notifications are
    # enabled and the conversation doesn't have the focus
    if ($CONV_NOTIFY{$name} && !$conv->has_focus()) {

	# Update the conversation title and count
	if ($count) {
	    $CONV_COUNT{$name}++;
	    $conv->set_title("(" . $CONV_COUNT{$name}.") " .
			     $CONV_TITLE{$name});
	}

	# Play a sound
	if ($sound) {
	    system("/usr/bin/canberra-gtk-play -l 1 -V 10.0 -f " . $sound .
		   " &");
	}
    }

    @_[2] = $message;
    return false;
}

sub plugin_load {
    my ($plugin) = @_;
    my ($conv_handle);

    Purple::Debug::info($PLUGIN_NAME, "plugin_load()\n");

    # Initialize the preferences
    Purple::Prefs::add_none($PLUGIN_PREFS);

    Purple::Prefs::add_bool($PLUGIN_PREFS . "/visual-alias", 1);
    Purple::Prefs::add_string($PLUGIN_PREFS . "/visual-alias-color", "#c00000");

    Purple::Prefs::add_bool($PLUGIN_PREFS . "/visual-all", 1);
    Purple::Prefs::add_string($PLUGIN_PREFS . "/visual-all-color", "#008000");

    Purple::Prefs::add_bool($PLUGIN_PREFS . "/audible-alias", 1);
    Purple::Prefs::add_string($PLUGIN_PREFS . "/audible-alias-sound",
        "/usr/share/sounds/gnome/default/alerts/bark.ogg");

    Purple::Prefs::add_bool($PLUGIN_PREFS . "/audible-all", 1);
    Purple::Prefs::add_string($PLUGIN_PREFS . "/audible-all-sound",
        "/usr/share/sounds/gnome/default/alerts/bark.ogg");

    # Register the Purple callbacks
    $conv_handle = Purple::Conversations::get_handle();
    Purple::Signal::connect($conv_handle, "receiving-chat-msg", $plugin,
			    \&receiving_chat_msg_cb, 0);
    Purple::Signal::connect($conv_handle, "conversation-created", $plugin,
			    \&conversation_created_cb, $plugin);

    # Register the Pidgin callbacks
    $conv_handle = Pidgin::Conversations::get_handle();
    Purple::Signal::connect($conv_handle, "conversation-switched", $plugin,
			    \&conversation_switched_cb, 0);

}

sub plugin_unload {
    my ($plugin) = @_;
    Purple::Debug::info($PLUGIN_NAME, "plugin_unload()\n");
}

