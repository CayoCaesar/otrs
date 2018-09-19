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

my $Selenium = $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');

$Selenium->RunTest(
    sub {

        my $Helper       = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
        my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
        my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
        my $LinkObject   = $Kernel::OM->Get('Kernel::System::LinkObject');

        # Create test user.
        my $TestUserLogin = $Helper->TestUserCreate(
            Groups => [ 'admin', 'users' ],
        ) || die "Did not get test user";

        # Get test user ID.
        my $TestUserID = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
            UserLogin => $TestUserLogin,
        );

        my $ScriptAlias = $ConfigObject->Get('ScriptAlias');
        my $Home        = $ConfigObject->Get('Home');

        # Login as test user.
        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        # Navigate to AdminGenericInterfaceWebservice screen.
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AdminGenericInterfaceWebservice");

        # Click 'Add web service' button.
        $Selenium->find_element("//button[\@type='submit']")->VerifiedClick();
        $Selenium->WaitFor( JavaScript => "return typeof(\$) === 'function' && \$('#Name').length" );

        # Import web service.
        $Selenium->find_element( "#ImportButton", 'css' )->click();
        $Selenium->WaitFor( JavaScript => "return typeof(\$) === 'function' && \$('.Dialog.Modal').length" );

        my $File     = 'GenericTicketConnectorREST.yml';
        my $Location = "$Home/scripts/test/sample/Webservice/$File";
        my $Name     = "Webservice" . $Helper->GetRandomID();
        $Selenium->find_element( "#WebserviceName",     'css' )->send_keys($Name);
        $Selenium->find_element( "#ConfigFile",         'css' )->send_keys($Location);
        $Selenium->find_element( "#ImportButtonAction", 'css' )->click();
        $Selenium->WaitFor(
            JavaScript =>
                "return typeof(\$) === 'function' && !\$('.Dialog.Modal').length && \$('tr td:contains(\"$Name\")').length"
        );

        # Verify that web service is created.
        $Self->True(
            $Selenium->execute_script("return \$('.MessageBox p:contains(Web service \"$Name\" created)').length"),
            "$Name is created",
        );

        # Create test tickets.
        my @TicketIDs;
        for my $TicketCreate ( 1 .. 2 ) {
            my $TicketTitle = "Title" . $Helper->GetRandomID();
            my $TicketID    = $TicketObject->TicketCreate(
                Title      => $TicketTitle,
                Queue      => 'Raw',
                Lock       => 'unlock',
                Priority   => '3 normal',
                State      => 'open',
                CustomerID => 'SeleniumCustomer',
                OwnerID    => $TestUserID,
                UserID     => $TestUserID,
            );
            $Self->True(
                $TicketID,
                "TicketID $TicketID is created",
            );
            push @TicketIDs, $TicketID;
        }

        # Link first and second ticket as parent-child.
        my $Success = $LinkObject->LinkAdd(
            SourceObject => 'Ticket',
            SourceKey    => $TicketIDs[0],
            TargetObject => 'Ticket',
            TargetKey    => $TicketIDs[1],
            Type         => 'ParentChild',
            State        => 'Valid',
            UserID       => 1,
        );
        $Self->True(
            $Success,
            "TickedID $TicketIDs[0] and $TicketIDs[1] linked as parent-child"
        );

        # Discard ticket object to trigger link ticket add event.
        $Kernel::OM->ObjectsDiscard( Objects => ['Kernel::System::Ticket'] );

        # Go to test webservice detail screen.
        $Selenium->find_element( $Name, 'link_text' )->VerifiedClick();

        # Go to Debugger screen.
        $Selenium->execute_script("return \$('.fa-bug').click();");
        $Selenium->WaitFor(
            JavaScript =>
                "return typeof(\$) === 'function' && \$('#RequestList').length"
        );

        $Self->True(
            $Selenium->execute_script("return \$('#RequestList tr:eq(1)').text().trim();"),
            "There is a content in RequestList, link tiket add event is trigered",
        );

        # Go back to the overview screen.
        $Selenium->execute_script("return \$('.fa-caret-left').click();");
        $Selenium->WaitFor(
            JavaScript =>
                "return typeof(\$) === 'function' && \$('#DeleteButton').length"
        );

        # Delete web service.
        $Selenium->find_element( "#DeleteButton", 'css' )->click();
        $Selenium->WaitFor(
            JavaScript =>
                "return typeof(\$) === 'function' && \$('.Dialog.Modal').length && \$('#DialogButton2').length"
        );
        $Selenium->find_element( "#DialogButton2", 'css' )->click();

        # Wait until delete dialog has closed and action performed.
        $Selenium->WaitFor( JavaScript => "return typeof(\$) === 'function' && !\$('#DialogButton2').length" );
        $Selenium->WaitFor(
            JavaScript =>
                'return typeof(Core) == "object" && typeof(Core.App) == "object" && Core.App.PageLoadComplete'
        );

        # Verify that web service is deleted.
        $Self->True(
            index( $Selenium->get_page_source(), "Web service \"$Name\" deleted!" ) > -1,
            "$Name is deleted",
        );

    }
);

1;
