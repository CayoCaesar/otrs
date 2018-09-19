# --
# Copyright (C) 2001-2018 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package scripts::DBUpdateTo6::MigrateTimeZoneConfiguration;    ## no critic

use strict;
use warnings;

use IO::Interactive qw(is_interactive);

use parent qw(scripts::DBUpdateTo6::Base);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DB',
    'Kernel::System::SysConfig',
);

sub CheckPreviousRequirement {
    my ( $Self, %Param ) = @_;

    # Check if following table already exists. In this case, time zone configuration is already done.
    my $TableExists = $Self->TableExists(
        Table => 'ticket_number_counter',
    );

    return 1 if $TableExists;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # Check if configuration was already made.
    my $OTRSTimeZone        = $ConfigObject->Get('OTRSTimeZone') // '';
    my $UserDefaultTimeZone = $ConfigObject->Get('UserDefaultTimeZone') // '';
    if ( $OTRSTimeZone && $UserDefaultTimeZone ) {
        return 1;
    }

    # Get system time zone
    my $DateTimeObject = $Kernel::OM->Create(
        'Kernel::System::DateTime',
        ObjectParams => {
            TimeZone => 'UTC',
        },
    );
    my $SystemTimeZone = $DateTimeObject->SystemTimeZoneGet() || 'UTC';
    $DateTimeObject->ToTimeZone( TimeZone => $SystemTimeZone );

    # Get configured deprecated time zone offset.
    my $TimeOffset = int( $ConfigObject->Get('TimeZone') || 0 );

    # Calculate complete time offset (server time zone + OTRS time offset).
    my $SuggestedTimeZone = $TimeOffset ? '' : $SystemTimeZone;
    $TimeOffset += $DateTimeObject->Format( Format => '%{offset}' ) / 60 / 60;

    if ( ( $Param{CommandlineOptions}->{NonInteractive} || !is_interactive() ) && $TimeOffset != 0 ) {
        print
            "\n\n      Error: The currently time offset is $TimeOffset hours, in this case you can not run the script in non-interactive mode. \n"
            . "        Please execute the script in interactive mode and select the correct timezone. \n\n";
        return;
    }

    if ( $Param{CommandlineOptions}->{NonInteractive} || !is_interactive() ) {
        return 1;
    }

    #
    # OTRSTimeZone
    #

    # Show suggestions for time zone
    my %TimeZones = map { $_ => 1 } @{ $DateTimeObject->TimeZoneList() };
    my $TimeZoneByOffset = $DateTimeObject->TimeZoneByOffsetList();
    if ( exists $TimeZoneByOffset->{$TimeOffset} ) {
        print
            "\n\n        The currently configured time offset is $TimeOffset hours, these are the suggestions for a corresponding OTRS time zone: \n\n";

        print "        " . join( "\n        ", sort @{ $TimeZoneByOffset->{$TimeOffset} } ) . "\n";
    }

    if ( $SuggestedTimeZone && $TimeZones{$SuggestedTimeZone} ) {
        print "\n\n        It seems that $SuggestedTimeZone should be the correct time zone to set for your OTRS. \n";
    }

    $Self->{TargetTimeZones}->{OTRSTimeZone} = $Self->_AskForTimeZone(
        ConfigKey => 'OTRSTimeZone',
        TimeZones => \%TimeZones,
    );

    #
    # UserDefaultTimeZone
    #
    $Self->{TargetTimeZones}->{UserDefaultTimeZone} = $Self->_AskForTimeZone(
        ConfigKey => 'UserDefaultTimeZone',
        TimeZones => \%TimeZones,
    );

    #
    # TimeZone::Calendar[1..9] (but only those that have already a time offset set)
    #
    CALENDAR:
    for my $Calendar ( 1 .. 9 ) {
        my $ConfigKey        = "TimeZone::Calendar$Calendar";
        my $CalendarTimeZone = $ConfigObject->Get($ConfigKey);
        next CALENDAR if !defined $CalendarTimeZone;

        $Self->{TargetTimeZones}->{$ConfigKey} = $Self->_AskForTimeZone(
            ConfigKey => $ConfigKey,
            TimeZones => \%TimeZones,
        );
    }

    print "\n";

    return 1;
}

=head1 NAME

scripts::DBUpdateTo6::MigrateTimeZoneConfiguration - Migrate timezone configuration.

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $Verbose = $Param{CommandlineOptions}->{Verbose} || 0;

    # Check if following table already exists. In this case, time zone configuration is already done.
    my $TableExists = $Self->TableExists(
        Table => 'ticket_number_counter',
    );

    return 1 if $TableExists;

    #
    # Check for interactive mode
    #
    if ( $Param{CommandlineOptions}->{NonInteractive} || !is_interactive() ) {

        if ($Verbose) {
            print
                "\n        - Migration of time zone settings is being skipped because this script is being executed in non-interactive mode. \n"
                . "        Please make sure to set the following SysConfig options after this script has been executed: \n"
                . "        OTRSTimeZone \n"
                . "        UserDefaultTimeZone \n"
                . "        TimeZone::Calendar1 to TimeZone::Calendar9 (depending on the calendars in use) \n\n";
        }
        return 1;
    }

    for my $ConfigKey ( sort keys %{ $Self->{TargetTimeZones} // {} } ) {

        my $Result = $Self->SettingUpdate(
            Name           => $ConfigKey,
            IsValid        => 1,
            EffectiveValue => $Self->{TargetTimeZones}->{$ConfigKey},
            UserID         => 1,
        );

        return if !$Result;
    }

    return 1;
}

sub _AskForTimeZone {
    my ( $Self, %Param ) = @_;

    my $TimeZone;
    print "\n";
    while ( !defined $TimeZone || !$Param{TimeZones}->{$TimeZone} ) {
        print
            "        Enter the time zone to use for $Param{ConfigKey} (leave empty to show a list of all available time zones): ";
        $TimeZone = <>;

        # Remove white space
        $TimeZone =~ s{\s}{}smx;

        if ( length $TimeZone ) {
            if ( !$Param{TimeZones}->{$TimeZone} ) {
                print "        Invalid time zone. \n";
            }
        }
        else {
            # Show list of all available time zones
            print "        " . join( "\n        ", sort keys %{ $Param{TimeZones} } ) . " \n";
        }
    }

    return $TimeZone;
}

1;

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
