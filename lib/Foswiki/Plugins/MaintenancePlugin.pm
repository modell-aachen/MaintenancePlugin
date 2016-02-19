# See bottom of file for default license and copyright information
package Foswiki::Plugins::MaintenancePlugin;

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Plugins ();

# Core modules
use File::Spec; # Needed for portable checking of PATH


our $VERSION = '0.7';
our $RELEASE = "0.7";
our $SHORTDESCRIPTION = 'Q.wiki maintenance plugin';
our $NO_PREFS_IN_TOPIC = 1;

# Exported priorities for check results
our $CRITICAL = 0;
our $ERROR = 1;
our $WARN = 2;

our $checks = {
    "kvp:talk" => {
        name => "KVP Talk Suffix",
        description => "Check if KVPPlugin suffix is \"Talk\"",
        check => sub {
            my $result = { result => 0 };
            if ( ( exists $Foswiki::cfg{Plugins}{KVPPlugin}{Enabled} ) and ( $Foswiki::cfg{Plugins}{KVPPlugin}{Enabled} ) ) {
                # TODO check for Topics with old "Talk" suffix here
                if ( $Foswiki::cfg{Extensions}{KVPPlugin}{suffix} ne 'TALK' ) {
                    $result->{result} = 1;
                    $result->{priority} = $WARN;
                    $result->{solution} = 'Change setting {Extensions}{KVPPlugin}{suffix} to \'TALK\' and migrate existing topics using the current suffix, which is ' . $Foswiki::cfg{Extensions}{KVPPlugin}{suffix};
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
                        $result->{priority} = $ERROR;
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
                $result->{priority} = $WARN;
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
                    $result->{priority} = $ERROR;
                    $result->{solution} = "Add '   * Set ACTIONTRACKERPLUGIN_UPDATEAJAX = 1' to [[Main.SitePreferences]]";
                }
            }
            return $result;
        }
    },
    "actiontrackerplugin:disableduninstalled" => {
        name => "ActionTrackerPlugin disabled",
        description => "Check if ActionTrackerPlugin disabled and uninstalled.",
        check => sub {
            my $result = { result => 0 };
            my $return_text;
            if ( exists $Foswiki::cfg{Plugins}{ActionTrackerPlugin}{Enabled}) {
                $result->{result} = 1;
                $result->{priority} = $WARN;
                $result->{solution} = "ActionTrackerPlugin is enabled. Disable and uninstall ActionTrackerPlugin.";
            } elsif ( -e $Foswiki::cfg{ScriptDir} ."/../lib/Foswiki/Plugins/ActionTrackerPlugin.pm") {
                $result->{result} = 1;
                $result->{priority} = $WARN;
                $result->{solution} = "ActionTrackerPlugin found. Uninstall ActionTrackerPlugin.";
            }
            return $result;
        }
    },
    "actiontrackerplugin:remains" => {
        name => "No ActionTrackerPlugin remains present",
        description => "Check if ActionTrackerPlugin options are present.",
        check => sub {
            my $result = { result => 0 };
            my $return_text = '';
            my @webs = Foswiki::Func::getListOfWebs("user");
            my @actionWebs = ();
            for my $web (@webs) {
                my $tableHeader = Foswiki::Func::getPreferencesValue("ACTIONTRACKERPLUGIN_TABLEHEADER", $web);
                if ($tableHeader ne '') {
                    $result->{result} = 1;
                    push @actionWebs, $web;
                }
            }
            # Also check SitePreferences
            my $updateajax = Foswiki::Func::getPreferencesValue("ACTIONTRACKERPLUGIN_UPDATEAJAX");
            my $tableHeader = Foswiki::Func::getPreferencesValue("ACTIONTRACKERPLUGIN_TABLEHEADER");
            if ($updateajax ne '' || $tableHeader ne '') {
                $result->{result} = 1;
                push @actionWebs, 'Main/SitePreferences';
            }
            if (scalar @actionWebs > 0) {
                $return_text .= "Remove ActionTrackerPlugin settings (i.e. =ACTIONTRACKERPLUGIN_UPDATEAJAX=, =ACTIONTRACKERPLUGIN_TABLEHEADER=) from the following topics, if possible:" . '<div>' . join( "/WebPreferences</div><div>", @actionWebs ) . '</div><br>';
            }
            my @unknowns = _grepRecursiv($Foswiki::cfg{DataDir}, '%ACTION{');
            if (scalar @unknowns > 0) {
                $result->{result} = 1;
                $return_text .= "Remove =ACTION= macro from the following topics/files if possible:" . '<div>' . join( "</div><div>", @unknowns ) . '</div>';
            }
            if (1 == $result->{result}) {
                $result->{priority} = $WARN;
                $result->{solution} = $return_text;
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
                $result->{priority} = $WARN;
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
                    $result->{priority} = $ERROR;
                    $result->{solution} = "Update [[Main.GroupViewTemplate]] manually from QwikiContrib";
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
                $result->{priority} = $WARN;
                $result->{solution} = "Check locale direcories. If need be, merge custom localizations into subdirecory \"ZZCustom\". Offending directories: " . join( ", ", @unknowns );
            }
            return $result;
        }
    },
    "autocomplete" => {
        name => "Grep USERAUTOCOMPLETE",
        description => "Check if there are any Forms with an USERAUTOCOMPLETE field",
        check => sub {
            my $result = { result => 0 };
            my @unknowns = _grepRecursiv($Foswiki::cfg{DataDir}, '%USERAUTOCOMPLETE%');
            if ( scalar @unknowns > 0 ) {
                $result->{result} = 1;
                $result->{priority} = $WARN;
                $result->{solution} = "Check files in data directory for =USERAUTOCOMPLETE=:" . '<div>' . join( "</div><div>", @unknowns ) . '</div>';
            }
            return $result;
        }
    }
};

## Helper ##
sub _grepRecursiv{
    my ( $dir, $regex ) = @_;
    my @unknowns = ();
    opendir( my $localedh, $dir ) or push(@unknowns, "Could not open dir" );
    if ( scalar @unknowns == 0) {
        foreach my $fp (readdir $localedh) {
            if ($fp eq "." || $fp eq "..") {
                next;
            }
            my $abFile = $dir.'/'.$fp;
            if (-f $abFile) {
                if($abFile !~ /\.txt$/){
                    next;
                }
                my $fh;
                if (open $fh, "<", $abFile) {
                    foreach my $line (<$fh>) {
                        if ($line =~ /$regex/) {
                            push(@unknowns, $abFile);
                            last;
                        }
                    }
                    close $fh or push(@unknowns, "Could not close file " );
                }else{
                    push(@unknowns, "Could not read file " );
                }
            }
            if (-d $abFile) {
                if($abFile =~ /,pfv$/){
                    next;
                }
                my @input = _grepRecursiv($abFile, $regex);
                if(scalar @input >0){
                    push (@unknowns,@input) ;
                }
            }
        }
    }
    return @unknowns;
}

# This sub is used to collect Maintenance.pm
sub _collectChecks {
    for my $type (qw(Plugins Contrib)) {
        my  $typeDir = File::Spec->catdir($Foswiki::cfg{ScriptDir},'..','lib','Foswiki', $type);
        opendir(my $dh, $typeDir) or die "Cannot open directory: $!";
        my @modules = sort map {$_ =  Foswiki::Sandbox::untaintUnchecked($_)} grep {/.pm$/} readdir($dh);
        closedir($dh);
        for my $pm (@modules) {
            my $doRequire = 0;
            # Check if we want to require the module.
            # Do not require files not named *Contrib.pm from Contrib directory.
            # Also exclude some known criminal PluginContribs, which are stealthily required by their respective Plugin or vice versa.
            if (($type eq 'Contrib') and ($pm =~ /(?:Contrib|Skin)\.pm$/) and ($pm !~ /(JEditableContrib)|(MailerContrib)|(VirtualHostingContrib)\.pm/)) {
                $doRequire = 1;
            } elsif (($type eq 'Plugins') and (defined $Foswiki::cfg{Plugins}{substr($pm, 0, -3)}{Module}) and ($Foswiki::cfg{Plugins}{substr($pm, 0, -3)}{Enabled}) and ($pm !~ /(JEditableContribPlugin)\.pm/)) {
                $doRequire = 1;
            }

            if ($doRequire) {
                no strict 'refs';
                # Require module, if version string not found
                unless (${'Foswiki::' . $type . '::' . substr($pm, 0, -3) . '::VERSION'}) {
                    require(File::Spec->catfile($typeDir, $pm));
                }

                my $moduleDir = File::Spec->catdir($typeDir, substr($pm, 0, -3));
                # Module is required, now check if it has a sub "maintenanceHandler"
                my $handlerstr = 'Foswiki::' . $type . '::' . substr($pm, 0, -3) . '::maintenanceHandler';
                if (*{$handlerstr}{CODE}) {
                    my $res = &{$handlerstr}();
                }
            }
        }
    }
}

## Public ##

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
    for my $check ( sort keys %$checks ) {
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
        for my $check ( sort keys %$checks ) {
            # Exclude experimental checks, if mpcheck=safe
            unless ((CGI::param('mpcheck') eq 'safe') && ( exists $checks->{$check}->{experimental})) {
                my $res = $checks->{$check}->{check}();
                if ( $res->{result} ) {
                    $problems++;
                    my $prio =  $res->{priority};
                    my ( $COLOR, $ENDCOLOR ) = ( '', '' );
                    if ( $prio < $ERROR ) { $ENDCOLOR = '%ENDCOLOR%'; }
                    if ( $prio == $CRITICAL ) { $COLOR = '%RED%'; }
                    if ( $prio == $ERROR ) { $COLOR = '%ORANGE%'; }
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

# MaintenancePlugin compatibility
sub maintenanceHandler {
    Foswiki::Plugins::MaintenancePlugin::registerCheck("general:filepermissions", {
        name => "File permissions",
        description => "File permissions incorrect",
        check => sub {
            my $result = { result => 0 };
            # Core module
            require File::Find;
            my @dirs = ( $Foswiki::cfg{DataDir}, $Foswiki::cfg{PubDir} );
            our $direg = qr(^($Foswiki::cfg{DataDir})|($Foswiki::cfg{PubDir}));
            our @offenders = ();
            our @gcos = getpwuid($<);
            File::Find::finddepth({ wanted => \&permissions, untaint => 1, untaint_pattern => /$direg/ }, @dirs);
            # This implements:  find . ! -user www-data -or ! -perm -u+r
            sub permissions {
                my ($dev, $ino, $mode, $nlink, $uid, $gid) = lstat($_);
                if (($uid != $gcos[2])          # Wrong uid
                    or (($mode & 0400) != 0400) # Not readable
                    or (($File::Find::name =~ /\.txt$/) && (($mode & 0600) != 0600 )) # .txt file not writable.
                ) {
                    push(@offenders, $File::Find::name);
                }
            }
            if (scalar @offenders) {
                $result->{result} = 1;
                $result->{priority} = $ERROR;
                $result->{solution} = "There exist " . scalar @offenders . " files and directories with wrong permissions.<ul><li>" . join("</li><li>", @offenders) . '</li></ul>';
                my $help = 'Try one of these commands in the foswiki directory:<br><pre>    chown -R www-data:www-data .<br>    find -type d -exec chmod 755 {} \;<br>    chmod -R u+w *</pre>';
                $result->{solution} .= $help;
            }
            return $result;
        },
        experimental => 1
    });
    Foswiki::Plugins::MaintenancePlugin::registerCheck("general:release", {
        name => "Foswiki release",
        description => "Installed Foswiki release is not newest supported stable version.",
        check => sub {
            my $result = { result => 0 };
            my $last = 'Foswiki-2.1.0';
            if ( $Foswiki::RELEASE ne $last ) {
                $result->{result} = 1;
                $result->{priority} = $WARN;
                $result->{solution} = "Update Foswiki to $last. I am very sorry.";
            }
            return $result;
        }
    });
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
