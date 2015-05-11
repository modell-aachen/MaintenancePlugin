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
    },
    "general: customnowysiwyg" => {
        name => "Custom web NOWYSIWYG",
        description => "Custom web has NOWYSIWYG preference",
        check => sub {
            my $result = { result => 0 };
            my $nowysiwyg = Foswiki::Func::getPreferencesValue( "NOWYSIWYG", "Custom" );
            chomp $nowysiwyg;
            if ( $nowysiwyg ne '1' ) {
                $result->{result} = 1;
                $result->{priority} = WARN;
                $result->{solution} = "Add '   * Set NOWYSIWYG = 1' to [[Custom.WebPreferences]].";
            }
            return $result;
        }
    },
    "general: customskins" => {
        name => "Custom web skins",
        description => "Custom web has only CustomSkins",
        check => sub {
            my $result = { result => 0 };
            my @topics = grep(/(?<!^Custom)Skin/,Foswiki::Func::getTopicList( "Custom" ));
            if ( scalar @topics ) {
                $result->{result} = 1;
                $result->{priority} = ERROR;
                $result->{solution} = "Rename/restructure Skins in Custom web. Offending topics: " . join(", ", @topics);
            }
            return $result;
        }
    },
    "general: filepermissions" => {
        name => "File permissions",
        description => "Some files has wrong permissions",
        check => sub {
            my $result = { result => 0 };
            # Core module
            use File::Find;
            my @dirs = ( $Foswiki::cfg{DataDir}, $Foswiki::cfg{PubDir} );
            our $direg = qr(^($Foswiki::cfg{DataDir})|($Foswiki::cfg{PubDir}));
            our @offenders = ();
            our @gcos = getpwuid( $< );
            finddepth( { wanted => \&permissions, untaint => 1, untaint_pattern => /$direg/ }, @dirs );
            # This implements:  find . ! -user www-data -or ! -perm -u+r -or \( -perm -u+w -name "*,v" \)
            sub permissions{
                my ( $dev, $ino, $mode, $nlink, $uid, $gid ) = lstat( $_ );
                if ( ( ( $uid != $gcos[2] ) && ( ( $mode & 0400 ) == 0400 ) )
                    or ( ( $File::Find::name =~ /,v$/) && ( ( $mode & 0600 ) == 0600 ) )
                    or ( ( $File::Find::name =~ /\.txt$/) && ( ( $mode & 0600 ) != 0600 ) )
                ) {
                    push ( @offenders, $File::Find::name );
                }
            }
            if ( scalar @offenders ) {
                $result->{result} = 1;
                $result->{priority} = ERROR;
                $result->{solution} = "There exist " . scalar @offenders . " files and directories with wrong permissions.<br>" . join("<br>", @offenders);
                my $help = '<br>Try one of these commands:<br><pre>    chown -R www-data:www-data .<br>    find -type d -exec chmod 755 {} \;<br>    chmod -R u+w *<br>    find . -type f -name "*,v" -exec chmod 444 {} \;</pre>';
                $result->{solution} .= $help;
            }
            return $result;
        }
    },
    "general: GroupViewTemplate" => {
        name => "GroupViewTemplate up to date",
        description => "GroupViewTemplate has redirect and autocomplete",
        check => sub {
            my $result = { result => 0 };
            my ( $gvmeta, $gv ) = Foswiki::Func::readTopic( 'Main', 'GroupViewTemplate' );
            unless ( ( $gv =~ /USERAUTOCOMPLETE/ ) && ( $gv =~ /redirectto" value="%BASEWEB%\.%BASETOPIC%/ ) ) {
                    $result->{result} = 1;
                    $result->{priority} = ERROR;
                    $result->{solution} = "Update [[Main.GroupViewTemplate]] manually from QwikiContrib.";
            }
            return $result;
        }
    },
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
