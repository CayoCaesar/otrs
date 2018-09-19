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

use Kernel::Language;

my $Selenium = $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');

$Selenium->RunTest(
    sub {

        my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

        my $Language = 'de';

        # Create test user and login.
        my $TestUserLogin = $Helper->TestUserCreate(
            Language => $Language,
            Groups   => ['admin'],
        ) || die "Did not get test user";

        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        my $ConfigObject   = $Kernel::OM->Get('Kernel::Config');
        my $LanguageObject = Kernel::Language->new(
            UserLanguage => $Language,
        );

        my $ScriptAlias = $ConfigObject->Get('ScriptAlias');

        # Navigate to AdminPostMasterFilter screen.
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AdminPostMasterFilter");

        # Check overview AdminPostMasterFilter.
        $Selenium->find_element( "table",             'css' );
        $Selenium->find_element( "table thead tr th", 'css' );
        $Selenium->find_element( "table tbody tr td", 'css' );

        # Check breadcrumb on Overview screen.
        $Self->True(
            $Selenium->find_element( '.BreadCrumb', 'css' ),
            "Breadcrumb is found on Overview screen.",
        );

        # Click 'Add filter'.
        $Selenium->find_element("//a[contains(\@href, \'Action=AdminPostMasterFilter;Subaction=AddAction' )]")
            ->VerifiedClick();

        # Check client side validation.
        $Selenium->find_element( "#EditName", 'css' )->clear();
        $Selenium->execute_script("\$('#Submit').click();");
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("#EditName.Error").length' );

        $Self->Is(
            $Selenium->execute_script(
                "return \$('#EditName').hasClass('Error')"
            ),
            '1',
            'Client side validation correctly detected missing input value',
        );

        # Check add page.
        for my $ID (
            qw(EditName StopAfterMatch MatchHeaderExample MatchValueExample SetHeaderExample SetValueExample)
            )
        {
            my $Element = $Selenium->find_element( "#$ID", 'css' );
            $Element->is_enabled();
            $Element->is_displayed();
        }

        my $HeaderFieldCount = $ConfigObject->Get('PostmasterHeaderFieldCount');
        if ($HeaderFieldCount) {
            for my $HeaderID ( 1 .. $HeaderFieldCount ) {
                for my $Header (
                    qw (MatchHeader MatchNot MatchValue SetHeader SetValue)
                    )
                {
                    my $Element = $Selenium->find_element( "#$Header$HeaderID", 'css' );
                    $Element->is_enabled();
                    $Element->is_displayed();
                }

                $HeaderID++;
            }
        }

        # Check breadcrumb on Add screen.
        my $SecondBreadcrumbText = $LanguageObject->Translate('PostMaster Filter Management');
        my $ThirdBreadcrumbText  = $LanguageObject->Translate('Add PostMaster Filter');
        my $Count                = 1;
        for my $BreadcrumbText ( $SecondBreadcrumbText, $ThirdBreadcrumbText ) {
            $Self->Is(
                $Selenium->execute_script("return \$('.BreadCrumb li:eq($Count)').text().trim()"),
                $BreadcrumbText,
                "Breadcrumb text '$BreadcrumbText' is found on screen"
            );

            $Count++;
        }

        # Check filter value length.
        # See bug#13889 for more information.
        my $PostMasterValueLong = 'A' x 200;
        $Selenium->find_element( "#MatchValue1", 'css' )->send_keys($PostMasterValueLong);
        $Self->Is(
            $Selenium->find_element( "#MatchValue1", 'css' )->get_value(),
            $PostMasterValueLong,
            "Check max length for MatchValue",
        );
        $Selenium->find_element( "#MatchValue1", 'css' )->clear();

        $Selenium->find_element( "#SetValue1", 'css' )->send_keys($PostMasterValueLong);
        $Self->Is(
            $Selenium->find_element( "#SetValue1", 'css' )->get_value(),
            $PostMasterValueLong,
            "Check max length for SetValue1",
        );
        $Selenium->find_element( "#SetValue1", 'css' )->clear();

        # Add first test PostMasterFilter.
        my $PostMasterName     = "postmasterfilter" . $Helper->GetRandomID();
        my $PostMasterBody     = "Selenium test for PostMasterFilter";
        my $PostMasterPriority = "2 low";

        $Selenium->find_element( "#EditName", 'css' )->send_keys($PostMasterName);
        $Selenium->execute_script("\$('#MatchHeader1').val('Body').trigger('redraw.InputField').trigger('change');");
        $Selenium->find_element( "#MatchNot1",   'css' )->click();
        $Selenium->find_element( "#MatchValue1", 'css' )->send_keys($PostMasterBody);
        $Selenium->execute_script(
            "\$('#SetHeader1').val('X-OTRS-Priority').trigger('redraw.InputField').trigger('change');"
        );

        $Selenium->find_element( "#SetValue1", 'css' )->send_keys($PostMasterPriority);
        $Selenium->execute_script("\$('#Submit').click();");
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("#PostMasterFilters").length;' );

        # Check for created first test PostMasterFilter on screen.
        $Self->True(
            index( $Selenium->get_page_source(), $PostMasterName ) > -1,
            "$PostMasterName PostMasterFilter found on page",
        );

        # Check new test PostMasterFilter values.
        $Selenium->find_element( $PostMasterName, 'link_text' )->VerifiedClick();

        $Self->Is(
            $Selenium->find_element( '#EditName', 'css' )->get_value(),
            $PostMasterName,
            "#EditName stored value",
        );
        $Self->Is(
            $Selenium->find_element( '#MatchHeader1', 'css' )->get_value(),
            "Body",
            "#MatchHeader1 stored value",
        );
        $Self->Is(
            $Selenium->find_element( '#MatchNot1', 'css' )->is_selected(),
            1,
            "#MatchNot1 stored value",
        );
        $Self->Is(
            $Selenium->find_element( '#MatchValue1', 'css' )->get_value(),
            $PostMasterBody,
            "#MatchValue1 stored value",
        );
        $Self->Is(
            $Selenium->find_element( '#SetHeader1', 'css' )->get_value(),
            "X-OTRS-Priority",
            "#SetHeader1 stored value",
        );
        $Self->Is(
            $Selenium->find_element( '#SetValue1', 'css' )->get_value(),
            $PostMasterPriority,
            "#SetValue1 stored value",
        );

        # Check breadcrumb on Edit screen.
        $Count               = 1;
        $ThirdBreadcrumbText = $LanguageObject->Translate('Edit PostMaster Filter') . ": $PostMasterName";
        for my $BreadcrumbText ( $SecondBreadcrumbText, $ThirdBreadcrumbText ) {
            $Self->Is(
                $Selenium->execute_script("return \$('.BreadCrumb li:eq($Count)').text().trim()"),
                $BreadcrumbText,
                "Breadcrumb text '$BreadcrumbText' is found on screen"
            );

            $Count++;
        }

        # Edit test PostMasterFilter.
        my $EditPostMasterPriority = "4 high";

        $Selenium->execute_script("\$('#StopAfterMatch').val('1').trigger('redraw.InputField').trigger('change');");
        $Selenium->find_element( "#MatchNot1", 'css' )->click();
        $Selenium->find_element( "#SetValue1", 'css' )->clear();
        $Selenium->find_element( "#SetValue1", 'css' )->send_keys($EditPostMasterPriority);
        $Selenium->execute_script("\$('#Submit').click();");
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("#PostMasterFilters").length;' );

        # Check edited test PostMasterFilter values.
        $Selenium->find_element( $PostMasterName, 'link_text' )->click();
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("#StopAfterMatch").length;' );

        $Self->Is(
            $Selenium->find_element( '#StopAfterMatch', 'css' )->get_value(),
            1,
            "#StopAfterMatch updated value",
        );
        $Self->Is(
            $Selenium->find_element( '#MatchNot1', 'css' )->is_selected(),
            0,
            "#MatchNot1 updated value",
        );
        $Self->Is(
            $Selenium->find_element( '#SetValue1', 'css' )->get_value(),
            $EditPostMasterPriority,
            "#SetValue1 updated value",
        );

        # Make sure that 0 can be stored in match and set as well (see http://bugs.otrs.org/show_bug.cgi?id=12218).
        $Selenium->find_element( "#MatchValue1", 'css' )->clear();
        $Selenium->find_element( "#MatchValue1", 'css' )->send_keys('0');
        $Selenium->find_element( "#SetValue1",   'css' )->clear();
        $Selenium->find_element( "#SetValue1",   'css' )->send_keys('0');
        $Selenium->find_element( "#Submit",      'css' )->VerifiedClick();

        # Try to create PostMasterFilter with the same name, (see https://bugs.otrs.org/show_bug.cgi?id=12718).
        $Selenium->find_element("//a[contains(\@href, \'Action=AdminPostMasterFilter;Subaction=AddAction' )]")
            ->VerifiedClick();

        $Selenium->find_element( "#EditName", 'css' )->send_keys($PostMasterName);
        $Selenium->execute_script("\$('#MatchHeader1').val('Body').trigger('redraw.InputField').trigger('change');");
        $Selenium->find_element( "#MatchValue1", 'css' )->send_keys($PostMasterBody);
        $Selenium->execute_script(
            "\$('#SetHeader1').val('X-OTRS-Priority').trigger('redraw.InputField').trigger('change');"
        );
        $Selenium->find_element( "#SetValue1", 'css' )->send_keys($PostMasterPriority);
        $Selenium->execute_script("\$('#Submit').click();");

        # Wait for dialog to appears.
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("#DialogButton1").length;' );

        # Confirm JS error.
        $Selenium->find_element( "#DialogButton1", 'css' )->click();

        # Verify duplicated name error.
        $Self->Is(
            $Selenium->execute_script(
                "return \$('#EditName').hasClass('Error')"
            ),
            '1',
            'Client side validation correctly detected duplicated name input value',
        );

        # Edit name to create second PostMasterFilter.
        my $PostMasterName2 = $PostMasterName . '2';
        $Selenium->find_element( "#EditName", 'css' )->clear();
        $Selenium->find_element( "#EditName", 'css' )->send_keys($PostMasterName2);
        $Selenium->execute_script("\$('#Submit').click();");
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("#PostMasterFilters").length;' );

        # Verify second PostMasterFilter is created.
        $Self->True(
            index( $Selenium->get_page_source(), $PostMasterName2 ) > -1,
            "$PostMasterName2 second PostMasterFilter found on page",
        );

        # Click to edit second PostMasterFilter.
        $Selenium->find_element( $PostMasterName2, 'link_text' )->VerifiedClick();

        # Try to change name as first PostMasterFilter, verify duplication error.
        $Selenium->find_element( "#EditName", 'css' )->clear();
        $Selenium->find_element( "#EditName", 'css' )->send_keys($PostMasterName);
        $Selenium->execute_script("\$('#Submit').click();");

        # Wait for dialog to appears.
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("#DialogButton1").length;' );

        # Confirm JS error.
        $Selenium->find_element( "#DialogButton1", 'css' )->click();

        # Verify duplicated name error.
        $Self->Is(
            $Selenium->execute_script(
                "return \$('#EditName').hasClass('Error')"
            ),
            '1',
            'Client side validation correctly detected duplicated name input value',
        );

        # Change name to something else, verify second PostMasterFilter will be first deleted
        # then created new one.
        my $PostMasterName3 = $PostMasterName . '3';
        $Selenium->find_element( "#EditName", 'css' )->clear();
        $Selenium->find_element( "#EditName", 'css' )->send_keys($PostMasterName3);
        $Selenium->execute_script("\$('#Submit').click();");
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("#PostMasterFilters").length;' );

        $Self->True(
            index( $Selenium->get_page_source(), $PostMasterName2 ) == -1,
            "$PostMasterName2 original second PostMasterFilter is not found on page",
        );
        $Self->True(
            index( $Selenium->get_page_source(), $PostMasterName3 ) > -1,
            "$PostMasterName2 edited second PostMasterFilter found on page",
        );

        # Delete second PostMasterFilter.
        $Selenium->find_element(
            "//a[contains(\@data-query-string, \'Subaction=Delete;Name=$PostMasterName3' )]"
        )->click();

        # Wait for dialog to appears.
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("#DialogButton1").length;' );

        # Verify delete dialog message.
        my $DeleteMessage = $LanguageObject->Translate("Do you really want to delete this postmaster filter?");
        $Self->True(
            index( $Selenium->get_page_source(), $DeleteMessage ) > -1,
            "Delete message is found",
        );

        # Confirm delete action.
        $Selenium->find_element( "#DialogButton1", 'css' )->VerifiedClick();

        # Wait for the dialog to disappear.
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $(".Dialog:visible").length === 0;' );
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("#PostMasterFilters").length > 0;' );

        # Check if second PostMasterFilter is deleted.
        $Self->True(
            index( $Selenium->get_page_source(), $PostMasterName3 ) == -1,
            "Second PostMasterFilter '$PostMasterName3' is deleted"
        );

        # Delete first PostMasterFilter.
        $Selenium->find_element(
            "//a[contains(\@data-query-string, \'Subaction=Delete;Name=$PostMasterName' )]"
        )->click();

        # Wait for dialog to appears.
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $(".Dialog:visible").length === 1;' );

        # Confirm delete action.
        $Selenium->find_element( "#DialogButton1", 'css' )->VerifiedClick();

        # Wait for the dialog to disappear.
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $(".Dialog:visible").length === 0;' );
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("#PostMasterFilters").length > 0;' );

        # Check if first postmaster filter is deleted.
        $Self->True(
            index( $Selenium->get_page_source(), $PostMasterName ) == -1,
            "First PostMasterFilter '$PostMasterName' is deleted"
        );
    }
);

1;
