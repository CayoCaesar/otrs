# --
# Copyright (C) 2001-2018 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

my $TicketObject  = $Kernel::OM->Get('Kernel::System::Ticket');
my $ArticleObject = $Kernel::OM->Get('Kernel::System::Ticket::Article');

$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase  => 1,
        UseTmpArticleDir => 1,
    },
);

$Kernel::OM->Get('Kernel::System::Cache')->CleanUp();
for my $Cache ( 0 .. 1 ) {
    $Self->IsDeeply(
        { $ArticleObject->ArticleSenderTypeList() },
        {
            '1' => 'agent',
            '2' => 'system',
            '3' => 'customer',
        },
        "ArticleSenderTypeList() - cache $Cache",
    );
}

$Kernel::OM->Get('Kernel::System::Cache')->CleanUp();
for my $Cache ( 0 .. 1 ) {
    $Self->Is(
        $ArticleObject->ArticleSenderTypeLookup( SenderType => 'agent' ),
        1,
        "ArticleSenderTypeLookup( SenderType ) - cache $Cache",
    );
    $Self->Is(
        $ArticleObject->ArticleSenderTypeLookup( SenderTypeID => 1 ),
        'agent',
        "ArticleSenderTypeLookup( SenderTypeID ) - cache $Cache",
    );
}

# cleanup is done by RestoreDatabase.

1;
