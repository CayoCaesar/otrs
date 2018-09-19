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

        # Do not check RichText.
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'Frontend::RichText',
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

        my $TicketObject         = $Kernel::OM->Get('Kernel::System::Ticket');
        my $ArticleBackendObject = $Kernel::OM->Get('Kernel::System::Ticket::Article::Backend::Internal');

        # Create test ticket.
        my $TicketID = $TicketObject->TicketCreate(
            Title        => 'Selenium Test Ticket',
            Queue        => 'Raw',
            Lock         => 'unlock',
            Priority     => '3 normal',
            State        => 'new',
            CustomerID   => 'SeleniumCustomer',
            CustomerUser => 'SeleniumCustomer@localhost.com',
            OwnerID      => $TestUserID,
            UserID       => $TestUserID,
        );
        $Self->True(
            $TicketID,
            "Ticket is created - ID $TicketID",
        );

        # Login as test user.
        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        my $ScriptAlias = $Kernel::OM->Get('Kernel::Config')->Get('ScriptAlias');

        # Navigate to zoom view of created test ticket.
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AgentTicketZoom;TicketID=$TicketID");

        # Force sub menus to be visible in order to be able to click one of the links.
        $Selenium->WaitFor(
            JavaScript =>
                'return typeof($) === "function" && $("#nav-Communication ul").css({ "height": "auto", "opacity": "100" });'
        );

        # Click on 'Note' and switch window.
        $Selenium->find_element("//a[contains(\@href, \'Action=AgentTicketNote;TicketID=$TicketID' )]")->click();

        $Selenium->WaitFor( WindowCount => 2 );
        my $Handles = $Selenium->get_window_handles();
        $Selenium->switch_to_window( $Handles->[1] );

        # Wait until page has loaded, if necessary.
        $Selenium->WaitFor(
            JavaScript =>
                'return typeof($) === "function" && $(".WidgetSimple").length;'
        );

        # Open collapsed widgets, if necessary.
        $Selenium->execute_script(
            "\$('.WidgetSimple.Collapsed .WidgetAction > a').trigger('click');"
        );

        $Selenium->WaitFor(
            JavaScript =>
                'return typeof($) === "function" && $(".WidgetSimple.Expanded").length;'
        );

        # Check page.
        for my $ID (
            qw(Subject RichText FileUpload IsVisibleForCustomer submitRichText)
            )
        {
            my $Element = $Selenium->find_element( "#$ID", 'css' );
            $Element->is_enabled();
            $Element->is_displayed();
        }

        # Get default subject value from Ticket::Frontend::AgentTicketNote###Subject.
        my $DefaultNoteSubject = $ConfigObject->Get("Ticket::Frontend::AgentTicketNote")->{Subject};

        # Add note.
        my $NoteSubject;
        if ($DefaultNoteSubject) {
            $NoteSubject = $DefaultNoteSubject;
        }
        else {
            $NoteSubject = 'Test';
            $Selenium->find_element( "#Subject", 'css' )->send_keys($NoteSubject);
        }

        $Selenium->find_element( "#RichText",       'css' )->send_keys('Test');
        $Selenium->find_element( "#submitRichText", 'css' )->click();

        # Switch window back to agent ticket zoom view of created test ticket.
        $Selenium->WaitFor( WindowCount => 1 );
        $Selenium->switch_to_window( $Handles->[0] );

        # Expand Miscellaneous dropdown menu.
        $Selenium->WaitFor(
            JavaScript =>
                'return typeof($) === "function" && $("#nav-Miscellaneous ul").css({ "height": "auto", "opacity": "100" });'
        );

        # Click on 'History' and switch window.
        $Selenium->find_element("//a[contains(\@href, \'Action=AgentTicketHistory;TicketID=$TicketID' )]")->click();

        $Selenium->WaitFor( WindowCount => 2 );
        $Handles = $Selenium->get_window_handles();
        $Selenium->switch_to_window( $Handles->[1] );

        # Wait until page has loaded, if necessary.
        $Selenium->WaitFor(
            JavaScript =>
                'return typeof($) === "function" && $(".WidgetSimple").length;'
        );

        # Confirm note action.
        my $NoteMsg = "Added note (Note)";
        $Self->True(
            index( $Selenium->get_page_source(), $NoteMsg ) > -1,
            "Ticket note action completed",
        );

        # Close history window.
        $Selenium->find_element( ".CancelClosePopup", 'css' )->click();

        # Switch window back to agent ticket zoom view of created test ticket.
        $Selenium->WaitFor( WindowCount => 1 );
        $Selenium->switch_to_window( $Handles->[0] );

        # Click 'Reply to note' in order to check for pre-loaded reply-to note subject, see bug #10931.
        $Selenium->find_element("//a[contains(\@href, \'ReplyToArticle' )]")->click();

        # Switch window.
        $Selenium->WaitFor( WindowCount => 2 );
        $Handles = $Selenium->get_window_handles();
        $Selenium->switch_to_window( $Handles->[1] );

        # Wait until page has loaded, if necessary.
        $Selenium->WaitFor(
            JavaScript =>
                'return typeof($) === "function" && $(".WidgetSimple").length;'
        );

        # Check for subject pre-loaded value.
        my $NoteSubjectRe = $ConfigObject->Get('Ticket::SubjectRe') || 'Re';

        $Self->Is(
            $Selenium->find_element( '#Subject', 'css' )->get_value(),
            $NoteSubjectRe . ': ' . $NoteSubject,
            "Reply-To note #Subject pre-loaded value",
        );

        # Close note pop-up window.
        $Selenium->close();

        # Switch window back to agent ticket zoom view of created test ticket.
        $Selenium->WaitFor( WindowCount => 1 );
        $Selenium->switch_to_window( $Handles->[0] );

        # Turn on RichText for next test.
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'Frontend::RichText',
            Value => 1,
        );

        # Get image attachment.
        my $AttachmentName = "StdAttachment-Test1.png";
        my $Location       = $ConfigObject->Get('Home')
            . "/scripts/test/sample/StdAttachment/$AttachmentName";
        my $ContentRef = $Kernel::OM->Get('Kernel::System::Main')->FileRead(
            Location => $Location,
            Mode     => 'binmode',
        );
        my $Content   = ${$ContentRef};
        my $ContentID = 'inline173020.131906379.1472199795.695365.264540139@localhost';

        # Create test note with inline attachment.
        my $ArticleID = $ArticleBackendObject->ArticleCreate(
            TicketID             => $TicketID,
            IsVisibleForCustomer => 0,
            SenderType           => 'agent',
            Subject              => 'Selenium subject test',
            Body                 => '<!DOCTYPE html><html><body><img src="cid:' . $ContentID . '" /></body></html>',
            ContentType          => 'text/html; charset="utf8"',
            HistoryType          => 'AddNote',
            HistoryComment       => 'Added note (Note)',
            UserID               => 1,
            Attachment           => [
                {
                    Content     => $Content,
                    ContentID   => $ContentID,
                    ContentType => 'image/png; name="' . $AttachmentName . '"',
                    Disposition => 'inline',
                    FileID      => 1,
                    Filename    => $AttachmentName,
                },
            ],
            NoAgentNotify => 1,
        );
        $Self->True(
            $ArticleID,
            "ArticleCreate - ID $ArticleID",
        );

        # Navigate to added note article.
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AgentTicketZoom;TicketID=$TicketID;ArticleID=$ArticleID");

        # Click 'Reply to note'.
        $Selenium->find_element("//a[contains(\@href, \'ReplyToArticle' )]")->click();

        # Switch window.
        $Selenium->WaitFor( WindowCount => 2 );
        $Handles = $Selenium->get_window_handles();
        $Selenium->switch_to_window( $Handles->[1] );

        # Wait until page has loaded, if necessary.
        $Selenium->WaitFor( JavaScript => "return typeof(\$) === 'function'" );

        # Wait for the CKE to load.
        $Selenium->WaitFor(
            JavaScript =>
                "return \$('body.cke_editable', \$('.cke_wysiwyg_frame').contents()).length == 1"
        );

        # Submit note.
        $Selenium->find_element( "#submitRichText", 'css' )->click();

        # Wait until popup has closed.
        $Selenium->WaitFor( WindowCount => 1 );
        $Selenium->switch_to_window( $Handles->[0] );

        # Wait until page has loaded, if necessary.
        $Selenium->WaitFor(
            JavaScript =>
                'return typeof($) === "function";'
        );

        # Get last article id.
        my @Articles = $Kernel::OM->Get('Kernel::System::Ticket::Article')->ArticleList(
            TicketID => $TicketID,
            OnlyLast => 1,
        );
        my $LastArticleID = $Articles[0]->{ArticleID};

        # Get article attachments.
        my $HTMLContent     = '';
        my %AttachmentIndex = $ArticleBackendObject->ArticleAttachmentIndex(
            ArticleID => $LastArticleID,
        );

        # Go through all attachments.
        for my $FileID ( sort keys %AttachmentIndex ) {
            my %Attachment = $ArticleBackendObject->ArticleAttachment(
                ArticleID => $LastArticleID,
                FileID    => $FileID,
            );

            # Image attachment.
            if ( $Attachment{ContentType} =~ /^image\/png/ ) {
                $Self->Is(
                    $Attachment{Disposition},
                    'inline',
                    'Inline image attachment found',
                );

                # Save content id.
                if ( $Attachment{ContentID} ) {
                    $ContentID = $Attachment{ContentID};
                    $ContentID =~ s/<|>//g;
                }
            }

            # Html attachment.
            elsif ( $Attachment{ContentType} =~ /^text\/html/ ) {
                $HTMLContent = $Attachment{Content};
            }
        }

        # Check if inline attachment is present in the note reply (see bug#12259).
        $Self->True(
            index( $HTMLContent, $ContentID ) > -1,
            'Inline attachment found in note reply',
        );

        # Add a template.
        my $RandomID               = $Helper->GetRandomID();
        my $TemplateText           = 'This is a test template';
        my $StandardTemplateObject = $Kernel::OM->Get('Kernel::System::StandardTemplate');
        my $TemplateID             = $StandardTemplateObject->StandardTemplateAdd(
            Name         => 'UTTemplate_' . $RandomID,
            Template     => $TemplateText,
            ContentType  => 'text/plain; charset=utf-8',
            TemplateType => 'Note',
            ValidID      => 1,
            UserID       => 1,
        );

        $Self->True(
            $TemplateID,
            "Template is created - ID $TemplateID",
        );

        my $QueueObject = $Kernel::OM->Get('Kernel::System::Queue');
        my $QueueID = $QueueObject->QueueLookup( Queue => 'Raw' );

        # Assign the template to our queue.
        my $Success = $QueueObject->QueueStandardTemplateMemberAdd(
            QueueID            => $QueueID,
            StandardTemplateID => $TemplateID,
            Active             => 1,
            UserID             => 1,
        );
        $Self->True(
            $Success,
            "Template got assigned to 'Raw'",
        );

        # Now switch to mobile mode and reload the window.
        $Selenium->set_window_size( 600, 400 );
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AgentTicketZoom;TicketID=$TicketID");

        $Selenium->execute_script(
            "\$('.Cluster ul.Actions').scrollLeft(\$('#nav-Note').offset().left - \$('#nav-Note').width());"
        );

        # Open the note screen (which should be an iframe now).
        $Selenium->find_element("//a[contains(\@href, \'Action=AgentTicketNote;TicketID=$TicketID' )]")->click();

        # Wait for the iframe to show up.
        $Selenium->WaitFor(
            JavaScript =>
                "return typeof(\$) === 'function' && \$('form#Compose', \$('.PopupIframe').contents()).length == 1"
        );

        # Get frame name.
        my $FrameName = $Selenium->execute_script(
            "return \$('iframe.PopupIframe').attr('name');"
        );

        $Selenium->switch_to_frame($FrameName);

        $Selenium->WaitFor(
            JavaScript =>
                'return typeof(Core) == "object" && typeof(Core.App) == "object" && Core.App.PageLoadComplete'
        ) || die "OTRS API verification failed after page load.";

        # Check if the richtext is empty.
        $Self->Is(
            $Selenium->find_element( '#RichText', 'css' )->get_value(),
            '',
            "RichText is empty",
        );

        # Select the created template.
        $Selenium->execute_script(
            "\$('#StandardTemplateID').val('$TemplateID').trigger('redraw.InputField').trigger('change');"
        );

        # Wait a short time and for the spinner to disappear.
        sleep(2);
        $Selenium->WaitFor(
            JavaScript =>
                "return typeof(\$) === 'function' && \$('.AJAXLoader:visible', \$('.PopupIframe').contents()).length == 0"
        );

        my $CKEditorValue = $Selenium->execute_script(
            "return CKEDITOR.instances.RichText.getData()"
        );

        $Self->Is(
            $CKEditorValue,
            $TemplateText,
            "RichText contains the correct value from the selected template",
        );

        # Delete template.
        $Success = $StandardTemplateObject->StandardTemplateDelete(
            ID => $TemplateID,
        );
        $Self->True(
            $Success,
            "Template is deleted - ID $TemplateID",
        );

        # Delete created test tickets.
        $Success = $TicketObject->TicketDelete(
            TicketID => $TicketID,
            UserID   => $TestUserID,
        );

        # Ticket deletion could fail if apache still writes to ticket history. Try again in this case.
        if ( !$Success ) {
            sleep 3;
            $Success = $TicketObject->TicketDelete(
                TicketID => $TicketID,
                UserID   => $TestUserID,
            );
        }
        $Self->True(
            $Success,
            "Ticket is deleted - ID $TicketID",
        );

        # Make sure the cache is correct.
        $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
            Type => 'Ticket',
        );
    },
);

1;
