# --
# Copyright (C) 2001-2018 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

## no critic (Modules::RequireExplicitPackage)
use strict;
use warnings;
use utf8;

use vars (qw($Self));

my $CommandObject = $Kernel::OM->Get('Kernel::System::Console::Command::Dev::Tools::Migrate::ConfigXMLStructure');

my $Home = $Kernel::OM->Get('Kernel::Config')->Get('Home');

my ( $Result, $ExitCode );
{
    local *STDOUT;
    open STDOUT, '>:encoding(UTF-8)', \$Result;
    $ExitCode = $CommandObject->Execute( "--source-directory", "$Home/Kernel/Config/Files/NotExisting/" );
    $Kernel::OM->Get('Kernel::System::Encode')->EncodeInput( \$Result );
}
$Self->Is(
    $ExitCode,
    1,
    "Dev::Tools::Migrate::ConfigXMLStructure exit code not existing directory",
);

1;
