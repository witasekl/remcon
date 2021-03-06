# Remote control for Irssi and Bitlbee
#
# Copyright 2012 Libor Witasek
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


# Read the README.md file for info, how to use the script.

# The latest version can be downloaded from the project page:
# https://github.com/witasekl/remcon


use strict;
use vars qw($VERSION %IRSSI);

use Irssi;

$VERSION = '0.40';
%IRSSI = (
    authors     => 'Libor Witasek',
    contact     => 'witasekl@gmail.com',
    name        => 'Remote control',
    description => 'This script allows you ' .
                   'to control Bitlbee remotely ' .
                   'from another IM account.',
    license     => 'GNU GPLv3',
);

use constant {
    STATUS_INITIAL => 0,
    STATUS_STARTED => 1,
    STATUS_STOPPED => 2,
};

my $event_privmsg_ref = \&event_privmsg; 
my $nicklist_new_ref = \&nicklist_new;
my $nicklist_remove_ref = \&nicklist_remove;
my $socket = screen_socket_path();
my $status;
my $last_target;
my $listen_root;
my $watched_users;
my $remcon_admin;
my $remcon_channel;
my $remcon_root;
my $remcon_autoaway_msg;
my $remcon_detect_attached_screen;
my @awaylog;

sub screen_socket_path{
    my @screen_ls = `LC_ALL="C" screen -ls`;
    my $screen_ls_length = @screen_ls;
    my $sty = $ENV{'STY'};

    if ($screen_ls_length > 1 and $sty) {
        my $socket = $screen_ls[$screen_ls_length - 2];
        $socket = substr($socket, 0, length($socket) - 1);
        if ($socket =~ s/^.* ([^ .]+)\.*$/\1/) {
            return $socket . "/" . $sty;
        }
    }
    return "";
}

sub is_screen_attached{
    if ($socket) {
        my @screen = stat($socket);
        return (($screen[2] & 00100) != 0);
    }
    return 0;
}

sub only_if_detached_screen {
    if ($remcon_detect_attached_screen) {
        if ($socket) {
            return !is_screen_attached();
        }
        else { # Not running in Screen
            return 1;
        }
    }
    else {
        return 1;
    }
}

sub get_nicklist {
    my ($server) = @_;
    my @online = "+";
    my @away = "-";

    my $channel = $server->channel_find($remcon_channel);
    if ($channel) {
        my @sorted_nicks = sort {lc($a->{'nick'}) cmp lc($b->{'nick'})}
            $channel->nicks();
        foreach my $nick (@sorted_nicks) {
            if (!$nick->{'op'}) {
                if ($nick->{'voice'}) {
                    push(@online, $nick->{'nick'});
                }
                else {
                    push(@away, $nick->{'nick'});
                }
            }
        }
    }

    return (join(" ", @online), join(" ", @away));
}

sub nick_exists {
    my ($server, $nick) = @_;

    my $channel = $server->channel_find($remcon_channel);
    if ($channel) {
        if ($channel->nick_find($nick)) {
            return 1;
        }
    }
    return 0;
}

sub print_list {
    my ($server, $nick, @list) = @_;

    foreach my $line (@list) {
        $server->send_message($nick, $line, 1);
    }
}

sub send_message {
    my ($server, $target, $message) = @_;

    if (!$target) {
        if ($last_target) {
            $target = $last_target;
        }
        else {
            $server->send_message($remcon_admin,
                "You must specify target nick!", 1);
            return;
        }
    }
    else {
        $last_target = $target;
    }
    if (nick_exists($server, $target)) {
        if ($target eq $remcon_root) {
            $server->send_message($remcon_channel, $message, 0);
            if (!$listen_root) {
                $server->send_message($remcon_admin,
                    "Warning: You don't listen, what root says.", 1);
            }
        }
        else {
            $server->command("msg $target $message");
        }
        $server->send_message($remcon_admin, "Message was sent to $target.",
            1);
    }
    else {
        $server->send_message($remcon_admin, "Nick $target doesn't exist.", 1);
    }
}

sub print_help {
    my ($server, $target) = @_;
    my @help = ("Commands: !blist, !away [msg], !listen <on|off>, " .
        "!awaylog [count], !watch-users [nick_1] ... [nick_n], " .
        "!watched-users, !help", "Message sending: [nick:] <msg>");

    print_list($server, $target, @help);
}

sub print_awaylog {
    my ($server, $items) = @_;
    my $awaylog_size = @awaylog;
    my @output = ();
 
    if ($awaylog_size) {
        my $min = ($awaylog_size < $items) ? $awaylog_size : $items;
        for (my $i = 0; $i < $min; $i++) {
            push(@output, pop(@awaylog));
        }
        print_list($server, $remcon_admin, @output);
    }
    else {
        $server->send_message($remcon_admin, "Awaylog is empty.", 1);
    }
}

sub process_control_message {
    my ($server, $nick, $text) = @_;

    if ($text eq "!blist") {
        print_list($server, $nick, get_nicklist($server));
    }
    elsif ($text eq ":") {
        $last_target = "";
    }
    elsif ($text eq "!help") {
        print_help($server, $nick);
    }
    elsif ($text eq "!watched-users") {
        $server->send_message($remcon_admin, "Watched users: " . "$watched_users", 1);
    }
    elsif ($text =~ s/^!away( .*|)$/\1/) {
        $server->command("away$text");
    }
    elsif ($text =~ s/^!listen (on|off)$/\1/) {
        if ($text eq "on") {
            $listen_root = 1;
        }
        else {
            $listen_root = 0;
        }
    }
    elsif ($text =~ s/^!awaylog( [1-9]|)$/\1/) {
        print_awaylog($server, ($text ? $text : 3));
    }
    elsif ($text =~ s/^!watch-users( .*|)$/\1/) {
        $watched_users = $text;
    }
    elsif ($text =~ /^!/) {
        $server->send_message($remcon_admin, "Unknown command: $text.", 1);
    }
    elsif ($text =~ s/^([^ :]+): *(.*)$/\1 \2/) {
        my ($target, $message) = split(" ", $text, 2);
        send_message($server, $target, $message);
    }
    else {
        send_message($server, "", $text);
    }
}

sub process_message {
    my ($server, $nick, $text) = @_;
    my $is_root = ($nick eq $remcon_root);

    if (only_if_detached_screen()) {
        if ($listen_root || !$is_root) {
            if (nick_exists($server, $remcon_admin)) {
                $server->send_message($remcon_admin, "$nick: $text", 1);
            } elsif (!$is_root) {
                unshift(@awaylog, "$nick: $text");
            }
        }
    }
}

sub event_privmsg {
    my ($server, $data, $nick, $address) = @_;
    my ($target, $text) = split(/ :/, $data, 2);

    if ($nick eq $remcon_admin) {
        process_control_message($server, $nick, $text);
        Irssi::signal_stop();
    }
    else {
        process_message($server, $nick, $text);
    }
}

sub nicklist_new {
    my ($channel, $nick) = @_;

    if ($watched_users) {
        my $nickname = $nick->{'nick'};
        if ($watched_users =~ /$nickname/) {
            foreach my $server (Irssi::servers()) {
                if (nick_exists($server, $remcon_admin)) {
                    $server->send_message($remcon_admin, "User '" .
                        $nickname . "' has logged in.", 1);
                }
            }
        }
    }
}

sub nicklist_remove {
    my ($channel, $nick) = @_;

    if ($remcon_autoaway_msg) {
        if ($nick->{'nick'} eq $remcon_admin) {
            if (only_if_detached_screen()) {
                foreach my $server (Irssi::servers()) { 
                    $server->command("away $remcon_autoaway_msg");
                }
            }
        }
    }
}

sub remcon_start {
    my ($data, $server, $channel) = @_;

    $remcon_admin = Irssi::settings_get_str('remcon_admin');
    $remcon_channel = Irssi::settings_get_str('remcon_channel');
    $remcon_root = Irssi::settings_get_str('remcon_root');
    $remcon_autoaway_msg = Irssi::settings_get_str('remcon_autoaway_msg');
    $remcon_detect_attached_screen = Irssi::settings_get_bool('remcon_detect_attached_screen');

    if ($status == STATUS_STARTED) {
        print "Remcon already started!";
    }
    elsif (($status == STATUS_INITIAL) && !nick_exists($server, $remcon_admin))
    {
        print "Nick '" . $remcon_admin .
            "' wasn't found. Check 'remcon_admin' setting.";
    }
    else {
        Irssi::signal_add("event privmsg", $event_privmsg_ref);
        Irssi::signal_add("nicklist new", $nicklist_new_ref);
        Irssi::signal_add("nicklist remove", $nicklist_remove_ref);
        $status = STATUS_STARTED;
        @awaylog = ();
        print "Remcon started successfully.";
    }
}

sub remcon_stop {
    if ($status != STATUS_STARTED) {
        print "Remcon wasn't started yet!";
    }
    else {
        Irssi::signal_remove("event privmsg", $event_privmsg_ref);
        Irssi::signal_remove("nicklist new", $nicklist_new_ref);
        Irssi::signal_remove("nicklist remove", $nicklist_remove_ref);
        $status = STATUS_STOPPED;
        $last_target = "";
        $listen_root = 0;
        $watched_users = "";
        @awaylog = ();
        print "Remcon stopped successfully.";
    }
}

sub remcon_restart {
    my ($data, $server, $channel) = @_;

    remcon_stop($data, $server, $channel);
    remcon_start($data, $server, $channel);
}

Irssi::command_bind 'remcon' => sub {
    my ($data, $server, $item) = @_;
    $data =~ s/\s+$//g;
    Irssi::command_runsub('remcon', $data, $server, $item);
};

Irssi::command_bind('remcon start', \&remcon_start);
Irssi::command_bind('remcon stop', \&remcon_stop);
Irssi::command_bind('remcon restart', \&remcon_restart);

Irssi::settings_add_str('remcon', 'remcon_admin', 'remcon');
Irssi::settings_add_str('remcon', 'remcon_channel', '&bitlbee');
Irssi::settings_add_str('remcon', 'remcon_root', 'root');
Irssi::settings_add_str('remcon', 'remcon_autoaway_msg', '');
Irssi::settings_add_bool('remcon', 'remcon_detect_attached_screen', 1);

