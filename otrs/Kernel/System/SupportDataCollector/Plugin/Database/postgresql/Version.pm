# --
# Copyright (C) 2001-2018 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SupportDataCollector::Plugin::Database::postgresql::Version;

use strict;
use warnings;

use parent qw(Kernel::System::SupportDataCollector::PluginBase);

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::System::DB',
);

sub GetDisplayPath {
    return Translatable('Database');
}

sub Run {
    my $Self = shift;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    if ( $DBObject->GetDatabaseFunction('Type') !~ m{^postgresql} ) {
        return $Self->GetResults();
    }

    my $Version = $DBObject->Version();
    my ( $VersionMajor, $VersionMinor ) = $Version =~ m/^PostgreSQL \s+ (\d{1,3}) \. (\d{1,3})/ismx;
    if ($VersionMajor) {
        if ( sprintf( '%03d%03d', $VersionMajor, $VersionMinor ) >= 9_002 ) {
            $Self->AddResultOk(
                Label => Translatable('Database Version'),
                Value => $Version,
            );
        }
        else {
            $Self->AddResultProblem(
                Label   => Translatable('Database Version'),
                Value   => $Version,
                Message => Translatable('PostgreSQL 9.2 or higher is required.')
            );
        }
    }
    else {
        $Self->AddResultProblem(
            Label   => Translatable('Database Version'),
            Value   => $Version,
            Message => Translatable('Could not determine database version.')
        );
    }

    return $Self->GetResults();
}

1;
