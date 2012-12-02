## Remcon - remote control for Irssi & Bitlbee

This script allows you to control Irssi and Bitlbee from some another IM (e.g.
Jabber) account.

### How to use the script:

First of all you will have to choose which account (nick) would you like to use
as an administrator account and set the name as the value for 'remcon_admin'
setting, e.g.:

    /set remcon_admin some_nickname

*Note: The default value for the 'remcon_admin' setting is 'remcon'.*

Then you can start controllig of Irssi simply by entering the following
command:

    /remcon start

If you would like to stop the remote control, just enter:

    /remcon stop

During the first start the script checks, whether the nick name defined in
'remcon_admin' setting exists and if it isn't offline. Otherwise the script
displays the following error message:

    Nick 'some_nickname' wasn't found. Check 'remcon_admin' setting.

If the remote control script starts correctly, the defined account (nick name)
will be receiving redirected messages from the other buddies and also will be
able to use the following commands for controlling the Irssi and Bitlbee:

 - !blist - Returns two lines containing buddy list. The first line (starting
   with symbol '+') contains all nicknames with 'online' status. The second
   line (starting with symbol '-') contains the rest of nicknames, which aren't
   'offline' (i.e. 'away', etc...).

 - !away [msg] - Switches to the 'away' status with the message 'msg. If the
   'msg' is empty, the command will remove the away message and it will switch
   back to the 'online' status.

 - !listen <on|off> - Enables or disables redirecting of messages from the
   root user (usually the answers from Bitlbee). By default the redirection is
   disabled.

   For example if you want to see all pending questions from Bitlbee, enable
   the redirection with command '!listen on' and send the 'qlist' command to
   the root user, i.e.: 'root: qlist'.

 - !awaylog [count] - Returns messages from away-log (it's filled with the
   messages, which weren't been able to be retirected, because the
   'remcon_admin' user had been offline). Value 'count' (it can be 1 - 9)
   specifies the number of messages, which should be returned from the
   away-log. By default it returns 3 messages.

 - !watch-users [user_1] ... [user_n] - Defines a list of watched users. If
   some of the users logs in, the script will inform you about it.

 - !watched-users - Returns a list of watched users.

   *Note: Don't mix up the away-log with the Irssi away.log file.*

 - !help - Returns short help message.

 - nick: message - Sends the message to the user defined by the nickname
   'nick'. Next time, when you would like to send some another message to the
   same user, you don't have to specify the nickname. Just to type the message
   and it will be sent to the last used user. If you would like to remove the
   info about the last used user, just type colon symbol: ':'.

The script can be customized by the settings described in the next section.

### Settings:

 - remcon_admin - Defines the nickname of the user, who will be able to control
   the Irssi and bitlbee. Default value is 'remcon'.

 - remcon_channel - Defines the IRC channel. Default value is '&bitlbee'.

 - remcon_root - Defines the root Bitlbee IRC user. Default value is 'root'.

 - remcon_autoaway_msg - Defines the away message, which is used if the remcon
   admin user is disconnected. If it's empty string, the auto-away
   functionality is disabled. Default value is ''.

 - remcon_detect_attached_screen - If it's enabled, the script will try detect,
   if Irssi runs in GNU Screen and if the Screen session is attached. If yes,
   then the script won't redirect messages to the remcon admin user and also
   the 'remcon_autoaway_msg' will be temporarily disabled. Default value is
   'ON'.

*Note: Settings are loaded after the Remcon is started. So if you would like to
change some setting value(s) while the Remcon is running, you will have to stop
it:*

    /remcon stop

*and then start again:*

    /remcon start

*or simple restart it:*

    /remcon restart

