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
        my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

        # Do not check RichText.
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'Frontend::RichText',
            Value => 0,
        );

        # Disable setting.
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'Ticket::Frontend::CustomerTicketZoom###CustomerZoomExpand',
            Value => 0,
        );

        # Create test customer user.
        my $TestCustomerUserLogin = $Helper->TestCustomerUserCreate(
        ) || die "Did not get test customer user";

        # Create test ticket.
        my $TicketNumber = $TicketObject->TicketCreateNumber();
        my $TicketID     = $TicketObject->TicketCreate(
            TN           => $TicketNumber,
            Title        => 'Some Ticket Title',
            Queue        => 'Raw',
            Lock         => 'unlock',
            Priority     => '3 normal',
            State        => 'new',
            CustomerID   => $TestCustomerUserLogin,
            CustomerUser => $TestCustomerUserLogin,
            OwnerID      => 1,
            UserID       => 1,
        );
        $Self->True(
            $TicketID,
            "Ticket is created - $TicketID",
        );

        # Create test article for test ticket.
        my $SubjectRandom = "Subject" . $Helper->GetRandomID();
        my $TextRandom    = "Text" . $Helper->GetRandomID();

        my $ArticleBackendObject = $Kernel::OM->Get('Kernel::System::Ticket::Article')->BackendForChannel(
            ChannelName => 'Phone',
        );

        my $ArticleID = $ArticleBackendObject->ArticleCreate(
            TicketID             => $TicketID,
            SenderType           => 'customer',
            IsVisibleForCustomer => 1,
            Subject              => $SubjectRandom,
            Body                 => $TextRandom,
            Charset              => 'charset=ISO-8859-15',
            MimeType             => 'text/plain',
            HistoryType          => 'AddNote',
            HistoryComment       => 'Some free text!',
            UserID               => 1,
        );

        $Self->True(
            $ArticleID,
            "Article #1 is created - $ArticleID",
        );

        my $ArticleID2 = $ArticleBackendObject->ArticleCreate(
            TicketID             => $TicketID,
            SenderType           => 'customer',
            IsVisibleForCustomer => 1,
            Subject              => $SubjectRandom,
            Body                 => $TextRandom,
            Charset              => 'charset=ISO-8859-15',
            MimeType             => 'text/plain',
            HistoryType          => 'AddNote',
            HistoryComment       => 'Some free text!',
            UserID               => 1,
        );

        $Self->True(
            $ArticleID2,
            "Article #2 is created - $ArticleID2",
        );

        # Account some time to the ticket.
        my $Success = $TicketObject->TicketAccountTime(
            TicketID  => $TicketID,
            ArticleID => $ArticleID,
            TimeUnit  => '7',
            UserID    => 1,
        );
        $Self->True(
            $Success,
            "Time accounted to the ticket",
        );

        # Login as test customer user.
        $Selenium->Login(
            Type     => 'Customer',
            User     => $TestCustomerUserLogin,
            Password => $TestCustomerUserLogin,
        );

        my $ScriptAlias = $Kernel::OM->Get('Kernel::Config')->Get('ScriptAlias');

        $Selenium->VerifiedGet("${ScriptAlias}customer.pl?Action=CustomerTicketZoom;TicketNumber=123123123");

        $Self->True(
            index( $Selenium->get_page_source(), 'No Permission' ) > -1,
            "No permission message for tickets the user may not see, even if they don't exist.",
        );

        $Selenium->VerifiedGet("${ScriptAlias}customer.pl?Action=CustomerTicketZoom;TicketNumber=");

        $Self->True(
            index( $Selenium->get_page_source(), 'Need TicketID' ) > -1,
            "Error message for missing TicketID/TicketNumber.",
        );

        $Selenium->VerifiedGet("${ScriptAlias}customer.pl?Action=CustomerTicketOverview");

        # Search for new created ticket on CustomerTicketOverview screen.
        $Self->True(
            $Selenium->find_element("//a[contains(\@href, \'Action=CustomerTicketZoom;TicketNumber=$TicketNumber' )]"),
            "Ticket with ticket number $TicketNumber is found on screen"
        );

        # Check customer ticket zoom screen.
        $Selenium->find_element("//a[contains(\@href, \'Action=CustomerTicketZoom;TicketNumber=$TicketNumber' )]")
            ->VerifiedClick();

        # Check add page.
        for my $ID (
            qw(Messages FollowUp ZoomSidebar)
            )
        {
            $Selenium->WaitFor( JavaScript => "return typeof(\$) === 'function' && \$('#$ID').length" );
            my $Element = $Selenium->find_element( "#$ID", 'css' );
            $Element->is_enabled();
            $Element->is_displayed();
        }

        # Check ticket data.
        $Self->True(
            index( $Selenium->get_page_source(), $TicketNumber ) > -1,
            "Ticket number is $TicketNumber",
        );

        $Self->True(
            index( $Selenium->get_page_source(), $SubjectRandom ) > -1,
            "Subject is $SubjectRandom",
        );

        $Self->True(
            index( $Selenium->get_page_source(), $TextRandom ) > -1,
            "Article body is $TextRandom",
        );

        $Self->True(
            index( $Selenium->get_page_source(), 'Raw' ) > -1,
            "Queue is Raw",
        );

        # Accounted time should not be displayed.
        $Self->False(
            index( $Selenium->get_page_source(), '<span class="Key">Accounted time:</span>' ) > -1,
            "Accounted time is not displayed",
        );

        # Enable displaying accounted time.
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'Ticket::Frontend::CustomerTicketZoom###ZoomTimeDisplay',
            Value => 1
        );

        # Reload the page.
        $Selenium->VerifiedGet("${ScriptAlias}customer.pl?Action=CustomerTicketZoom;TicketNumber=$TicketNumber");

        my $NumberOfExpandedArticles = $Selenium->execute_script(
            'return $("ul#Messages li.Visible").length'
        );
        $Self->Is(
            $NumberOfExpandedArticles,
            1,
            'Make sure that only one article is expanded.'
        );

        # Enable expanding.
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'Ticket::Frontend::CustomerTicketZoom###CustomerZoomExpand',
            Value => 1,
        );

        # Reload the page.
        $Selenium->VerifiedGet("${ScriptAlias}customer.pl?Action=CustomerTicketZoom;TicketNumber=$TicketNumber");

        $NumberOfExpandedArticles = $Selenium->execute_script(
            'return $("ul#Messages li.Visible").length'
        );
        $Self->Is(
            $NumberOfExpandedArticles,
            2,
            'Make sure that all articles are expanded.'
        );

        # Accounted time should now be displayed.
        $Self->True(
            index( $Selenium->get_page_source(), '<span class="Key">Accounted time:</span>' ) > -1,
            "Accounted time is displayed",
        );

        # Check reply button.
        $Selenium->find_element("//a[contains(\@id, \'ReplyButton' )]")->click();
        $Selenium->WaitFor( JavaScript => "return typeof(\$) === 'function' && \$('#FollowUp.Visible').length" );
        $Selenium->find_element("//button[contains(\@value, \'Submit' )]");

        # Change the ticket state to 'merged'.
        my $Merged = $TicketObject->TicketStateSet(
            State    => 'merged',
            TicketID => $TicketID,
            UserID   => 1,
        );
        $Self->True(
            $Merged,
            "Ticket state changed to 'merged'",
        );

        # Refresh the page.
        $Selenium->VerifiedRefresh();

        # Check if reply button is missing in merged ticket (bug#7301).
        $Self->Is(
            $Selenium->execute_script('return $("a#ReplyButton").length'),
            0,
            "Reply button not found",
        );

        # Check if print button exists on the screen.
        $Self->Is(
            $Selenium->execute_script('return $("a[href*=\'Action=CustomerTicketPrint\']").length'),
            1,
            "Print button is found",
        );

        # Clean up test data from the DB.
        $Success = $TicketObject->TicketDelete(
            TicketID => $TicketID,
            UserID   => 1,
        );

        # Ticket deletion could fail if apache still writes to ticket history. Try again in this case.
        if ( !$Success ) {
            sleep 3;
            $Success = $TicketObject->TicketDelete(
                TicketID => $TicketID,
                UserID   => 1,
            );
        }
        $Self->True(
            $Success,
            "Ticket is deleted - $TicketID",
        );

        # Make sure the cache is correct.
        $Kernel::OM->Get('Kernel::System::Cache')->CleanUp( Type => 'Ticket' );
    }
);

1;
