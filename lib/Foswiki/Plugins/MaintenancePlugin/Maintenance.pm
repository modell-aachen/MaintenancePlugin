package Foswiki::Plugins::MaintenancePlugin::Maintenance;

our $maintain = 1;
sub maintain {
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
            our @gcos = getpwuid( $< );
            File::Find::finddepth( { wanted => \&permissions, untaint => 1, untaint_pattern => /$direg/ }, @dirs );
            # This implements:  find . ! -user www-data -or ! -perm -u+r -or \( -perm -u+w -name "*,v" \)
            sub permissions {
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
                my $help = '<br>Try one of these commands in the foswiki directory:<br><pre>    chown -R www-data:www-data .<br>    find -type d -exec chmod 755 {} \;<br>    chmod -R u+w *<br>    find . -type f -name "*,v" -exec chmod 444 {} \;</pre>';
                $result->{solution} .= $help;
            }
            return $result;
        },
        experimental => 1
    });
}

1;
