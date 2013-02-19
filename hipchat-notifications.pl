#!/usr/bin/perl

use Pidgin;
use Purple;

%PLUGIN_INFO = (
    perl_api_version => 2,
    name => "HipChat Notifications",
    version => "0.1",
    summary => "Customized notifications for HipChat rooms",
    description => "",
    author => "Juerg Haefliger <juergh\@gmail.com",
    url => "",
    load => "plugin_load",
    unload => "plugin_unload"
);

%CONV_TITLE = ();
%CONV_COUNT = ();
%CONV_NOTIFY = ();

sub plugin_init {
    return %PLUGIN_INFO;
}

sub enable_notifications_cb {
    my ($conv) = @_;
    my $name = $conv->get_name();

    Purple::Debug::info("hipchat-notifications", "enable notifications for " .
			$name . "\n");

    $CONV_NOTIFY{$name} = 1;
    return false;
}

sub conversation_switched_cb {
    my ($conv) = @_;
    my $name = $conv->get_name();

    Purple::Debug::info("hipchat-notifications", "conversation switched to " .
			$name . "\n");

    # Reset the conversation title and count
    $conv->set_title($CONV_TITLE{$name});
    $CONV_COUNT{$name} = 0;
}

sub conversation_created_cb {
    my ($conv, $plugin) = @_;
    my $name = $conv->get_name();
    my $title = $conv->get_title();

    Purple::Debug::info("hipchat-notifications", "conversation " . $name .
			" (" . $title . ") created\n");

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
    my $notify = 0;

    # Check if this is a HipChat account
    if ($account->get_username() =~ m|chat.hipchat.com/xmpp$|) {

	# Check if the message was sent to all
	$all = "\@all";
	$quoted = quotemeta($all);
	if ($message =~ /(^|\s)$quoted($|\s)/) {
	    Purple::Debug::info("hipchat-notifications", "message for " .
				$quoted . " received\n");
	    $notify = 1;
	    goto DONE;
	}

	# Check if the message was sent to me
	$alias = "\@" . $account->get_alias();
	$alias =~ s/\s//g;
	$quoted = quotemeta($alias);
	if ($message =~ /(^|\s)$quoted($|\s)/) {
	    Purple::Debug::info("hipchat-notifications", "message for " .
				$quoted . " received\n");
	    $notify = 1;
	    goto DONE;
	}
    }

DONE:
    if ($notify) {
	# Color the message
	$message = "<font color=#007f00>" . $message . "</font>";

	if ($CONV_NOTIFY{$name}) {
	    # Update the conversation title and count
	    $CONV_COUNT{$name}++;
	    $conv->set_title("(" . $CONV_COUNT{$name}.") " .
			     $CONV_TITLE{$name});

	    # Play a sound
	    system("/usr/bin/canberra-gtk-play -l 1 -V 10.0 " .
		   "-f /usr/share/sounds/gnome/default/alerts/bark.ogg &");
	}
    }

    @_[2] = $message;
    return false;
}

sub plugin_load {
    my ($plugin) = @_;
    my ($conv_handle);

    Purple::Debug::info("hipchat-notifications", "plugin_load()\n");
    
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
    Purple::Debug::info("hipchat-notifications", "plugin_unload()\n");
}

