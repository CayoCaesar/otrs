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
        my $UserObject   = $Kernel::OM->Get('Kernel::System::User');
        my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

        # Do not check email addresses and mx records.
        # Change settings in both runtime and disk configuration.
        for my $Key (qw(CheckEmailAddresses CheckMXRecord)) {
            $Helper->ConfigSettingChange(
                Valid => 1,
                Key   => $Key,
                Value => 0,
            );
        }

        # Override FirstnameLastnameOrder setting to check if it is taken into account.
        #   (see bug#12554 for more information).
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'FirstnameLastnameOrder',
            Value => 1,
        );

        # Create test user.
        my $TestUserLogin = $Helper->TestUserCreate(
            Groups => [ 'admin', 'users' ],
        ) || die "Did not get test user";

        # Get test user ID.
        my $TestUserID = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
            UserLogin => $TestUserLogin,
        );

        my $RandomID = $Helper->GetRandomID();

        # Create test queue.
        my $QueueName = 'Queue' . $RandomID;
        my $QueueID   = $Kernel::OM->Get('Kernel::System::Queue')->QueueAdd(
            Name            => $QueueName,
            ValidID         => 1,
            GroupID         => 1,
            SystemAddressID => 1,
            SalutationID    => 1,
            SignatureID     => 1,
            Comment         => 'Selenium Queue',
            UserID          => $TestUserID,
        );
        $Self->True(
            $QueueID,
            "QueueAdd() successful for test $QueueName - ID $QueueID",
        );

        # Create test users.
        my @UserIDs;
        my %Users;
        for my $User ( 1 .. 15 ) {
            my $UserFirstname = 'Firstname' . $User;
            my $UserLastname  = 'Lastname' . $User;
            my $UserLogin     = 'test' . $RandomID . $User;
            my $UserID        = $UserObject->UserAdd(
                UserFirstname => $UserFirstname,
                UserLastname  => $UserLastname,
                UserLogin     => $UserLogin,
                UserEmail     => "test$RandomID$User\@example.com",
                ValidID       => 1,
                ChangeUserID  => $TestUserID,
            );
            $Self->True(
                $UserID,
                "User is created - $UserID",
            );

            push @UserIDs, $UserID;

            # Store user full name for later comparison.
            my %UserData = $UserObject->GetUserData(
                UserID => $UserID,
            );
            $Users{$UserID} = $UserData{UserFullname};
        }

        # Create test tickets.
        my @TicketIDs;
        my @TicketNumbers;
        for my $Count ( 0 .. 14 ) {
            my $TicketNumber = $TicketObject->TicketCreateNumber();
            my $TicketID     = $TicketObject->TicketCreate(
                TN            => $TicketNumber,
                Title         => 'Some Ticket Title',
                Queue         => $QueueName,
                Lock          => 'unlock',
                Priority      => '3 normal',
                State         => 'new',
                CustomerID    => 'TestCustomer',
                CustomerUser  => 'customer@example.com',
                OwnerID       => $UserIDs[$Count],
                ResponsibleID => $UserIDs[$Count],
                UserID        => $TestUserID,
            );

            $Self->True(
                $TicketID,
                "Ticket is created - $TicketID"
            );

            push @TicketIDs,     $TicketID;
            push @TicketNumbers, $TicketNumber;
        }

        # Reverse sort test ticket numbers for test purposes.
        my @SortTicketNumbers = reverse sort @TicketNumbers;

        # Login as test user.
        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        # Go to status open view, overview small, default sort is Age, default order is Down.
        my $ScriptAlias = $Kernel::OM->Get('Kernel::Config')->Get('ScriptAlias');
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AgentTicketStatusView");

        # Set filter to test queue.
        $Selenium->find_element("//a[contains(\@title, \'Queue, filter not active\' )]")->click();
        $Selenium->WaitFor(
            JavaScript =>
                "return typeof(\$) === 'function' && \$('#ColumnFilterQueue option[value=\"$QueueID\"]').length;"
        );
        $Selenium->execute_script(
            "\$('#ColumnFilterQueue').val('$QueueID').trigger('redraw.InputField').trigger('change');"
        );
        $Selenium->WaitFor(
            JavaScript => "return typeof(\$) === 'function' && \$('li.ContextSettings.RemoveFilters').length"
        );

        # Set tickets per page to 10.
        $Selenium->find_element( "#ShowContextSettingsDialog", 'css' )->click();
        $Selenium->WaitFor(
            JavaScript => 'return $(".Dialog.Modal #UserTicketOverviewSmallPageShown").length'
        );
        $Selenium->execute_script(
            "\$('#UserTicketOverviewSmallPageShown').val('10').trigger('redraw.InputField').trigger('change');"
        );

        # Move responsible from left to the right side.
        $Selenium->mouse_move_to_location(
            element => $Selenium->find_element( '//li[@data-fieldname="Responsible"]', 'xpath' ),
        );

        $Selenium->DragAndDrop(
            Element      => 'li[data-fieldname="Responsible"]',
            Target       => '#AssignedFields-DashboardAgentTicketStatusView',
            TargetOffset => {
                X => 185,
                Y => 10,
            },
        );

        $Selenium->find_element( "#DialogButton1", 'css' )->click();
        $Selenium->WaitFor(
            JavaScript => 'return !$(".Dialog.Modal").length'
        );

        # Sort by ticket number, order down.
        $Selenium->find_element("//a[contains(\@title, \'TicketNumber\' )]")->VerifiedClick();

        # Verify that ticket with highest ticket number is on 1st page and with lowest is not.
        $Self->True(
            index( $Selenium->get_page_source(), $SortTicketNumbers[14] ) == -1,
            "First page - $SortTicketNumbers[14] - found on screen"
        );
        $Self->True(
            index( $Selenium->get_page_source(), $SortTicketNumbers[0] ) > -1,
            "First page - $SortTicketNumbers[0] - not found on screen"
        );

        # Switch to 2nd page to test pagination.
        $Selenium->find_element( "#AgentTicketStatusViewPage2", 'css' )->VerifiedClick();

        # Verify that ticket with lowest ticket number is on 2nd page and with highest is not.
        $Self->True(
            index( $Selenium->get_page_source(), $SortTicketNumbers[0] ) == -1,
            "Second page - $SortTicketNumbers[0] - found on screen"
        );
        $Self->True(
            index( $Selenium->get_page_source(), $SortTicketNumbers[14] ) > -1,
            "Second page - $SortTicketNumbers[14] - not found on screen"
        );

        $Selenium->VerifiedRefresh();

        # Test if filters are still stored.
        $Self->True(
            index( $Selenium->get_page_source(), $SortTicketNumbers[0] ) == -1,
            "After page refresh - $SortTicketNumbers[0] - found on screen"
        );
        $Self->True(
            index( $Selenium->get_page_source(), $SortTicketNumbers[14] ) > -1,
            "After page refresh - $SortTicketNumbers[14] - not found on screen"
        );

        # Check if owner and responsible columns are sorted by full names instead of IDs
        #   (see bug#4439 for more information).
        for my $Column (qw(Responsible Owner)) {

            # Sort by column, order down.
            $Selenium->find_element("//a[\@name='OverviewControl'][contains(\@title, '$Column')]")->VerifiedClick();

            # Check user with 9 in name is shown and with 1 is not present.
            $Self->True(
                index( $Selenium->get_page_source(), $Users{ $UserIDs[0] } ) == -1,
                "Column $Column - order Down - $Users{ $UserIDs[0] } - not found on screen"
            );
            $Self->True(
                index( $Selenium->get_page_source(), $Users{ $UserIDs[8] } ) > -1,
                "Column $Column - order Down - $Users{ $UserIDs[8] } - found on screen"
            );

            # Sort by column, order up.
            $Selenium->find_element("//a[\@name='OverviewControl'][contains(\@title, '$Column')]")->VerifiedClick();

            # Check user with 1 in name is shown and with 9 is not present.
            $Self->True(
                index( $Selenium->get_page_source(), $Users{ $UserIDs[0] } ) > -1,
                "Column $Column - order Up - $Users{ $UserIDs[0] } - found on screen"
            );
            $Self->True(
                index( $Selenium->get_page_source(), $Users{ $UserIDs[8] } ) == -1,
                "Column $Column - order Up - $Users{ $UserIDs[8] } - not found on screen"
            );

            # Sort by column, order down, for the next iteration.
            $Selenium->find_element("//a[\@name='OverviewControl'][contains(\@title, '$Column')]")->VerifiedClick();
        }

        # Remove all filters.
        $Selenium->find_element( "li.ContextSettings.RemoveFilters a", 'css' )->VerifiedClick();

        # Delete test tickets.
        my $Success;
        for my $TicketID (@TicketIDs) {
            $Success = $TicketObject->TicketDelete(
                TicketID => $TicketID,
                UserID   => $TestUserID,
            );
            $Self->True(
                $Success,
                "Delete ticket - $TicketID"
            );
        }

        my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

        # Delete test users.
        for my $UserID (@UserIDs) {
            $Success = $DBObject->Do(
                SQL => "DELETE FROM user_preferences WHERE user_id = $UserID",
            );
            $Self->True(
                $Success,
                "Delete user preferences - $UserID",
            );
            $Success = $DBObject->Do(
                SQL => "DELETE FROM users WHERE id = $UserID",
            );
            $Self->True(
                $Success,
                "Delete user - $UserID",
            );
        }

        # Delete test queue.
        $Success = $DBObject->Do(
            SQL => "DELETE FROM queue WHERE id = $QueueID",
        );
        $Self->True(
            $Success,
            "Delete queue - $QueueID",
        );

        my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');

        # Make sure cache is correct.
        for my $Cache (qw( Ticket Queue User )) {
            $CacheObject->CleanUp( Type => $Cache );
        }
    },
);

1;
