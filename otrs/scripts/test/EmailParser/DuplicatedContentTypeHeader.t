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

use Kernel::System::EmailParser;

my $Home = $Kernel::OM->Get('Kernel::Config')->Get('Home');

# test for bug#9989
my @Array;
open my $IN, '<', "$Home/scripts/test/sample/EmailParser/DuplicatedContentTypeHeader.eml";    ## no critic
while (<$IN>) {
    push @Array, $_;
}
close $IN;

# create local object
my $EmailParserObject = Kernel::System::EmailParser->new(
    Email => \@Array,
);

my @Attachments = $EmailParserObject->GetAttachments();
$Self->Is(
    scalar @Attachments,
    1,
    "Found 3 files (plain and both attachments)",
);

$Self->Is(
    $Attachments[0]->{Filename} || '',
    'Cisco_fax.tif',
    "Attachment name",
);

$Self->Is(
    $Attachments[0]->{ContentType} || '',
    'image/tiff; name="Cisco_fax.tif"; application=faxbw image/tiff; name="Cisco_fax.tif"; application=faxbw',
    "Attachment content type is stored in one line",
);

1;
