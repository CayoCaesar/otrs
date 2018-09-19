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

my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

# make sure to enable cloud services
$Helper->ConfigSettingChange(
    Valid => 1,
    Key   => 'CloudServices::Disabled',
    Value => 0,
);

$Helper->ConfigSettingChange(
    Valid => 1,
    Key   => 'Package::AllowNotVerifiedPackages',
    Value => 0,
);

my $RandomID = $Helper->GetRandomID();

# Override Request() from WebUserAgent to always return some test data without making any
#   actual web service calls. This should prevent instability in case cloud services are
#   unavailable at the exact moment of this test run.
my $CustomCode = <<"EOS";
sub Kernel::Config::Files::ZZZZUnitTestAdminPackageManager${RandomID}::Load {} # no-op, avoid warning logs
use Kernel::System::WebUserAgent;
package Kernel::System::WebUserAgent;
use strict;
use warnings;
## nofilter(TidyAll::Plugin::OTRS::Perl::TestSubs)
{
    no warnings 'redefine';
    sub Request {
        return (
            Status  => '200 OK',
            Content => '{"Success":1,"Results":{"PackageManagement":[{"Operation":"PackageVerify","Data":{"Test":"not_verified","TestPackageIncompatible":"not_verified"},"Success":"1"}]},"ErrorMessage":""},
        );
    }
}
1;
EOS
$Helper->CustomCodeActivate(
    Code       => $CustomCode,
    Identifier => 'AdminPackageManager' . $RandomID,
);

my $Selenium = $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');

my $CheckBreadcrumb = sub {

    my %Param = @_;

    my $BreadcrumbText = $Param{BreadcrumbText} || '';
    my $Count = 1;

    for my $BreadcrumbText ( 'Package Manager', "$BreadcrumbText Test" ) {
        $Self->Is(
            $Selenium->execute_script("return \$('.BreadCrumb li:eq($Count)').text().trim()"),
            $BreadcrumbText,
            "Breadcrumb text '$BreadcrumbText' is found on screen"
        );

        $Count++;
    }
};

$Selenium->RunTest(
    sub {

        my $Helper        = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
        my $PackageObject = $Kernel::OM->Get('Kernel::System::Package');

        # For test stability check if package is already installed.
        my $PackageCheck = $PackageObject->PackageIsInstalled(
            Name => 'Test',
        );

        # If package is installed, remove it so we can install it again in the test.
        if ($PackageCheck) {
            my $FileString = '<?xml version="1.0" encoding="utf-8" ?>
                <otrs_package version="1.0">
                  <Name>Test</Name>
                  <Version>0.0.1</Version>
                  <Framework>x.x.x</Framework>
                  <Vendor>OTRS AG</Vendor>
                  <URL>http://otrs.org/</URL>
                  <License>GNU GENERAL PUBLIC LICENSE Version 2, June 199</License>
                  <ChangeLog>2005-11-10 New package (some test &lt; &gt; &amp;).</ChangeLog>
                  <Description Lang="en">A test package (some test &lt; &gt; &amp;).</Description>
                  <Description Lang="de">Ein Test Paket (some test &lt; &gt; &amp;).</Description>
                  <ModuleRequired Version="1.112">Encode</ModuleRequired>
                  <BuildDate>2005-11-10 21:17:16</BuildDate>
                  <BuildHost>yourhost.example.com</BuildHost>
                  <CodeInstall>
                   # just a test &lt;some&gt; plus some &amp; text
                  </CodeInstall>
                  <DatabaseInstall>
                    <TableCreate Name="test_package">
                        <Column Name="name_a" Required="true" Type="INTEGER"/>
                        <Column Name="name_b" Required="true" Size="60" Type="VARCHAR"/>
                        <Column Name="name_c" Required="false" Size="60" Type="VARCHAR"/>
                    </TableCreate>
                    <Insert Table="test_package">
                        <Data Key="name_a">1234</Data>
                        <Data Key="name_b" Type="Quote">some text</Data>
                        <Data Key="name_c" Type="Quote">some text &lt;more&gt;
                          text &amp; text
                        </Data>
                    </Insert>
                    <Insert Table="test_package">
                        <Data Key="name_a">0</Data>
                        <Data Key="name_b" Type="Quote">1</Data>
                    </Insert>
                  </DatabaseInstall>
                  <DatabaseUninstall>
                    <TableDrop Name="test_package"/>
                  </DatabaseUninstall>
                  <Filelist>
                    <File Location="var/tmp/Test" Permission="644" Encode="Base64">aGVsbG8K</File>
                    <File Location="var/Test" Permission="644" Encode="Base64">aGVsbG8K</File>
                  </Filelist>
                </otrs_package>';

            my $PackageUninstall = $PackageObject->PackageUninstall( String => $FileString );
            $Self->True(
                $PackageUninstall,
                'Test package is uninstalled'
            );
        }

        # Create test user and login.
        my $TestUserLogin = $Helper->TestUserCreate(
            Groups => ['admin'],
        ) || die 'Did not get test user';

        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

        # Get script alias.
        my $ScriptAlias = $ConfigObject->Get('ScriptAlias');

        # Navigate to AdminPackageManager screen.
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AdminPackageManager");

        # Check breadcrumb on Overview screen.
        $Self->True(
            $Selenium->find_element( '.BreadCrumb', 'css' ),
            'Breadcrumb is found on Overview screen'
        );

        # Check overview AdminPackageManager.
        my $Element = $Selenium->find_element( '#FileUpload', 'css' );
        $Element->is_enabled();
        $Element->is_displayed();

        # Install test package.
        my $Location = $ConfigObject->Get('Home') . '/scripts/test/sample/PackageManager/TestPackage.opm';

        $Selenium->find_element( '#FileUpload', 'css' )->send_keys($Location);

        $Selenium->find_element("//button[\@value='Install'][\@type='submit']")->VerifiedClick();

        # Check breadcrumb on Install screen.
        $CheckBreadcrumb->(
            BreadcrumbText => 'Install Package:',
        );

        # Package is not verified, so it's not possible to continue with the installation.
        $Self->Is(
            $Selenium->execute_script("return \$('button[type=\"submit\"][value=\"Continue\"]').length"),
            '0',
            'Continue button not available because package is not verified'
        );

        $Self->True(
            index(
                $Selenium->get_page_source(),
                'The installation of packages which are not verified by the OTRS Group is not possible by default.'
            ) > 0,
            'Message for aborting installation of package is displayed'
        );

        # Continue with package installation.
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'Package::AllowNotVerifiedPackages',
            Value => 1,
        );

        # Allow apache to pick up the changed SysConfig via Apache::Reload.
        sleep 1;

        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AdminPackageManager");

        # Check for notification.
        $Self->True(
            $Selenium->execute_script(
                'return $("div.MessageBox.Error p:contains(\'The installation of packages which are not verified by the OTRS Group is activated. These packages could threaten your whole system! It is recommended not to use unverified packages.\')").length',
            ),
            'Install warning for not verified packages is displayed',
        );

        $Selenium->find_element( '#FileUpload', 'css' )->send_keys($Location);
        $Selenium->find_element("//button[\@value='Install'][\@type='submit']")->VerifiedClick();

        $CheckBreadcrumb->(
            BreadcrumbText => 'Install Package:',
        );
        $Selenium->find_element("//button[\@value='Continue'][\@type='submit']")->VerifiedClick();

        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $(".DataTable").length;' );
        $Self->True(
            $Selenium->find_element(
                "//a[contains(\@href, \'Subaction=View;Name=Test' )]"
            )->is_displayed(),
            'Test package is installed'
        );

        # Load page with metadata of installed package.
        $Selenium->find_element(
            "//a[contains(\@href, \'Subaction=View;Name=Test' )]"
        )->VerifiedClick();

        # Check breadcrumb on Package metadata screen.
        $CheckBreadcrumb->(
            BreadcrumbText => 'Package Information:',
        );

        $Selenium->find_element("//a[contains(\@href, \'Subaction=Download' )]");
        $Selenium->find_element("//a[contains(\@href, \'Subaction=RebuildPackage' )]");
        $Selenium->find_element("//a[contains(\@href, \'Subaction=Reinstall' )]");

        # Go back to overview.
        $Selenium->find_element("//a[contains(\@href, \'Action=AdminPackageManager' )]")->VerifiedClick();

        # Uninstall package.
        $Selenium->find_element(
            "//a[contains(\@href, \'Subaction=Uninstall;Name=Test' )]"
        )->VerifiedClick();

        # Check breadcrumb on uninstall screen.
        $CheckBreadcrumb->(
            BreadcrumbText => 'Uninstall Package:',
        );

        $Selenium->find_element("//button[\@value='Uninstall package'][\@type='submit']")->VerifiedClick();

        # Check if test package is uninstalled.
        $Self->True(
            index( $Selenium->get_page_source(), 'Subaction=View;Name=Test' ) == -1,
            'Test package is uninstalled'
        );

        $Selenium->VerifiedGet(
            "${ScriptAlias}index.pl?Action=AdminPackageManager;Subaction=View;Name=NonexistingPackage;Version=0.0.1"
        );

        $Selenium->find_element( 'div.ErrorScreen', 'css' );

        # Navigate to AdminPackageManager screen.
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AdminPackageManager");

        # Try to install incompatible test package.
        $Location = $ConfigObject->Get('Home') . '/scripts/test/sample/PackageManager/TestPackageIncompatible.opm';

        $Selenium->find_element( '#FileUpload', 'css' )->send_keys($Location);

        $Selenium->find_element("//button[\@value='Install'][\@type='submit']")->VerifiedClick();
        $Selenium->find_element("//button[\@value='Continue'][\@type='submit']")->VerifiedClick();

        # Check if info for incompatible package is shown.
        $Self->True(
            $Selenium->execute_script(
                "return \$('.WidgetSimple .Content h2:contains(\"Package installation requires a patch level update of OTRS\")').length;"
            ),
            'Info for incompatible package is shown'
        );

    }
);

1;
