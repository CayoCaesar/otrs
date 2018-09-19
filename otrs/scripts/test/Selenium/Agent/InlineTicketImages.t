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

# get selenium object
my $Selenium = $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');

my $CreateTestCustomer = sub {
    my $Helper             = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');

    my $RandomID           = $Helper->GetRandomID();
    my $TestCustomer       = 'Customer' . $RandomID;
    my $CustomerEmail      = "$TestCustomer\@localhost.com";
    my $TestCustomerUserID = $CustomerUserObject->CustomerUserAdd(
        Source         => 'CustomerUser',
        UserFirstname  => $TestCustomer,
        UserLastname   => $TestCustomer,
        UserCustomerID => $TestCustomer,
        UserLogin      => $TestCustomer,
        UserEmail      => $CustomerEmail,
        ValidID        => 1,
        UserID         => 1
    );
    $Self->True(
        $TestCustomerUserID,
        "CustomerUserAdd - ID $TestCustomerUserID",
    );

    return $TestCustomer;
};

my $CreateTestUser = sub {
    my $Helper     = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
    my $UserObject = $Kernel::OM->Get('Kernel::System::User');

    my $Language      = 'en';
    my $TestUserLogin = $Helper->TestUserCreate(
        Groups   => [ 'users', ],
        Language => $Language,
    ) || die "Did not get test user";

    # get UserID
    my $TestUserID = $UserObject->UserLookup(
        UserLogin => $TestUserLogin,
    );

    return $TestUserLogin;
};

my $ImportSampleEmail = sub {
    my $OTRSDIR = $Kernel::OM->Get('Kernel::Config')->Get('Home');
    my $FH      = IO::File->new( "${ OTRSDIR }/scripts/test/sample/PostMaster/InlineImage.box", 'r', );
    my @Lines   = <$FH>;

    my $CommunicationLogObject = $Kernel::OM->Create(
        'Kernel::System::CommunicationLog',
        ObjectParams => {
            Transport   => 'Email',
            Direction   => 'Incoming',
            AccountType => 'Test',
            AccountID   => 'test',
        },
    );

    $CommunicationLogObject->ObjectLogStart( ObjectLogType => 'Message' );

    my $PostMasterObject = $Kernel::OM->Create(
        'Kernel::System::PostMaster',
        ObjectParams => {
            Email                  => \@Lines,
            Trusted                => 0,
            CommunicationLogObject => $CommunicationLogObject,
        },
    );

    my ( undef, $TicketID ) = $PostMasterObject->Run(
        QueueID => 0,
    );

    return {
        TicketID               => $TicketID,
        CommunicationLogObject => $CommunicationLogObject,
    };
};

my $DeleteSampleEmail = sub {
    my %Param = @_;

    my $Data = $Param{Data};

    # Delete communication log
    my $CommunicationLogDBObj   = $Kernel::OM->Get('Kernel::System::CommunicationLog::DB');
    my $CommunicationLogDeleted = $CommunicationLogDBObj->CommunicationDelete(
        CommunicationID => $Data->{CommunicationLogObject}->CommunicationIDGet(),
    );

    $Self->True(
        $CommunicationLogDeleted,
        'Communication log deleted.',
    );

    # Delete ticket
    my $TicketDeleted = $Kernel::OM->Get('Kernel::System::Ticket')->TicketDelete(
        TicketID => $Data->{TicketID},
        UserID   => 1,
    );

    $Self->True(
        $TicketDeleted,
        'Ticket deleted.',
    );

    return;
};

# Check in the TicketZoom that we don't have any attachment list.
my $CheckTicketZoom = sub {
    my %Param = @_;

    my $TicketID = $Param{TicketID};

    # get script alias
    my $ScriptAlias = $Kernel::OM->Get('Kernel::Config')->Get('ScriptAlias');

    # go to ticket zoom page
    $Selenium->VerifiedGet( "${ScriptAlias}index.pl?Action=AgentTicketZoom;TicketID=" . $TicketID );

    # get the attachment list items
    my $AttachmentsList = $Selenium->find_elements( '.ArticleMailContent .ArticleAttachments li', 'css' );

    $Self->False(
        scalar( @{$AttachmentsList} ),
        "TicketZoom, inline images not in the attachments list."
    );

    return;
};

# Check in the message source that the inline image have the Content-Disposition has 'inline'.
my $CheckEmailContentDisposition = sub {
    my %Param = @_;

    my $MailQueueObject = $Kernel::OM->Get('Kernel::System::MailQueue');

    my $Action = $Param{Action};

    # Get the last email stored in the mail-queue.
    my $List = $MailQueueObject->List();
    $List = [ sort { $a->{ID} <=> $b->{ID} } @{$List} ];
    my $Email = pop @{$List};

    my $Body = $Email->{Message}->{Body};

    # Search for the image content-type and then get the content-disposition.
    my $Pos = index $Body, 'Content-Type: image/png;';
    my $Substr = substr $Body, $Pos;
    my ($ContentDisposition) = ( $Substr =~ m/Content-Disposition: (\w+);/i );

    $Self->Is(
        'inline',
        $ContentDisposition,
        "TicketCompose(${ Action }), Content-Disposition as inline",
    );

    return;
};

# Check in the TicketCompose(Reply|Forward) that attachment list is empty.
my $CheckTicketReplyOrForward = sub {
    my %Param = @_;

    my $TicketID = $Param{TicketID};
    my $Action   = $Param{Action};

    # get script alias
    my $ScriptAlias = $Kernel::OM->Get('Kernel::Config')->Get('ScriptAlias');

    # go to ticket zoom page
    $Selenium->VerifiedGet( "${ScriptAlias}index.pl?Action=AgentTicketZoom;TicketID=" . $TicketID );

    if ( $Action eq 'Reply' ) {
        $Selenium->execute_script(
            "\$('form[title=\"Reply\"] select[id^=\"ResponseID\"]').val('1').trigger('redraw.InputField').trigger('change');"
        );
    }
    else {    # Forward
        $Selenium->find_element("//a[contains(\@href, \'Action=AgentTicketForward;')]")->click();
    }

    # Switch to compose window.
    $Selenium->WaitFor( WindowCount => 2 );
    my $Handles = $Selenium->get_window_handles();
    $Selenium->switch_to_window( $Handles->[1] );

    # Wait without jQuery because it might not be loaded yet.
    $Selenium->WaitFor(
        JavaScript => 'return typeof($) === "function" && $("#ToCustomer").length && $("#submitRichText").length'
    );

    if ( $Action eq 'Forward' ) {
        my $TestCustomer = $Param{TestCustomer};

        # Input required field and select customer.
        $Selenium->find_element( "#ToCustomer", 'css' )->send_keys($TestCustomer);

        # Autocomplete results are not shown sometimes, so add a space to trigger event one times more.
        sleep 1;
        $Selenium->find_element( "#ToCustomer", 'css' )->send_keys(" ");

        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("li.ui-menu-item:visible").length' );
        $Selenium->execute_script("\$('li.ui-menu-item:contains($TestCustomer)').click()");
    }

    # get attachments list
    my $AttachmentsList = $Selenium->find_elements( 'table.AttachmentList tbody tr', 'css' );

    $Self->False(
        scalar( @{$AttachmentsList} ),
        "TicketCompose(${ Action }), inline images not in the attachments list."
    );

    # Input required fields and submit compose.
    $Selenium->execute_script("\$('#submitRichText').click()");

    $Selenium->WaitFor( WindowCount => 1 );
    $Selenium->switch_to_window( $Handles->[0] );

    $Selenium->VerifiedRefresh();

    $CheckEmailContentDisposition->(
        Action => $Action,
    );

    return;
};

$Selenium->RunTest(
    sub {
        my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

        # Disable check email addresses.
        $Helper->ConfigSettingChange(
            Key   => 'CheckEmailAddresses',
            Value => 0,
        );

        # Do not check service and type.
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'Ticket::Service',
            Value => 0
        );
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'Ticket::Type',
            Value => 0
        );

        # import the sample email
        my $ImportedEmail = $ImportSampleEmail->();

        # create test user
        my $TestUserLogin = $CreateTestUser->();

        # create test customer
        my $TestCustomer = $CreateTestCustomer->();

        # start test
        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        $CheckTicketZoom->(
            TicketID => $ImportedEmail->{TicketID},
        );

        $CheckTicketReplyOrForward->(
            TicketID => $ImportedEmail->{TicketID},
            Action   => 'Reply',
        );

        $CheckTicketReplyOrForward->(
            TicketID     => $ImportedEmail->{TicketID},
            Action       => 'Forward',
            TestCustomer => $TestCustomer,
        );

        $DeleteSampleEmail->(
            Data => $ImportedEmail,
        );

        return;
    }
);

1;
