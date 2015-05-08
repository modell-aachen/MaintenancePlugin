# See bottom of file for default license and copyright information

package Foswiki::Plugins::MaintenancePlugin;

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Plugins ();

our $VERSION = '0.1';
our $RELEASE = "0.1";
our $SHORTDESCRIPTION = 'Q.wiki maintenance plugin';
our $NO_PREFS_IN_TOPIC = 1;

# priorities for check results
use constant CRITICAL => 0;
use constant ERROR => 1;
use constant WARN => 2;


my $checks = {
    "general: kvp talk" => {
        name => "KVP Talk Suffix",
        description => "Check if KVPPlugin suffix is \"Talk\"",
        check => sub {
            my $result = { result => 0 };
            if ( ( exists $Foswiki::cfg{Plugins}{KVPPlugin}{Enabled} ) and ( $Foswiki::cfg{Plugins}{KVPPlugin}{Enabled} ) ) {
                if ( $Foswiki::cfg{Extensions}{KVPPlugin}{suffix} ne 'TALK' ) {
                    $result->{result} = 1;
                    $result->{priority} = WARN;
                    $result->{solution} = 'Change setting {Extensions}{KVPPlugin}{suffix} to \'TALK\' and migrate existing topics using the current suffix, which is ' . $Foswiki::cfg{Extensions}{KVPPlugin}{suffix};
                }
            }
            return $result;
        }
    },
    "general: ldap refresh" => {
        name => "LDAP refresh enabled",
        description => "Check if a cronjob with refreshldap=on exists",
        check => sub {
            my $result = { result => 0 };
            if ( $Foswiki::cfg{LoginManager} =~ /(Ldap)|(Switchable)|(Kerberos)/ ) {
                    # Read crontab for webserver user
                    my $ct = qx(crontab -l);
                    unless ( $ct =~ /refreshldap=on/ ) {
                        $result->{result} = 1;
                        $result->{priority} = ERROR;
                        my ( $name, @rest ) = getpwuid( $< );
                        $result->{solution} = "Add refreshldap cronjob to to crontab for user \"$name\" as described in documentation";
                    }
            }
            return $result;
        }
    },
    "general: contextmenu skin" => {
        name => "SKIN preference has \"contextmenu\"",
        description => "Check if modaccontextmenu enabled in SKIN preference",
        check => sub {
            my $result = { result => 0 };
            if ( ( exists $Foswiki::cfg{Plugins}{ModacContextMenuPlugin}{Enabled} ) and ( $Foswiki::cfg{Plugins}{ModacContextMenuPlugin}{Enabled} ) ) {
                    unless ( Foswiki::Func::getPreferencesValue('SKIN') =~ /contextmenu/ ) {
                        $result->{result} = 1;
                        $result->{priority} = ERROR;
                        $result->{solution} = "Add contextmenu to SKIN in [[Main.SitePreferences]]";
                    }
            }
            return $result;
        }
    },
    "general: replaceifeditedagainwithin" => {
        name => "ReplaceIfEditedAgainWithin set correctly",
        description => "{ReplaceIfEditedAgainWithin} set to 0",
        check => sub {
            my $result = { result => 0 };
            if ( ( exists $Foswiki::cfg{ReplaceIfEditedAgainWithin} ) and ( $Foswiki::cfg{ReplaceIfEditedAgainWithin} != 0 ) ) {
                $result->{result} = 1;
                $result->{priority} = WARN;
                $result->{solution} = "Set {ReplaceIfEditedAgainWithin} to 0";
            }
            return $result;
        }
    },
    "general: actiontrackersiteprefs" => {
        name => "Actiontracker site preferences",
        description => "ACTIONTRACKERPLUGIN_UPDATEAJAX set in SitePreferences",
        check => sub {
            my $result = { result => 0 };
            if ( ( exists $Foswiki::cfg{Plugins}{ActionTrackerPlugin}{Enabled} ) and ( $Foswiki::cfg{Plugins}{ActionTrackerPlugin}{Enabled} ) ) {
                my ( $spmeta, $sp ) = Foswiki::Func::readTopic( 'Main', 'SitePreferences');
                if ( $spmeta->getPreference( "ACTIONTRACKERPLUGIN_UPDATEAJAX" ) ne '1' ) {
                    $result->{result} = 1;
                    $result->{priority} = ERROR;
                    $result->{solution} = "Add '   * Set ACTIONTRACKERPLUGIN_UPDATEAJAX = 1' to [[Main.SitePreferences]].";
                }
            }
            return $result;
        }
    }
};

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    Foswiki::Func::registerTagHandler( 'MP_LIST', \&tagList );
    Foswiki::Func::registerTagHandler( 'MP_CHECK', \&tagCheck );

    # Plugin correctly initialized
    return 1;
}

sub registerCheck {
    my ( $name, $newcheck, @bad ) = @_;
    if ( @bad ) {
        Foswiki::Func::writeWarning( "Wrong number of arguments in " . (caller(0))[3] );
        return 0;
    }
    if ( exists $checks->{ $name } ) {
        Foswiki::Func::writeWarning( "Check with name $name already registered" );
        return 0;
    } else {
        $checks->{ $name } = $newcheck;
        return 1;
    }
}

sub tagList {
    my( $session, $params, $topic, $web, $topicObject ) = @_;
    my $result = "| *Check* | *Description* |\n";
    for my $check ( keys $checks ) {
        $result .= '| ' . $checks->{$check}->{name} . ' | ' . $checks->{$check}->{description}  . " |\n";
    }
    return $result;
}

sub tagCheck {
    my( $session, $params, $topic, $web, $topicObject ) = @_;

    my $result;
    # Allow only for AdminUser
    if ( ( Foswiki::Func::isAnAdmin() ) and ( CGI::param( 'mpcheck' ) ) ) {
        my $problems = 0;
        my $warnings = {};
        for my $check ( keys $checks ) {
            my $res = $checks->{$check}->{check}();
            if ( $res->{result} ) {
                $problems++;
                my $prio =  $res->{priority};
                my ( $COLOR, $ENDCOLOR ) = ( '', '' );
                if ( $prio < ERROR ) { $ENDCOLOR = '%ENDCOLOR%'; }
                if ( $prio == CRITICAL ) { $COLOR = '%RED%'; }
                if ( $prio == ERROR ) { $COLOR = '%ORANGE%'; }
                unless ( exists $warnings->{$prio} ) { $warnings->{$prio} = []; }
                push( @{$warnings->{$prio}}, "| $COLOR$prio$ENDCOLOR | $COLOR" . $checks->{$check}->{name} . "$ENDCOLOR | " .  $checks->{$check}->{description} . ' | ' . $res->{solution} . " |\n" );
            }
        }
        if ( $problems > 0 ) {
            $result = "| *Prio* | *Name* | *Description* | *Solution* |\n";
            for my $prio ( sort keys $warnings ) {
                $result .= join("", @{$warnings->{$prio}});
            }
        } else {
            $result .= " | No problems detected. Everything is awesome ||||\n";
        }
    } else {
        $result = 'MP_CHECK only allowed for admins and in use with mpcheck=1. ';
    }
    return $result;
}

# The function used to handle the %EXAMPLETAG{...}% macro
# You would have one of these for each macro you want to process.
#sub _EXAMPLETAG {
#    my($session, $params, $topic, $web, $topicObject) = @_;
#    # $session  - a reference to the Foswiki session object
#    #             (you probably won't need it, but documented in Foswiki.pm)
#    # $params=  - a reference to a Foswiki::Attrs object containing
#    #             parameters.
#    #             This can be used as a simple hash that maps parameter names
#    #             to values, with _DEFAULT being the name for the default
#    #             (unnamed) parameter.
#    # $topic    - name of the topic in the query
#    # $web      - name of the web in the query
#    # $topicObject - a reference to a Foswiki::Meta object containing the
#    #             topic the macro is being rendered in (new for foswiki 1.1.x)
#    # Return: the result of processing the macro. This will replace the
#    # macro call in the final text.
#
#    # For example, %EXAMPLETAG{'hamburger' sideorder="onions"}%
#    # $params->{_DEFAULT} will be 'hamburger'
#    # $params->{sideorder} will be 'onions'
#}

1;

__END__
Q.wiki maintenance plugin - Modell Aachen GmbH

Author: %$AUTHOR%

Copyright (C) 2015 Modell Aachen GmbH

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
