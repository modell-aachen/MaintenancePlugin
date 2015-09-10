# See bottom of file for default license and copyright information
package Foswiki::Plugins::MaintenancePlugin;

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Plugins ();

# Core modules
use File::Spec; # Needed for portable checking of PATH

our $VERSION = '0.4';
our $RELEASE = "0.4";
our $SHORTDESCRIPTION = 'Q.wiki maintenance plugin';
our $NO_PREFS_IN_TOPIC = 1;

# priorities for check results
use constant CRITICAL => 0;
use constant ERROR => 1;
use constant WARN => 2;

my $checks = {
    "kvp:talk" => {
        name => "KVP Talk Suffix",
        description => "Check if KVPPlugin suffix is \"Talk\"",
        check => sub {
            my $result = { result => 0 };
            if ( ( exists $Foswiki::cfg{Plugins}{KVPPlugin}{Enabled} ) and ( $Foswiki::cfg{Plugins}{KVPPlugin}{Enabled} ) ) {
                # TODO check for Topics with old "Talk" suffix here
                if ( $Foswiki::cfg{Extensions}{KVPPlugin}{suffix} ne 'TALK' ) {
                    $result->{result} = 1;
                    $result->{priority} = WARN;
                    $result->{solution} = 'Change setting {Extensions}{KVPPlugin}{suffix} to \'TALK\' and migrate existing topics using the current suffix, which is ' . $Foswiki::cfg{Extensions}{KVPPlugin}{suffix};
                }
            }
            return $result;
        }
    },
    "ldapcontrib:refresh" => {
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
    "modaccontextmenu:skin" => {
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
    "general:replaceifeditedagainwithin" => {
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
    "actiontrackerplugin:sitepreferences" => {
        name => "Actiontracker site preferences",
        description => "ACTIONTRACKERPLUGIN_UPDATEAJAX set in SitePreferences",
        check => sub {
            my $result = { result => 0 };
            if ( ( exists $Foswiki::cfg{Plugins}{ActionTrackerPlugin}{Enabled} ) and ( $Foswiki::cfg{Plugins}{ActionTrackerPlugin}{Enabled} ) ) {
                my ( $spmeta, $sp ) = Foswiki::Func::readTopic( 'Main', 'SitePreferences');
                if ( $spmeta->getPreference( "ACTIONTRACKERPLUGIN_UPDATEAJAX" ) ne '1' ) {
                    $result->{result} = 1;
                    $result->{priority} = ERROR;
                    $result->{solution} = "Add '   * Set ACTIONTRACKERPLUGIN_UPDATEAJAX = 1' to [[Main.SitePreferences]]";
                }
            }
            return $result;
        }
    },
    "general:customnowysiwyg" => {
        name => "Custom web NOWYSIWYG",
        description => "Custom web has NOWYSIWYG preference",
        check => sub {
            my $result = { result => 0 };
            my $nowysiwyg = Foswiki::Func::getPreferencesValue( "NOWYSIWYG", "Custom" );
            chomp $nowysiwyg;
            $nowysiwyg =~ s/\s+$//;
            $nowysiwyg =~ s/^\s+//;
            if ( $nowysiwyg ne '1' ) {
                $result->{result} = 1;
                $result->{priority} = WARN;
                $result->{solution} = "Add '   * Set NOWYSIWYG = 1' to [[Custom.WebPreferences]]";
            }
            return $result;
        }
    },
    "general:groupviewtemplate" => {
        name => "GroupViewTemplate outdated",
        description => "GroupViewTemplate has redirect and autocomplete",
        check => sub {
            my $result = { result => 0 };
            my ( $gvmeta, $gv ) = Foswiki::Func::readTopic( 'Main', 'GroupViewTemplate' );
            unless ( ( $gv =~ /USERAUTOCOMPLETE/ ) && ( $gv =~ /redirectto" value="%BASEWEB%\.%BASETOPIC%/ ) ) {
                    $result->{result} = 1;
                    $result->{priority} = ERROR;
                    $result->{solution} = "Update [[Main.GroupViewTemplate]] manually from QwikiContrib";
            }
            return $result;
        }
    },
    "processescontentcontrib:responsibilities" => {
        name => "Responsibilities outdated",
        description => "Responsibilites topic search is outdated",
        check => sub {
            my $result = { result => 0 };
            # find topic
            my ($web, $topic) = ( '', '' );
            if ( Foswiki::Func::webExists( 'Processes' ) ) {
                $web = 'Processes';
                if ( Foswiki::Func::topicExists( $web, 'Responsibilities' ) ) { $topic = 'Responsibilities'; }
                elsif ( Foswiki::Func::topicExists( $web, 'Seitenverantwortlichkeiten' ) ) { $topic = 'Seitenverantwortlichkeiten'; }
            } elsif ( Foswiki::Func::webExists( 'Prozesse' ) ) {
                $web = 'Prozesse';
                if ( Foswiki::Func::topicExists( $web, 'Responsibilities' ) ) { $topic = 'Responsibilities'; }
                elsif ( Foswiki::Func::topicExists( $web, 'Seitenverantwortlichkeiten' ) ) { $topic = 'Seitenverantwortlichkeiten'; }
            }
            # Could not determine topic?
            if ( $topic eq '' ) {
                $result->{result} = 1;
                $result->{priority} = WARN;
                $result->{solution} = "Could not find responsibilites topic. Find and check manually if it lists only correct topics";
            } else {
                # Check topic
                my ( $tmeta, $tv ) = Foswiki::Func::readTopic( $web, $topic );
                # check it SOLRSEARCH excludes Discussions etc.
                unless ( $tv =~ /-topic:\(\*Template OR \*Talk OR \*TALK OR \*Form OR NormClassification\*\)/ ) {
                        $result->{result} = 1;
                        $result->{priority} = WARN;
                        $result->{solution} = "Update [[$web.$topic]] manually to exclude unwanted topics from results";
                }
            }
            return $result;
        }
    },
    "general:userautocomplete" => {
        name => "User autocomplete configuration",
        description => "USERAUTOCOMPLETE set in SitePreferences",
        check => sub {
            my $result = { result => 0 };
            my ( $spmeta, $sp ) = Foswiki::Func::readTopic( 'Main', 'SitePreferences');
            if ( $spmeta->getPreference( "USERAUTOCOMPLETE" ) eq '' ) {
                $result->{result} = 1;
                $result->{priority} = CRITICAL;
                $result->{solution} = "Add USERAUTOCOMPLETE setting to [[Main.SitePreferences]] according to documentation";
            }
            return $result;
        }
    },
    "general:locales" => {
        name => "Locale directories",
        description => "Directories without System topic in locales dir.",
        check => sub {
            my $result = { result => 0 };
            my @unknowns = ();
            opendir( my $localedh, $Foswiki::cfg{LocalesDir} ) or push(@unknowns, "Could not open locale dir" );
            if ( scalar @unknowns == 0) {
                my @dirs = readdir( $localedh );
                # check dirs for existing contribs
                foreach my $res ( @dirs ) {
                    unless ( ( $res =~ /(^\.)|(^\.\.)|(\.po)|(^Foswiki\.pot)|(^ZZCustom)|(^Foswiki)$/ ) || ( Foswiki::Func::topicExists( "System", $res ) ) ) {
                        push( @unknowns, $res );
                    }
                }
                closedir $localedh;
            }
            if ( scalar @unknowns > 0 ) {
                $result->{result} = 1;
                $result->{priority} = WARN;
                $result->{solution} = "Check locale direcories. If need be, merge custom localizations into subdirecory \"ZZCustom\". Offending directories: " . join( ", ", @unknowns );
            }
            return $result;
        }
    },
    "general:release" => {
        name => "Foswiki release",
        description => "Installed Foswiki release is not newest supported stable version.",
        check => sub {
            my $result = { result => 0 };
            my $last = 'Foswiki-1.1.9';
            if ( $Foswiki::RELEASE ne $last ) {
                $result->{result} = 1;
                $result->{priority} = WARN;
                $result->{solution} = "Update Foswiki to $last. I am very sorry.";
            }
            return $result;
        }
    },
    # FIXME this is most likely not portable to non linux systems, or 2.4 linux systems.
    "general:stringifiercontrib:commands" => {
        name => "Stringifier command validity",
        description => "One or more necessary stringifier commands appear to be nonfunctional.",
        check => sub {
            my $result = { result => 0 };
            if ( my @cmds = keys( %{$Foswiki::cfg{StringifierContrib}} ) ) {
                my $indexer = $Foswiki::cfg{StringifierContrib}{WordIndexer};
                my @offenders = ();
                my @path = ('');
                push @path, File::Spec->path();
                for my $cmd ( @cmds ) {
                    if ( $cmd =~ /Cmd$/ ) {
                        # Do not check unused word indexers.
                        if ( ( ( $indexer eq 'wv' ) && ( $cmd =~ /^(abiwordCmd)|(antiwordCmd)$/) )
                            or ( ( $indexer eq 'antiword' ) && ( $cmd =~ /^(abiwordCmd)|(wvTextCmd)$/ ) )
                            or ( ( $indexer eq 'abiword'  ) && ( $cmd =~ /^(antiwordCmd)|(wvTextCmd)$/ ) ) ) {
                            next;
                        }
                        # Omit parameters
                        my $executable = ( split( / /, $Foswiki::cfg{StringifierContrib}{$cmd} ) )[0];
                        my $found = 0;
                        # check local dir, then PATH
                        if ( $executable =~ /^\./ ) {
                            if ( -x $executable ) { $found = 1; last; }
                        }
                        for my $check ( map { File::Spec->catfile( $_, $executable ) } @path ) {
                            if ( -x $check ) { $found = 1; last; }
                        }
                        unless ( $found ) {
                            push @offenders, "{StringifierContrib}{$cmd}";
                        }
                    }
                }
                if ( scalar @offenders > 0 ) {
                        $result->{result} = 1;
                        $result->{priority} = ERROR;
                        $result->{solution} = "Check the following StringifierContrib commands: " . join( ', ', @offenders ) . ".";
                }
            }
            return $result;
        },
        experimental => 0
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

# This sub is used to collect Maintenance.pm
sub _collectChecks {
    for my $type qw(Plugins Contrib) {
        my  $typeDir = File::Spec->catdir($Foswiki::cfg{ScriptDir},'..','lib','Foswiki', $type);
        opendir(my $dh, $typeDir) or die "Cannot open directory: $!";
        my @modules = sort grep {/.pm$/} readdir($dh);
        closedir($dh);
        for my $pm (@modules) {
            my $moduleDir = File::Spec->catdir($typeDir, substr($pm, 0, -3));
            my $requirePath = File::Spec->catfile($moduleDir, 'Maintenance.pm');
            if ( -d $moduleDir and -f $requirePath) {
                $requirePath = Foswiki::Sandbox::untaintUnchecked($requirePath);
                # #FIXME: Technically, there could be anything in this file. Do we prevent that, or will we assume that the lib namespace is safe?
                require(File::Spec->catfile($requirePath));
                # Module is required, now check if it has a $maintain scalar that evaluates to true
                {
                    no strict 'refs';
                    my $modstr = 'Foswiki::' . $type . '::' . substr($pm, 0, -3) . '::Maintenance';
                    if (${$modstr . '::maintain'}) { &{$modstr . '::maintain'}; }
                }
            }
        }
    }
}

# This can be used to override existing checks or to add new ones.
sub registerCheck {
    my ( $name, $newcheck, @bad ) = @_;
    if ( @bad ) {
        Foswiki::Func::writeWarning( "Wrong number of arguments in " . (caller(0))[3] );
        return 0;
    }
    $checks->{ $name } = $newcheck;
}

sub tagList {
    my( $session, $params, $topic, $web, $topicObject ) = @_;
    # FIXME: Is this safe for non Admins? Maybe change to adminonly
    _collectChecks();
    my $result = "| *Check* | *Description* |\n";
    for my $check ( keys %$checks ) {
        $result .= '| ' . $checks->{$check}->{name} . ' | ' . $checks->{$check}->{description}  . " |\n";
    }
    return $result;
}

sub tagCheck {
    my( $session, $params, $topic, $web, $topicObject ) = @_;

    my $result;
    # Allow only for AdminUser
    if ((Foswiki::Func::isAnAdmin()) and (CGI::param('mpcheck'))) {
        my $problems = 0;
        my $warnings = {};
        _collectChecks();
        for my $check ( keys %$checks ) {
            # Exclude experimental checks, if mpcheck=safe
            unless ((CGI::param('mpcheck') eq 'safe') && ( exists $checks->{$check}->{experimental})) {
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
        }
        if ( $problems > 0 ) {
            $result = "| *Prio* | *Name* | *Description* | *Solution* |\n";
            for my $prio ( sort keys %$warnings ) {
                $result .= join( "", @{$warnings->{$prio}} );
            }
        } else {
            $result .= " | No problems detected. Everything is awesome ||||\n";
        }
    } else {
        $result = 'MP_CHECK only allowed for admins and in use with http get mpcheck set. ';
    }
    return $result;
}

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
