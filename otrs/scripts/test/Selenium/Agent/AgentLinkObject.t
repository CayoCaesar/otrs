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

        # Set link object view mode to simple.
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'LinkObject::ViewMode',
            Value => 'Simple',
        );

        # Set Ticket::SubjectSize.
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'Ticket::SubjectSize',
            Value => '60',
        );

        # Disable Ticket::ArchiveSystem.
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'Ticket::ArchiveSystem',
            Value => 0,
        );

        # Create test user.
        my $TestUserLogin = $Helper->TestUserCreate(
            Groups => [ 'admin', 'users' ],
        ) || die "Did not get test user";

        # Get test user ID.
        my $TestUserID = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
            UserLogin => $TestUserLogin,
        );

        # Create test tickets.
        my @TicketIDs;
        my @TicketNumbers;
        for my $Ticket ( 1 .. 3 ) {
            my $TicketNumber = $TicketObject->TicketCreateNumber();
            my $TicketID     = $TicketObject->TicketCreate(
                TN           => $TicketNumber,
                Title        => 'Some Ticket Title',
                Queue        => 'Raw',
                Lock         => 'unlock',
                Priority     => '3 normal',
                State        => 'new',
                CustomerID   => '123465',
                CustomerUser => 'customer@example.com',
                OwnerID      => $TestUserID,
                UserID       => $TestUserID,
            );
            $Self->True(
                $TicketID,
                "Created Ticket ID $TicketID - TN $TicketNumber",
            );
            push @TicketIDs,     $TicketID;
            push @TicketNumbers, $TicketNumber;
        }

        # Login as test user.
        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        my $ScriptAlias = $Kernel::OM->Get('Kernel::Config')->Get('ScriptAlias');

        # Navigate to zoom view of created test ticket.
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AgentTicketZoom;TicketID=$TicketIDs[0]");

        # Force sub menus to be visible in order to be able to click one of the links.
        $Selenium->execute_script("\$('.Cluster ul ul').addClass('ForceVisible');");

        # Click on 'Link'.
        $Selenium->find_element("//a[contains(\@href, \'Action=AgentLinkObject;SourceObject=Ticket;' )]")->click();

        # Switch to link object window.
        $Selenium->WaitFor( WindowCount => 2 );
        my $Handles = $Selenium->get_window_handles();
        $Selenium->switch_to_window( $Handles->[1] );
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("body").length' );
        $Selenium->execute_script("\$('#SubmitSearch').click();");

        $Selenium->WaitFor( AlertPresent => 1 );
        $Selenium->accept_alert();

        # Enable Ticket::ArchiveSystem.
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'Ticket::ArchiveSystem',
            Value => 1,
        );

        # Search for second created test ticket
        $Selenium->find_element(".//*[\@id='SEARCH::TicketNumber']")->send_keys( $TicketNumbers[1] );
        $Selenium->find_element( '#SubmitSearch', 'css' )->VerifiedClick();

        # Link created test tickets.
        $Selenium->find_element("//input[\@value='$TicketIDs[1]'][\@type='checkbox']")->click();
        $Selenium->WaitFor(
            JavaScript => "return \$('input[value=$TicketIDs[1]][type=checkbox]:checked').length"
        );
        $Selenium->execute_script(
            "\$('#TypeIdentifier').val('ParentChild::Target').trigger('redraw.InputField').trigger('change');"
        );
        $Selenium->find_element("//button[\@type='submit'][\@name='AddLinks']")->click();

        # Search for third created test ticket.
        $Selenium->find_element(".//*[\@id='SEARCH::TicketNumber']")->clear();
        $Selenium->find_element(".//*[\@id='SEARCH::TicketNumber']")->send_keys( $TicketNumbers[2] );
        $Selenium->find_element( '#SubmitSearch', 'css' )->VerifiedClick();

        # Link created test tickets.
        $Selenium->find_element("//input[\@value='$TicketIDs[2]'][\@type='checkbox']")->click();
        $Selenium->WaitFor(
            JavaScript => "return \$('input[value=$TicketIDs[2]][type=checkbox]:checked').length"
        );
        $Selenium->execute_script(
            "\$('#TypeIdentifier').val('Normal::Source').trigger('redraw.InputField').trigger('change');"
        );
        $Selenium->find_element("//button[\@type='submit'][\@name='AddLinks']")->VerifiedClick();

        $Selenium->find_element( "#LinkAddCloseLink", 'css' )->click();

        # Switch back to the main window.
        $Selenium->WaitFor( WindowCount => 1 );
        $Handles = $Selenium->get_window_handles();
        $Selenium->switch_to_window( $Handles->[0] );

        # Refresh agent ticket zoom.
        $Selenium->VerifiedRefresh();

        # Verify that parent test tickets is linked with child test ticket.
        $Self->True(
            index( $Selenium->get_page_source(), 'Child' ) > -1,
            "Child - found",
        ) || die;
        $Self->True(
            index( $Selenium->get_page_source(), "T:" . $TicketNumbers[1] ) > -1,
            "TicketNumber $TicketNumbers[1] - found",
        ) || die;

        # Verify that third test tickets is linked with the first ticket.
        $Self->True(
            index( $Selenium->get_page_source(), 'Normal' ) > -1,
            "Normal - found",
        ) || die;
        $Self->True(
            index( $Selenium->get_page_source(), "T:" . $TicketNumbers[2] ) > -1,
            "TicketNumber $TicketNumbers[2] - found",
        ) || die;

        # Click on child ticket.
        $Selenium->find_element("//a[contains(\@href, \'Action=AgentTicketZoom;TicketID=$TicketIDs[1]' )]")
            ->VerifiedClick();

        # Verify that child test ticket is linked with parent test ticket.
        $Self->True(
            index( $Selenium->get_page_source(), 'Parent' ) > -1,
            "Parent - found",
        ) || die;
        $Self->True(
            index( $Selenium->get_page_source(), "T:" . $TicketNumbers[0] ) > -1,
            "TicketNumber $TicketNumbers[0] - found",
        ) || die;

        # Test ticket title length in complex view for linked tickets, see bug #11511.
        # Set link object view mode to complex.
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'LinkObject::ViewMode',
            Value => 'Complex',
        );

        # Update test ticket title to more then 50 characters (there is 65).
        my $LongTicketTitle = 'This is long test ticket title with more then 50 characters in it';

        # Ticket::SubjectSize is set to 60 at the beginning of test.
        my $ShortTitle = substr( $LongTicketTitle, 0, 57 ) . "...";
        my $Success = $TicketObject->TicketTitleUpdate(
            Title    => $LongTicketTitle,
            TicketID => $TicketIDs[1],
            UserID   => 1,
        );
        $Self->True(
            $Success,
            "Updated ticket title - $TicketIDs[1]"
        );

        # Navigate to AgentTicketZoom screen.
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AgentTicketZoom;TicketID=$TicketIDs[0]");

        # Check for updated ticket title in linked tickets complex view table.
        $Self->True(
            index( $Selenium->get_page_source(), $LongTicketTitle ) > -1,
            "$LongTicketTitle - found in AgentTicketZoom complex view mode",
        ) || die;

        # Check for "default" visible columns in the Linked Ticket widget.
        $Self->Is(
            $Selenium->execute_script(
                "return \$('#WidgetTicket .DataTable thead tr th:nth-child(1)').text();"
            ),
            ' Ticket# ',
            'Default 1st column name',
        );
        $Self->Is(
            $Selenium->execute_script(
                "return \$('#WidgetTicket .DataTable thead tr th:nth-child(2)').text();"
            ),
            ' Title ',
            'Default 2nd column name',
        );
        $Self->Is(
            $Selenium->execute_script(
                "return \$('#WidgetTicket .DataTable thead tr th:nth-child(3)').text();"
            ),
            ' State ',
            'Default 3th column name',
        );
        $Self->Is(
            $Selenium->execute_script(
                "return \$('#WidgetTicket .DataTable thead tr th:nth-child(4)').text();"
            ),
            ' Queue ',
            'Default 4th column name',
        );
        $Self->Is(
            $Selenium->execute_script(
                "return \$('#WidgetTicket .DataTable thead tr th:nth-child(5)').text();"
            ),
            ' Created ',
            'Default 5th column name',
        );

        $Self->Is(
            $Selenium->execute_script(
                "return \$('#WidgetTicket .DataTable thead tr th:nth-child(6)').text();"
            ),
            ' Linked as ',
            'Default 6th column name',
        );

        # Click on the delete link in the of the third test ticket.
        $Selenium->find_element(
            "a.InstantLinkDelete[data-delete-link-sourceobject='Ticket'][data-delete-link-sourcekey='$TicketIDs[2]']",
            'css'
        )->click();
        $Selenium->WaitFor( AlertPresent => 1 );
        $Selenium->accept_alert();

        $Selenium->WaitFor(
            JavaScript =>
                "return typeof(\$) === 'function' && \$('.DataTable a[title*=$TicketNumbers[2]]').length === 0;"
        );

        # Check that link to third test ticket has been deleted.
        $Self->False(
            $Selenium->execute_script("return \$('.DataTable a[title*=$TicketNumbers[2]]').length"),
            "TicketNumber $TicketNumbers[2] - not found",
        ) || die;

        # Show ActionMenu - usually this is done when user hovers, however it's not possible to simulate this behavior.
        $Selenium->execute_script(
            "\$('#WidgetTicket .ActionMenu').show();"
        );

        # Check if column settings button is available in the Linked Ticket widget.
        $Selenium->find_element( 'a#linkobject-Ticket-toggle', 'css' )->click();

        # Wait for the complete widget to be fully slided in all the way down to the submit button.
        $Selenium->WaitFor(
            JavaScript =>
                'return typeof($) === "function" && $("#linkobject-Ticket_submit:visible").length;'
        );

        sleep 1;

        # TODO: remove limitation to firefox.
        if ( $Selenium->{browser_name} eq 'firefox' ) {
            $Self->True(
                1,
                "TODO: DragAndDrop is currently disabled in Firefox",
            );
        }
        else {

            # Remove Age from left side, and put it to the right side.
            $Selenium->DragAndDrop(
                Element      => '#WidgetTicket #AvailableField-linkobject-Ticket li[data-fieldname="Age"]',
                Target       => '#AssignedFields-linkobject-Ticket',
                TargetOffset => {
                    X => 185,
                    Y => 10,
                },
            );

            # Remove State from right side, and put it to the left side.
            $Selenium->DragAndDrop(
                Element      => '#WidgetTicket #AssignedFields-linkobject-Ticket li[data-fieldname="State"]',
                Target       => '#AvailableField-linkobject-Ticket',
                TargetOffset => {
                    X => 185,
                    Y => 10,
                },
            );

            # Put TicketNumber at the end.
            $Selenium->DragAndDrop(
                Element      => '#WidgetTicket #AssignedFields-linkobject-Ticket li[data-fieldname="TicketNumber"]',
                Target       => '#AvailableField-linkobject-Ticket',
                TargetOffset => {
                    X => 185,
                    Y => 10,
                },
            );
            $Selenium->DragAndDrop(
                Element      => '#WidgetTicket #AvailableField-linkobject-Ticket li[data-fieldname="TicketNumber"]',
                Target       => '#AssignedFields-linkobject-Ticket',
                TargetOffset => {
                    X => 185,
                    Y => 90,
                },
            );

            # Save.
            $Selenium->find_element( '#linkobject-Ticket_submit', 'css' )->click();

            # Wait for AJAX.
            $Selenium->WaitFor(
                JavaScript =>
                    'return typeof($) === "function" && $("#WidgetTicket .DataTable:visible").length;'
            );

            # Check for "updated" visible columns in the Linked Ticket widget.
            $Self->Is(
                $Selenium->execute_script(
                    "return \$('#WidgetTicket .DataTable thead tr th:nth-child(1)').text();"
                ),
                ' Age ',
                'Updated 1st column name',
            );
            $Self->Is(
                $Selenium->execute_script(
                    "return \$('#WidgetTicket .DataTable thead tr th:nth-child(2)').text();"
                ),
                ' Title ',
                'Updated 2nd column name',
            );
            $Self->Is(
                $Selenium->execute_script(
                    "return \$('#WidgetTicket .DataTable thead tr th:nth-child(3)').text();"
                ),
                ' Queue ',
                'Updated 3th column name',
            );
            $Self->Is(
                $Selenium->execute_script(
                    "return \$('#WidgetTicket .DataTable thead tr th:nth-child(4)').text();"
                ),
                ' Created ',
                'Updated 4th column name',
            );
            $Self->Is(
                $Selenium->execute_script(
                    "return \$('#WidgetTicket .DataTable thead tr th:nth-child(5)').text();"
                ),
                ' Ticket# ',
                'Updated 5th column name',
            );

            $Self->Is(
                $Selenium->execute_script(
                    "return \$('#WidgetTicket .DataTable thead tr th:nth-child(6)').text();"
                ),
                ' Linked as ',
                'Updated 6th column name',
            );

            # Verify there is button to delete link, even though TicketNumber is not in the first column.
            # See bug#13703 (https://bugs.otrs.org/show_bug.cgi?id=13703).
            $Self->True(
                $Selenium->execute_script("return \$('.InstantLinkDelete').length"),
                "Delete link button is present."
            );

            # Show ActionMenu - usually this is done when user hovers,
            # however it's not possible to simulate this behavior.
            $Selenium->execute_script(
                "\$('#WidgetTicket .ActionMenu').show();"
            );

            # Check if column settings button is available in the Linked Ticket widget.
            $Selenium->find_element( 'a#linkobject-Ticket-toggle', 'css' )->click();

            # Wait for the complete widget to be fully slided in all the way down to the submit button.
            $Selenium->WaitFor(
                JavaScript =>
                    'return typeof($) === "function" && $("#linkobject-Ticket_submit:visible").length;'
            );

            sleep 1;

            # Remove TicketNumber from right side, and put it to the left side.
            $Selenium->DragAndDrop(
                Element      => '#WidgetTicket #AssignedFields-linkobject-Ticket li[data-fieldname="TicketNumber"]',
                Target       => '#AvailableField-linkobject-Ticket',
                TargetOffset => {
                    X => 185,
                    Y => 10,
                },
            );

            # Save.
            $Selenium->find_element( '#linkobject-Ticket_submit', 'css' )->click();

            # Wait for AJAX.
            $Selenium->WaitFor(
                JavaScript =>
                    'return typeof($) === "function" && $("#WidgetTicket .DataTable:visible").length;'
            );

            # Check if TicketNumber is still there.
            $Self->Is(
                $Selenium->execute_script(
                    "return \$('#WidgetTicket .DataTable thead tr th:nth-child(1)').text();"
                ),
                ' Ticket# ',
                'Ticket# is still there.',
            );
        }

        # Force sub menus to be visible in order to be able to click one of the links.
        $Selenium->execute_script("\$('.Cluster ul ul').addClass('ForceVisible');");

        # Click on 'Link'.
        $Selenium->find_element("//a[contains(\@href, \'Action=AgentLinkObject;SourceObject=Ticket;' )]")->click();

        # Switch to link object window.
        $Selenium->WaitFor( WindowCount => 2 );
        $Handles = $Selenium->get_window_handles();
        $Selenium->switch_to_window( $Handles->[1] );
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("body").length' );

        # Switch to manage links tab.
        $Selenium->find_element("//a[contains(\@href, \'#ManageLinks' )]")->click();

        # Wait for the manage links tab to show up.
        $Selenium->WaitFor(
            JavaScript =>
                'return typeof($) === "function" && $("div[data-id=ManageLinks]:visible").length && parseInt($("div[data-id=ManageLinks]").css("opacity"), 10) == 1'
        );

        # Check for long ticket title in LinkDelete screen.
        # This one is displayed on hover.
        $Self->True(
            index( $Selenium->get_page_source(), "title=\"$LongTicketTitle\"" ) > -1,
            "\"title=$LongTicketTitle\" - found in LinkDelete screen - which is displayed on hover",
        ) || die;

        # Check for short ticket title in LinkDelete screen.
        $Self->True(
            index( $Selenium->get_page_source(), $ShortTitle ) > -1,
            "$ShortTitle - found in LinkDelete screen",
        ) || die;

        # Select all links.
        $Selenium->find_element( ".Tabs div.Active .SelectAll", "css" )->click();

        # Make sure it's selected.
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("#SelectAllLinks0:checked").length' );

        # Click on delete links.
        $Selenium->find_element( ".Tabs div.Active .CallForAction", "css" )->VerifiedClick();

        # Switch to add links tab.
        $Selenium->find_element("//a[contains(\@href, \'#AddNewLinks' )]")->click();

        # Wait for the add new links tab to show up.
        $Selenium->WaitFor(
            JavaScript =>
                'return typeof($) === "function" && $("div[data-id=AddNewLinks]:visible").length && parseInt($("div[data-id=AddNewLinks]").css("opacity"), 10) == 1'
        );

        my $SuccessArchived = $TicketObject->TicketArchiveFlagSet(
            ArchiveFlag => 'y',
            TicketID    => $TicketIDs[1],
            UserID      => $TestUserID,
        );

        $Self->True(
            $SuccessArchived,
            "Check if 2nd ticket is archived successfully."
        );

        # Check if there is "Search archive" drop-down.
        $Self->True(
            $Selenium->execute_script(
                "return \$('#SEARCH\\\\:\\\\:ArchiveID').length"
            ),
            'Search archive drop-down present.',
        );

        # Search for 2nd ticket.
        $Selenium->find_element(".//*[\@id='SEARCH::TicketNumber']")->send_keys( $TicketNumbers[1] );
        $Selenium->find_element( '#SubmitSearch', 'css' )->VerifiedClick();

        # Make sure there are no results.
        $Self->False(
            $Selenium->execute_script(
                "return \$('#WidgetTicket').length"
            ),
            'No result.',
        );

        # Click on the Archive search drop-down.
        $Selenium->execute_script(
            "\$('#SEARCH\\\\:\\\\:ArchiveID').val('ArchivedTickets').trigger('redraw.InputField').trigger('change');"
        );

        $Selenium->find_element( "#SubmitSearch", "css" )->VerifiedClick();

        # Wait till search is loaded.
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("#SelectAllLinks0").length' );

        # Link again.
        $Selenium->find_element( ".Tabs div.Active .SelectAll", "css" )->click();
        $Selenium->find_element( "#AddLinks",                   "css" )->VerifiedClick();
        $Selenium->find_element( "#LinkAddCloseLink",           "css" )->click();

        # Switch back to the main window.
        $Selenium->WaitFor( WindowCount => 1 );
        $Handles = $Selenium->get_window_handles();
        $Selenium->switch_to_window( $Handles->[0] );

        # Make sure they are really linked.
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("#WidgetTicket").length' );
        $Selenium->find_element( "#WidgetTicket", "css" );

        # Create Calendar.
        my $CalendarObject    = $Kernel::OM->Get('Kernel::System::Calendar');
        my $AppointmentObject = $Kernel::OM->Get('Kernel::System::Calendar::Appointment');
        my $RandomID          = $Helper->GetRandomID();
        my %Calendar          = $CalendarObject->CalendarCreate(
            CalendarName => "Calendar-$RandomID",
            Color        => '#3A87AD',
            GroupID      => 1,
            UserID       => 1,
        );
        $Self->True(
            $Calendar{CalendarID},
            "CalendarID $Calendar{CalendarID} is created.   "
        );

        # Create Appointment.
        my $StartTimeObject = $Kernel::OM->Create('Kernel::System::DateTime');
        $StartTimeObject->Subtract(
            Weeks => 1,
        );
        my $EndTimeObject = $StartTimeObject->Clone();
        $EndTimeObject->Add(
            Hours => 2,
        );

        my $AppointmentID = $AppointmentObject->AppointmentCreate(
            CalendarID  => $Calendar{CalendarID},
            Title       => 'Test Appointment Calendar',
            Description => 'Calendar description',
            Location    => 'Straubing',
            StartTime   => $StartTimeObject->ToString(),
            EndTime     => $EndTimeObject->ToString(),
            UserID      => 1,
            TimezoneID  => 0,
        );
        $Self->True(
            $AppointmentID,
            "AppointmentID $AppointmentID is created.",
        );

        # Force sub menus to be visible in order to be able to click one of the links.
        $Selenium->execute_script("\$('.Cluster ul ul').addClass('ForceVisible');");

        # Click on 'Link'.
        $Selenium->find_element("//a[contains(\@href, \'Action=AgentLinkObject;SourceObject=Ticket;' )]")->click();

        # Switch to link object window.
        $Selenium->WaitFor( WindowCount => 2 );
        $Handles = $Selenium->get_window_handles();
        $Selenium->switch_to_window( $Handles->[1] );
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("body").length' );

        # Select 'Appointment' as link type.
        $Selenium->execute_script(
            "\$('#TargetIdentifier').val('Appointment').trigger('redraw.InputField').trigger('change');"
        );
        $Selenium->WaitFor(
            JavaScript => 'return typeof($) === "function" && $("#SEARCH\\\\:\\\\:AppointmentCalendarID").length'
        );

        # Select created Calendar as filer.
        $Selenium->execute_script(
            "\$('#SEARCH\\\\:\\\\:AppointmentCalendarID').val('$Calendar{CalendarID}').trigger('redraw.InputField').trigger('change');"
        );
        $Selenium->find_element( '#SubmitSearch', 'css' )->VerifiedClick();

        # Link created test appointment.
        $Selenium->find_element("//input[\@value='$AppointmentID'][\@type='checkbox']")->click();
        $Selenium->WaitFor(
            JavaScript => "return \$('input[value=$AppointmentID][type=checkbox]:checked').length"
        );

        $Selenium->find_element( "#AddLinks",         "css" )->VerifiedClick();
        $Selenium->find_element( "#LinkAddCloseLink", "css" )->click();

        # Switch back to the main window.
        $Selenium->WaitFor( WindowCount => 1 );
        $Handles = $Selenium->get_window_handles();
        $Selenium->switch_to_window( $Handles->[0] );

        # Verify column settings button is available for both Ticket and Appointment link object widget.
        # See bug#13702 (https://bugs.otrs.org/show_bug.cgi?id=13702);
        for my $LinkObject (qw(Appointment Ticket)) {
            $Selenium->WaitFor(
                JavaScript =>
                    "return typeof(\$) === 'function' && \$('#Widget$LinkObject .ActionMenu').length;"
            );
            $Selenium->execute_script(
                "\$('#Widget$LinkObject .ActionMenu').show();"
            );
            $Selenium->WaitFor(
                JavaScript =>
                    "return \$('a#linkobject-$LinkObject-toggle:visible').length;"
            );
            $Selenium->execute_script(
                "\$('a#linkobject-$LinkObject-toggle').click();"
            );
            sleep 2;

            $Selenium->WaitFor(
                JavaScript =>
                    "return \$('#linkobject-${LinkObject}_submit:visible').length;"
            );
            $Self->True(
                $Selenium->execute_script(
                    "return \$('#linkobject-${LinkObject}_submit').length;"
                ),
                "$LinkObject link object widget setting is working."
            );
        }

        # Delete created test tickets.
        for my $TicketID (@TicketIDs) {
            $Success = $TicketObject->TicketDelete(
                TicketID => $TicketID,
                UserID   => $TestUserID,
            );
            $Self->True(
                $Success,
                "TicketID $TicketID is deleted.",
            );
        }

        # Delete created test Appointment.
        $Success = $AppointmentObject->AppointmentDelete(
            AppointmentID => $AppointmentID,
            UserID        => 1,
        );
        $Self->True(
            $Success,
            "AppointmentID $AppointmentID is deleted."
        );

        # Delete created test Calendar.
        $Success = $Kernel::OM->Get('Kernel::System::DB')->Do(
            SQL => "DELETE FROM calendar WHERE id = $Calendar{CalendarID}",
        );
        $Self->True(
            $Success,
            "CalendarID $Calendar{CalendarID} is deleted.",
        );
    }
);

1;
