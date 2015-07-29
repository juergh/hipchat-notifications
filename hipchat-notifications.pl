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
        "/visual-alias-background-color", "Highlight Color");
    $ppref->set_type(2);
    $ppref->set_max_length(7);
    $frame->add($ppref);

    $ppref = Purple::PluginPref->new_with_name_and_label($PLUGIN_PREFS .
        "/visual-alias-font-color", "Color");
    $ppref->set_type(2);
    $ppref->set_max_length(7);
    $frame->add($ppref);

    $ppref = Purple::PluginPref->new_with_name_and_label($PLUGIN_PREFS .
        "/visual-alias-bold", "Bold \@<alias> messages");
    $frame->add($ppref);

    $ppref = Purple::PluginPref->new_with_name_and_label($PLUGIN_PREFS .
        "/visual-all", "Color \@all messages");
    $frame->add($ppref);

    $ppref = Purple::PluginPref->new_with_name_and_label($PLUGIN_PREFS .
        "/visual-all-background-color", "Highlight Color");
    $ppref->set_type(2);
    $ppref->set_max_length(7);
    $frame->add($ppref);

    $ppref = Purple::PluginPref->new_with_name_and_label($PLUGIN_PREFS .
        "/visual-all-font-color", "Color");
    $ppref->set_type(2);
    $ppref->set_max_length(7);
    $frame->add($ppref);

    $ppref = Purple::PluginPref->new_with_name_and_label($PLUGIN_PREFS .
        "/visual-all-bold", "Bold \@all messages");
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

sub decorate_message {
    my ($message, $highlight, $settings_prefix) = @_;
    my $replace = $highlight;
    my $color = 0;
    my $bgcolor = 0;
    my $bold = 0;
    my @attrs;

    $bgcolor = Purple::Prefs::get_string(
        $PLUGIN_PREFS . $settings_prefix . "-background-color");
    $color = Purple::Prefs::get_string(
        $PLUGIN_PREFS . $settings_prefix . "-font-color");
    $bold = Purple::Prefs::get_bool(
        $PLUGIN_PREFS . $settings_prefix . "-bold");

    if ($bold) {
	$replace = "<b>" . $replace . "</b>";
    }
    if ($color) {
	push(@attrs, "color=\"" . $color . "\"");
    }
    if ($bgcolor) {
	push(@attrs, "back=\"" . $bgcolor . "\"");
    }
    $replace = "<font " . join(' ', @attrs) . ">" . $replace . "</font>";

    if ($replace ne $highlight) {

        my $pos = index($message, $highlight);
        if ($pos > -1) {
            substr( $message, $pos, length( $highlight ), $replace );
        } else {
            Purple::Debug::error(
                $PLUGIN_NAME, "Failed to find '$replace' in '$message'");
        }
    }

    return $message
}

sub writing_chat_msg_cb {
    my ($account, $sender, $message, $conv, $flags, $plugin) = @_;
    my $name = $conv->get_name();
    my $sound = 0;
    my $count = 0;

    if ( !($flags & Purple::Conversation::Flags::NICK) ||
        Purple::Conversation::get_type($conv) != Purple::Conversation::Type::CHAT ) {
        return false;
    }

    # ignore if not a HipChat account
    if (!($account->get_username() =~ m|(?<=[\.@])hipchat\..*/xmpp$|)) {
        return false;
    }

    # Check if the message was sent to all
    if (check_notify($message, "\@all")) {
        if (Purple::Prefs::get_bool($PLUGIN_PREFS . "/visual-all")) {
            $message = decorate_message($message, "\@all", "/visual-all");
        }

        if (Purple::Prefs::get_bool($PLUGIN_PREFS . "/audible-all")) {
            $sound = Purple::Prefs::get_string($PLUGIN_PREFS .
                                               "/audible-all-sound");
        }
        $count = 1;
    }

    $current_status = Purple::Account::get_active_status($account);
    $status = Purple::StatusType::get_primitive(Purple::Status::get_type($current_status));
    # Check if the message was sent to here
    if (check_notify($message, "\@here") && $status == Purple::Status::Primitive::AVAILABLE) {
        if (Purple::Prefs::get_bool($PLUGIN_PREFS . "/visual-all")) {
            $message = decorate_message($message, "\@here", "/visual-all");
        }

        if (Purple::Prefs::get_bool($PLUGIN_PREFS . "/audible-all")) {
            $sound = Purple::Prefs::get_string($PLUGIN_PREFS .
                                               "/audible-all-sound");
        }
        $count = 1;
    }

    # Check if the message was sent to me
    $alias = "\@" . $account->get_alias() =~ s/\s//gr;
    if (check_notify($message, $alias)) {
        if (Purple::Prefs::get_bool($PLUGIN_PREFS . "/visual-alias")) {
            $message = decorate_message($message, $alias, "/visual-alias");
        }

        if (Purple::Prefs::get_bool($PLUGIN_PREFS . "/audible-alias")) {
            $sound = Purple::Prefs::get_string($PLUGIN_PREFS .
                                               "/audible-alias-sound");
        }
        $count = 1;
    }

    # Update the conversation title and play a sound if notifications are
    # enabled and the conversation doesn't have the focus
    if ($CONV_NOTIFY{$name} && !$conv->has_focus()) {

	# Play a sound
	if ($sound) {
	    system("/usr/bin/canberra-gtk-play -l 1 -V 10.0 -f " . $sound .
		   " &");
	}
    }

    @_[2] = $message;
    return false;
}

sub check_notify {
    my ($message, $signature) = @_;

    my $quoted = quotemeta($signature);
    if ($message =~ /(?:^|\s)$quoted(?:$|\s)/) {
        Purple::Debug::info($PLUGIN_NAME, "message for " . $quoted .
                            " received\n");
        return 1;
    }

    return 0;
}

sub receiving_chat_msg_cb {
    my ($account, $sender, $message, $conv, $flags, $plugin) = @_;

    my $name = $conv->get_name();
    my @always_notify = (
        "\@all", # Check if the message was sent to all
        "\@" . $account->get_alias() =~ s/\s//gr # to your alias
    );
    my @available_notify = (
        "\@here" # or only if you are not away
    );
    my $count = 0;

    if ( $flags & Purple::Conversation::Flags::NICK ) {
        # flag already set for persons nick having been said, so
        # return immediately
        return false;
    }

    # ignore if not a HipChat account
    if (!($account->get_username() =~ m|(?<=[\.@])hipchat\..*/xmpp$|)) {
        return false;
    }

    foreach(@always_notify) {
        if (check_notify($message, $_)) {
            $flags |= Purple::Conversation::Flags::NICK;
            $count = 1;
        }
    }

    $current_status = Purple::Account::get_active_status($account);
    $status = Purple::StatusType::get_primitive(Purple::Status::get_type($current_status));
    if ($status == Purple::Status::Primitive::AVAILABLE) {
        foreach(@available_notify) {
            if (check_notify($message, $_)) {
                $flags |= Purple::Conversation::Flags::NICK;
                $count = 1;
            }
        }
    }

    if ($CONV_NOTIFY{$name} && !$conv->has_focus()) {

	# Update the conversation title and count
	if ($count) {
	    $CONV_COUNT{$name}++;
	    $conv->set_title("(" . $CONV_COUNT{$name}.") " .
			     $CONV_TITLE{$name});
	}
    }

    @_[4] = $flags;
    return false;
}

sub plugin_load {
    my ($plugin) = @_;
    my ($conv_handle);

    Purple::Debug::info($PLUGIN_NAME, "plugin_load()\n");

    # Initialize the preferences
    Purple::Prefs::add_none($PLUGIN_PREFS);

    Purple::Prefs::add_bool($PLUGIN_PREFS . "/visual-alias", 1);
    Purple::Prefs::add_string($PLUGIN_PREFS . "/visual-alias-background-color", "#E0FFFF");
    Purple::Prefs::add_string($PLUGIN_PREFS . "/visual-alias-font-color", "#c00000");
    Purple::Prefs::add_bool($PLUGIN_PREFS . "/visual-alias-bold", 1);

    Purple::Prefs::add_bool($PLUGIN_PREFS . "/visual-all", 1);
    Purple::Prefs::add_string($PLUGIN_PREFS . "/visual-all-background-color", "#E0FFFF");
    Purple::Prefs::add_string($PLUGIN_PREFS . "/visual-all-font-color", "#008000");
    Purple::Prefs::add_bool($PLUGIN_PREFS . "/visual-all-bold", 1);

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
    Purple::Signal::connect($conv_handle, "writing-chat-msg", $plugin,
                            \&writing_chat_msg_cb, 0);
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

