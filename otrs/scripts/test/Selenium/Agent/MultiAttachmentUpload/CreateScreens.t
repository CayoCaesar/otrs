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

use Kernel::Output::HTML::Layout;

my $Selenium = $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');

$Selenium->RunTest(
    sub {

        my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

        # Change web max file upload.
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'WebMaxFileUpload',
            Value => '68000'
        );

        my $Language = 'en';

        # Create test user and login.
        my $TestUserLogin = $Helper->TestUserCreate(
            Groups   => [ 'admin', 'users' ],
            Language => $Language,
        ) || die "Did not get test user";

        my $LayoutObject = Kernel::Output::HTML::Layout->new(
            Lang         => $Language,
            UserTimeZone => 'UTC',
        );

        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
        my $ScriptAlias  = $ConfigObject->Get('ScriptAlias');
        my $Home         = $ConfigObject->Get('Home');

        # Check screens.
        for my $Action (qw(AgentTicketPhone AgentTicketEmail))
        {

            $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=$Action");

            # Check DnDUpload.
            my $Element = $Selenium->find_element( ".DnDUpload", 'css' );
            $Element->is_enabled();
            $Element->is_displayed();

            # Hide DnDUpload and show input field.
            $Selenium->execute_script("\$('.DnDUpload').css('display', 'none')");
            $Selenium->execute_script("\$('#FileUpload').css('display', 'block')");

            # limit the allowed file types
            $Selenium->execute_script(
                "\$('#FileUpload').data('file-types', 'myext')"
            );

            my $CheckFileTypeFilename = 'Test1.png';
            my $Location              = "$Home/scripts/test/sample/Cache/$CheckFileTypeFilename";
            $Selenium->find_element( "#FileUpload", 'css' )->clear();
            $Selenium->find_element( "#FileUpload", 'css' )->send_keys($Location);
            $Selenium->WaitFor(
                JavaScript => 'return typeof($) === "function" && $(".Dialog:visible").length'
            );

            # Verify dialog message.
            my $FileTypeMessage = "The following files are not allowed to be uploaded: $CheckFileTypeFilename";
            $Self->True(
                $Selenium->execute_script(
                    "return \$('.Dialog.Modal .InnerContent:contains(\"$FileTypeMessage\")').length"
                ),
                "$Action - FileTypeMessage is found",
            );

            # Confirm dialog action.
            $Selenium->find_element( "#DialogButton1", 'css' )->click();
            $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && !$(".Dialog.Modal").length' );

            $Selenium->find_element( "#FileUpload", 'css' )->clear();

            # limit the max amount of files
            $Selenium->execute_script(
                "\$('#FileUpload').removeData('file-types')"
            );
            $Selenium->execute_script(
                "\$('#FileUpload').data('max-files', 2)"
            );

            $Location = "$Home/scripts/test/sample/Cache/Test1.pdf";
            $Selenium->find_element( "#FileUpload", 'css' )->send_keys($Location);
            $Selenium->WaitFor(
                JavaScript =>
                    "return typeof(\$) === 'function' && \$('.AttachmentDelete i').length === 1"
            );
            sleep 1;

            $Location = "$Home/scripts/test/sample/Cache/Test1.doc";
            $Selenium->find_element( "#FileUpload", 'css' )->send_keys($Location);
            $Selenium->WaitFor(
                JavaScript =>
                    "return typeof(\$) === 'function' && \$('.AttachmentDelete i').length === 2"
            );
            sleep 1;

            $Location = "$Home/scripts/test/sample/Cache/Test1.txt";
            $Selenium->find_element( "#FileUpload", 'css' )->send_keys($Location);
            $Selenium->WaitFor(
                AlertPresent => 1,
            );

            # Verify alert text.
            $Self->Is(
                $Selenium->get_alert_text(),
                'Sorry, you can only upload 2 files.',
                "$Action - alert for max files shown correctly",
            );

            # Accept alert.
            $Selenium->accept_alert();
            sleep 1;

            my $Count = 2;

            # Remove the existing files.
            for my $DeleteExtension (qw(doc pdf)) {

                # Delete Attachment.
                $Selenium->find_element( "(//a[\@class='AttachmentDelete'])[$Count]", 'xpath' )->click();
                $Count--;
                sleep 2;

                # Wait until attachment is deleted.
                $Selenium->WaitFor(
                    JavaScript =>
                        "return typeof(\$) === 'function' && \$('.AttachmentDelete i').length === $Count"
                );

                # Check if deleted.
                $Self->True(
                    $Selenium->execute_script(
                        "return \$('.AttachmentDelete i').length === $Count"
                    ),
                    "$Action - Upload '$DeleteExtension' file deleted"
                );
            }

            # Limit the max size per file (to 6 KB).
            $Selenium->execute_script(
                "\$('#FileUpload').removeData('max-files')"
            );
            $Selenium->execute_script(
                "\$('#FileUpload').data('max-size-per-file', 6000)"
            );
            $Selenium->execute_script(
                "\$('#FileUpload').data('max-size-per-file-hr', '6 KB')"
            );

            # Now try to upload two files of which one exceeds the max size
            # (.pdf should work (5KB), .png shouldn't (20KB)).
            $Location = "$Home/scripts/test/sample/Cache/Test1.pdf";
            $Selenium->find_element( "#FileUpload", 'css' )->clear();
            $Selenium->find_element( "#FileUpload", 'css' )->send_keys($Location);
            $Selenium->WaitFor(
                JavaScript =>
                    "return typeof(\$) === 'function' && \$('.AttachmentDelete i').length === 1"
            );
            sleep 1;

            my $CheckMaxAllowedSizeFilename = 'Test1.png';
            $Location = "$Home/scripts/test/sample/Cache/$CheckMaxAllowedSizeFilename";
            $Selenium->find_element( "#FileUpload", 'css' )->clear();
            $Selenium->find_element( "#FileUpload", 'css' )->send_keys($Location);
            $Selenium->WaitFor(
                JavaScript => 'return typeof($) === "function" && $(".Dialog:visible").length'
            );

            # Verify dialog message.
            my $MaxAllowedSizeMessage
                = "The following files exceed the maximum allowed size per file of 6 KB and were not uploaded: $CheckMaxAllowedSizeFilename";
            $Self->True(
                $Selenium->execute_script(
                    "return \$('.Dialog.Modal .InnerContent:contains(\"$MaxAllowedSizeMessage\")').length"
                ),
                "$Action - MaxAllowedSizeMessage is found",
            );

            # Confirm dialog action.
            $Selenium->find_element( "#DialogButton1", 'css' )->click();
            $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && !$(".Dialog.Modal").length' );

            # Remove the limitations again.
            $Selenium->execute_script(
                "\$('#FileUpload').removeData('max-size-per-file')"
            );

            # Delete the remaining file.
            $Self->True(
                $Selenium->execute_script(
                    "return \$('.AttachmentList tbody tr td.Filename:contains(\"Test1.pdf\")').length"
                ),
                "$Action - Uploaded 'pdf' file still there"
            );

            # Delete Attachment.
            $Selenium->find_element( "(//a[\@class='AttachmentDelete'])[1]", 'xpath' )->click();
            sleep 1;

            $Selenium->WaitFor(
                JavaScript =>
                    "return typeof(\$) === 'function' && \$('.AttachmentDelete i').length === 0"
            );

            # Check if deleted.
            $Self->True(
                $Selenium->execute_script(
                    "return \$('.AttachmentDelete i').length === 0"
                ),
                "$Action - Uploaded file Test1.pdf deleted"
            );

            # Upload files.
            for my $UploadExtension (qw(doc pdf png txt xls)) {

                my $Location = "$Home/scripts/test/sample/Main/Main-Test1.$UploadExtension";
                $Selenium->find_element( "#FileUpload", 'css' )->clear();
                $Selenium->find_element( "#FileUpload", 'css' )->send_keys($Location);
                $Selenium->WaitFor(
                    JavaScript =>
                        "return typeof(\$) === 'function' && \$('.AttachmentDelete i').length"
                );
                sleep 1;

                # Check if uploaded.
                $Self->True(
                    $Selenium->execute_script(
                        "return \$('.AttachmentList tbody tr td.Filename:contains(\"Main-Test1.$UploadExtension\")').length"
                    ),
                    "$Action - Upload '$UploadExtension' file correct"
                );
            }

            # Upload file again.
            my $CheckUploadAgainFilename = 'Main-Test1.txt';
            $Location = "$Home/scripts/test/sample/Main/$CheckUploadAgainFilename";
            $Selenium->find_element( "#FileUpload", 'css' )->clear();
            $Selenium->find_element( "#FileUpload", 'css' )->send_keys($Location);
            $Selenium->WaitFor(
                JavaScript => 'return typeof($) === "function" && $(".Dialog:visible").length'
            );

            # Verify dialog message.
            my $UploadAgainMessage
                = "The following files were already uploaded and have not been uploaded again: $CheckUploadAgainFilename";
            $Self->True(
                $Selenium->execute_script(
                    "return \$('.Dialog.Modal .InnerContent:contains(\"$UploadAgainMessage\")').length"
                ),
                "$Action - UploadAgainMessage is found",
            );

            # Confirm dialog action.
            $Selenium->find_element( "#DialogButton1", 'css' )->click();
            $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && !$(".Dialog.Modal").length' );

            # Check max size.
            my $CheckMaxSizeFilename = 'PostMaster-Test13.box';
            $Location = "$Home/scripts/test/sample/EmailParser/$CheckMaxSizeFilename";
            $Selenium->find_element( "#FileUpload", 'css' )->clear();
            $Selenium->find_element( "#FileUpload", 'css' )->send_keys($Location);
            $Selenium->WaitFor(
                JavaScript => 'return typeof($) === "function" && $(".Dialog:visible").length'
            );

            # Verify dialog message.
            my $UploadMaxMessage = "No space left for the following files: $CheckMaxSizeFilename";
            $Self->True(
                $Selenium->execute_script(
                    "return \$('.Dialog.Modal .InnerContent:contains(\"$UploadMaxMessage\")').length"
                ),
                "$Action - UploadMaxMessage is found",
            );

            # Confirm dialog action.
            $Selenium->find_element( "#DialogButton1", 'css' )->click();
            $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && !$(".Dialog.Modal").length' );

            # Submit and check later if files still there.
            $Selenium->find_element( "#submitRichText", 'css' )->click();
            $Selenium->WaitFor( JavaScript => "return \$('#Subject.Error').length" );

            $Count = 5;

            # Delete files.
            for my $DeleteExtension (qw(doc pdf png txt xls)) {

                # Delete Attachment.
                $Selenium->find_element( "(//a[\@class='AttachmentDelete'])[$Count]", 'xpath' )->click();
                $Count--;
                sleep 2;

                # Wait until attachment is deleted.
                $Selenium->WaitFor(
                    JavaScript =>
                        "return typeof(\$) === 'function' && \$('.AttachmentDelete i').length == $Count"
                );

                # Check if deleted.
                $Self->True(
                    $Selenium->execute_script(
                        "return \$('.AttachmentDelete i').length == $Count"
                    ),
                    "$Action - Uploaded file 'Main-Test1.$DeleteExtension' deleted"
                );
            }
        }
    }
);

1;
