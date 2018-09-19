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

        my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

        # Do not check RichText.
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'Frontend::RichText',
            Value => 0
        );

        # Enable Type feature.
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'Ticket::Type',
            Value => 1
        );

        my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

        my @DynamicFields = (
            {
                Name       => 'TestDropdownACLProcess',
                Label      => 'TestDropdownACLProcess',
                FieldOrder => 9990,
                FieldType  => 'Dropdown',
                ObjectType => 'Ticket',
                Config     => {
                    DefaultValue   => '',
                    Link           => '',
                    PossibleNone   => 0,
                    PossibleValues => {
                        a => 1,
                        b => 2,
                        c => 3,
                        d => 4,
                        e => 5,
                    },
                    TranslatableValues => 1,
                },
                Reorder => 1,
                ValidID => 1,
                UserID  => 1,
            },
        );

        my @DynamicFieldIDs;

        # Create test DynamicFields.
        for my $DynamicField (@DynamicFields) {

            my $DynamicFieldID = $DynamicFieldObject->DynamicFieldAdd(
                %{$DynamicField},
            );

            $Self->True(
                $DynamicFieldID,
                "Dynamic field $DynamicField->{Name} - ID $DynamicFieldID - created",
            );

            push @DynamicFieldIDs, $DynamicFieldID;
        }

        my $RandomID = $Helper->GetRandomID();

        # Create Ticket types.
        my $TypeObject = $Kernel::OM->Get('Kernel::System::Type');
        my @Types;
        for my $Count ( 1 .. 2 ) {
            my $TypeName = 'TicketType' . $Count . $RandomID;
            my $TypeID   = $TypeObject->TypeAdd(
                Name    => $TypeName,
                ValidID => 1,
                UserID  => 1,
            );
            $Self->True(
                $TypeID,
                "TypeID $TypeID is created"
            );
            push @Types, {
                ID   => $TypeID,
                Name => $TypeName,
            };
        }

        my $ACLObject = $Kernel::OM->Get('Kernel::System::ACL::DB::ACL');

        my @ACLs = (
            {
                Name           => '1-ACL' . $Helper->GetRandomID(),
                Comment        => 'Selenium Process ACL',
                Description    => 'Description',
                StopAfterMatch => 1,
                ConfigMatch    => {
                    Properties => {
                        'Frontend' => {
                            'Action' => [
                                'CustomerTicketProcess',
                            ],
                        },
                        'Ticket' => {
                            'Queue' => [
                                '[Not]Misc',
                            ],
                        },
                    },
                },
                ConfigChange => {
                    Possible => {
                        'Ticket' => {
                            'DynamicField_TestDropdownACLProcess' => [ 'a', 'b', 'c' ],
                        },
                    },
                },
                ValidID => 1,
                UserID  => 1,
            },
            {
                Name           => '2-ACL' . $Helper->GetRandomID(),
                Comment        => 'Selenium Process ACL',
                Description    => 'Description',
                StopAfterMatch => 1,
                ConfigMatch    => {
                    Properties => {
                        'Frontend' => {
                            'Action' => [
                                'CustomerTicketProcess',
                            ],
                        },
                        'Ticket' => {
                            'Queue' => [
                                'Misc',
                            ],
                        },
                    },
                },
                ConfigChange => {
                    Possible => {
                        'Ticket' => {
                            'DynamicField_TestDropdownACLProcess' => ['d'],
                        },
                    },
                },
                ValidID => 1,
                UserID  => 1,
            },
            {
                Name           => '3-ACL' . $RandomID,
                Comment        => 'Selenium Process ACL',
                Description    => 'Description',
                StopAfterMatch => 1,
                ConfigMatch    => {
                    Properties => {
                        'Ticket' => {
                            'DynamicField_TestDropdownACLProcess' => [
                                'c',
                            ],
                        },
                    },
                },
                ConfigChange => {
                    Possible => {
                        'Ticket' => {
                            'Type' => [ $Types[1]->{Name} ],
                        },
                    },
                },
                ValidID => 1,
                UserID  => 1,
            },
        );

        my @ACLIDs;

        for my $ACL (@ACLs) {

            my $ACLID = $ACLObject->ACLAdd(
                %{$ACL},
            );

            $Self->True(
                $ACLID,
                "ACLID $ACLID is created",
            );

            push @ACLIDs, $ACLID;
        }

        # Create test user and login.
        my $TestUserLogin = $Helper->TestUserCreate(
            Groups => ['admin'],
        ) || die "Did not get test user";

        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
        my $ScriptAlias  = $ConfigObject->Get('ScriptAlias');

        # Navigate to AdminACL and synchronize the created ACL's.
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AdminACL");
        $Selenium->find_element("//a[contains(\@href, 'Action=AdminACL;Subaction=ACLDeploy')]")->VerifiedClick();

        # Navigate to AdminProcessmanagement screen.
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AdminProcessManagement");

        # Import test Selenium Process.
        my $Location = $ConfigObject->Get('Home') . "/scripts/test/sample/ProcessManagement/CustomerTicketProcess.yml";
        $Selenium->find_element( "#FileUpload",                      'css' )->send_keys($Location);
        $Selenium->find_element( "#OverwriteExistingEntitiesImport", 'css' )->click();
        $Selenium->WaitFor(
            JavaScript => "return typeof(\$) === 'function' && !\$('#OverwriteExistingEntitiesImport:checked').length"
        );
        $Selenium->find_element("//button[\@value='Upload process configuration'][\@type='submit']")->VerifiedClick();
        $Selenium->find_element("//a[contains(\@href, \'Subaction=ProcessSync' )]")->VerifiedClick();

        # We have to allow a 1 second delay for Apache2::Reload to pick up the changed Process cache.
        sleep 1;

        # Get test user ID.
        my $TestUserID = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
            UserLogin => $TestUserLogin,
        );

        my @DeleteTicketIDs;

        # Get Process list.
        my $ProcessObject = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::Process');
        my $List          = $ProcessObject->ProcessList(
            UseEntities => 1,
            UserID      => $TestUserID,
        );

        # Get Process entity.
        my %ListReverse = reverse %{$List};
        my $ProcessName = "TestProcess";

        my $Process = $ProcessObject->ProcessGet(
            EntityID => $ListReverse{$ProcessName},
            UserID   => $TestUserID,
        );
        $Self->True(
            $Process,
            "Found TestProcess",
        );

        # Create test customer user and login.
        my $TestCustomerUserLogin = $Helper->TestCustomerUserCreate(
        ) || die "Did not get test customer user";

        $Selenium->Login(
            Type     => 'Customer',
            User     => $TestCustomerUserLogin,
            Password => $TestCustomerUserLogin,
        );

        # Navigate to customer ticket process directly via URL with pre-selected process and activity dialog
        # see bug#12850 ( https://bugs.otrs.org/show_bug.cgi?id=12850 ).
        $Selenium->VerifiedGet(
            "${ScriptAlias}customer.pl?Action=CustomerTicketProcess;ID=$ListReverse{$ProcessName};ActivityDialogEntityID=$Process->{Activities}->[0]"
        );
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && !$(".AJAXLoader:visible").length' );

        # Check pre-selected process is loaded correctly.
        $Self->True(
            $Selenium->find_element( "#Subject", 'css' ),
            "Pre-selected process with activity dialog via URL is successful"
        );

        # Navigate to CustomerTicketProcess screen.
        $Selenium->VerifiedGet("${ScriptAlias}customer.pl?Action=CustomerTicketProcess");

        # Create first scenario for test CustomerTicketProcess.
        $Selenium->execute_script(
            "\$('#ProcessEntityID').val('$ListReverse{$ProcessName}').trigger('redraw.InputField').trigger('change');"
        );
        $Selenium->WaitFor( JavaScript => "return typeof(\$) === 'function' && \$('#Subject').length" );

        # Check on DynamicField change - ACL restriction on Type field.
        # See bug#11512 (https://bugs.otrs.org/show_bug.cgi?id=11512).
        $Self->True(
            $Selenium->execute_script("return \$('#TypeID option:contains(\"$Types[0]->{Name}\")').length;"),
            "All Types are visible before ACL"
        );

        $Selenium->execute_script(
            "\$('#DynamicField_TestDropdownACLProcess').val('c').trigger('redraw.InputField').trigger('change');"
        );
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && !$(".AJAXLoader:visible").length' );

        $Self->False(
            $Selenium->execute_script("return \$('#TypeID option:contains(\"$Types[0]->{Name}\")').length;"),
            "DynamicField change - ACL restricted Types"
        );
        $Selenium->execute_script(
            "\$('#TypeID').val('$Types[1]->{ID}').trigger('redraw.InputField').trigger('change');"
        );
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && !$(".AJAXLoader:visible").length' );

        # Check further ACLs before the normal Process tests.
        $Self->Is(
            $Selenium->execute_script("return \$('#DynamicField_TestDropdownACLProcess > option').length;"),
            3,
            "DynamicField filtered options count",
        );

        $Selenium->execute_script("\$('#QueueID').val('4').trigger('redraw.InputField').trigger('change');");
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && !$(".AJAXLoader:visible").length' );

        $Self->Is(
            $Selenium->execute_script("return \$('#DynamicField_TestDropdownACLProcess > option').length;"),
            1,
            "DynamicField filtered options count",
        );

        my $SubjectRandom  = 'Subject' . $Helper->GetRandomID();
        my $ContentRandom  = 'Content' . $Helper->GetRandomID();
        my $AttachmentName = "StdAttachment-Test1.txt";
        my $AttachmentLocation
            = $Kernel::OM->Get('Kernel::Config')->Get('Home') . "/scripts/test/sample/StdAttachment/$AttachmentName";

        $Selenium->find_element( "#Subject",  'css' )->send_keys($SubjectRandom);
        $Selenium->find_element( "#RichText", 'css' )->send_keys($ContentRandom);
        $Selenium->execute_script("\$('#QueueID').val('2').trigger('redraw.InputField').trigger('change');");
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && !$(".AJAXLoader:visible").length' );

        # Hide DnDUpload and show input field.
        $Selenium->execute_script(
            "\$('.DnDUpload').css('display', 'none')"
        );
        $Selenium->execute_script(
            "\$('#FileUpload').css('display', 'block')"
        );

        $Selenium->find_element( "#FileUpload", 'css' )->send_keys($AttachmentLocation);
        $Selenium->WaitFor(
            JavaScript => 'return typeof($) === "function" && $("[class^=\'AttachmentDelete\']").length'
        );

        # Check if the header is visible on the page (bug#12543).
        my $Element = $Selenium->find_element(
            "//a[contains(\@href, \'Action=CustomerTicketOverview;Subaction=MyTickets' )]"
        );
        $Element->is_enabled();
        $Element->is_displayed();

        my $OTRSBusinessIsInstalled = $Kernel::OM->Get('Kernel::System::OTRSBusiness')->OTRSBusinessIsInstalled();
        my $OTRSSTORMIsInstalled    = $Kernel::OM->Get('Kernel::System::OTRSBusiness')->OTRSSTORMIsInstalled();

        my $FooterMessage;
        if ($OTRSSTORMIsInstalled) {
            $FooterMessage = 'STORM powered by OTRS';
        }
        elsif ($OTRSBusinessIsInstalled) {
            $FooterMessage = 'Powered by OTRS Business Solution';
        }
        else {
            $FooterMessage = 'Powered by ' . $ConfigObject->Get('Product');
        }

        $Self->True(
            index( $Selenium->get_page_source(), $FooterMessage ) > -1,
            "$FooterMessage found in footer on page (after attachment upload)",
        );

        $Selenium->find_element("//button[\@value='Submit'][\@type='submit']")->click();

        sleep 1;
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("div#MainBox").length;' );

        # Check for inputed values for first step in test Process ticket.
        $Self->True(
            index( $Selenium->get_page_source(), $SubjectRandom ) > -1,
            "$SubjectRandom found on page",
        ) || die;
        $Self->True(
            index( $Selenium->get_page_source(), $ProcessName ) > -1,
            "$ProcessName found on page",
        ) || die;
        $Self->True(
            index( $Selenium->get_page_source(), 'open' ) > -1,
            "Ticket open state found on page",
        ) || die;

        # Remember created ticket, to delete the ticket at the end of the test.
        my @TicketID = split( 'TicketID=', $Selenium->get_current_url() );
        push @DeleteTicketIDs, $TicketID[1];

        # Click on next step in Process ticket.
        $Selenium->find_element("//a[contains(\@href, \'ProcessEntityID=$ListReverse{$ProcessName}' )]")->click();

        $Selenium->WaitFor( WindowCount => 2 );
        my $Handles = $Selenium->get_window_handles();
        $Selenium->switch_to_window( $Handles->[1] );
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("#Subject").length;' );

        # For test scenario to complete, in next step we set ticket priority to 5 very high.
        $Selenium->execute_script("\$('#PriorityID').val('5').trigger('redraw.InputField').trigger('change');");
        $Selenium->find_element("//button[\@value='Submit'][\@type='submit']")->click();

        $Selenium->WaitFor( WindowCount => 1 );
        $Selenium->switch_to_window( $Handles->[0] );
        $Selenium->VerifiedRefresh();

        # Check for inputed values as final step in first scenario.
        $Self->True(
            index( $Selenium->get_page_source(), 'closed successful' ) > -1,
            "Ticket closed successful state found on page",
        );
        $Self->True(
            index( $Selenium->get_page_source(), '5 very high' ) > -1,
            "Ticket priority 5 very high found on page",
        );

        my $EndProcessMessage = "There are no dialogs available at this point in the process.";

        $Self->True(
            index( $Selenium->get_page_source(), $EndProcessMessage ) > -1,
            "$EndProcessMessage message found on page",
        );

        # Navigate to CustomerTicketProcess screen.
        $Selenium->VerifiedGet("${ScriptAlias}customer.pl?Action=CustomerTicketProcess");

        # Create second scenario for test CustomerTicketProcess.
        $Selenium->execute_script(
            "\$('#ProcessEntityID').val('$ListReverse{$ProcessName}').trigger('redraw.InputField').trigger('change');"
        );
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("#Subject").length;' );

        # In this scenario we just set ticket queue to junk to finish test.
        $Selenium->execute_script("\$('#QueueID').val('3').trigger('redraw.InputField').trigger('change');");
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && !$(".AJAXLoader:visible").length' );
        $Selenium->execute_script(
            "\$('#TypeID').val('$Types[1]->{ID}').trigger('redraw.InputField').trigger('change');"
        );
        $Selenium->find_element("//button[\@value='Submit'][\@type='submit']")->VerifiedClick();

        # Check if we are at the end of test Process ticket.
        $Self->True(
            index( $Selenium->get_page_source(), 'Junk' ) > -1,
            "Queue Junk found on page",
        );
        $Self->True(
            index( $Selenium->get_page_source(), $EndProcessMessage ) > -1,
            "$EndProcessMessage message found on page",
        );

        # Remember created ticket, to delete the ticket at the end of the test.
        @TicketID = split( 'TicketID=', $Selenium->get_current_url() );
        push @DeleteTicketIDs, $TicketID[1];

        my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

        for my $TicketID (@DeleteTicketIDs) {

            my $Success = $TicketObject->TicketDelete(
                TicketID => $TicketID,
                UserID   => $TestUserID,
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
                "TicketID $TicketID is deleted",
            );
        }

        # Clean up activities.
        my $ActivityObject       = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::Activity');
        my $ActivityDialogObject = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::ActivityDialog');
        for my $Item ( @{ $Process->{Activities} } ) {
            my $Activity = $ActivityObject->ActivityGet(
                EntityID            => $Item,
                UserID              => $TestUserID,
                ActivityDialogNames => 0,
            );

            # Clean up activity dialogs.
            for my $ActivityDialogItem ( @{ $Activity->{ActivityDialogs} } ) {
                my $ActivityDialog = $ActivityDialogObject->ActivityDialogGet(
                    EntityID => $ActivityDialogItem,
                    UserID   => $TestUserID,
                );

                # Delete test activity dialog.
                my $Success = $ActivityDialogObject->ActivityDialogDelete(
                    ID     => $ActivityDialog->{ID},
                    UserID => $TestUserID,
                );
                $Self->True(
                    $Success,
                    "ActivityDialog $ActivityDialog->{Name} is deleted",
                );
            }

            # Delete test activity.
            my $Success = $ActivityObject->ActivityDelete(
                ID     => $Activity->{ID},
                UserID => $TestUserID,
            );
            $Self->True(
                $Success,
                "Activity $Activity->{Name} is deleted",
            );
        }

        # Clean up transition actions.
        my $TransitionActionObject = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::TransitionAction');
        for my $Item ( @{ $Process->{TransitionActions} } ) {
            my $TransitionAction = $TransitionActionObject->TransitionActionGet(
                EntityID => $Item,
                UserID   => $TestUserID,
            );

            # Delete test transition action.
            my $Success = $TransitionActionObject->TransitionActionDelete(
                ID     => $TransitionAction->{ID},
                UserID => $TestUserID,
            );
            $Self->True(
                $Success,
                "TransitionAction $TransitionAction->{Name} is deleted",
            );
        }

        # Clean up transition.
        my $TransitionObject = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::Transition');
        for my $Item ( @{ $Process->{Transitions} } ) {
            my $Transition = $TransitionObject->TransitionGet(
                EntityID => $Item,
                UserID   => $TestUserID,
            );

            # Delete test transition.
            my $Success = $TransitionObject->TransitionDelete(
                ID     => $Transition->{ID},
                UserID => $TestUserID,
            );
            $Self->True(
                $Success,
                "Transition $Transition->{Name} is deleted",
            );
        }

        # Delete test Process.
        my $Success = $ProcessObject->ProcessDelete(
            ID     => $Process->{ID},
            UserID => $TestUserID,
        );
        $Self->True(
            $Success,
            "Process $Process->{Name} is deleted",
        );

        # Dynchronize Process after deleting test Process.
        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        # Navigate to AdminProcessManagement screen.
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AdminProcessManagement");

        # Synchronize Process after deleting test Process.
        $Selenium->find_element("//a[contains(\@href, \'Subaction=ProcessSync' )]")->VerifiedClick();

        # Cleanup ACL.
        for my $ACLID (@ACLIDs) {

            # Delete test ACL.
            $Success = $ACLObject->ACLDelete(
                ID     => $ACLID,
                UserID => 1,
            );
            $Self->True(
                $Success,
                "ACLID $ACLID is deleted",
            );
        }

        # Navigate to AdminACL to synchronize after test ACL cleanup.
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AdminACL");

        # Click 'Deploy ACLs'.
        $Selenium->find_element("//a[contains(\@href, 'Action=AdminACL;Subaction=ACLDeploy')]")->VerifiedClick();

        # Delete test Types.
        my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
        for my $Type (@Types) {
            $Type->{Name} = $DBObject->Quote( $Type->{Name} );
            $Success = $DBObject->Do(
                SQL  => "DELETE FROM ticket_type WHERE name = ?",
                Bind => [ \$Type->{Name} ],
            );
            $Self->True(
                $Success,
                "TypeID $Type->{ID} is deleted",
            );
        }

        # Cleanup DynamicField.
        for my $DynamicFieldID (@DynamicFieldIDs) {

            # Delete created test dynamic field
            $Success = $DynamicFieldObject->DynamicFieldDelete(
                ID     => $DynamicFieldID,
                UserID => 1,
            );
            $Self->True(
                $Success,
                "DynamicFieldID $DynamicFieldID is deleted",
            );
        }

        my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');

        # Make sure cache is correct.
        for my $Cache (
            qw(ProcessManagement_Activity ProcessManagement_ActivityDialog ProcessManagement_Process ProcessManagement_Transition ProcessManagement_TransitionAction )
            )
        {
            $CacheObject->CleanUp( Type => $Cache );
        }
    }
);

1;
