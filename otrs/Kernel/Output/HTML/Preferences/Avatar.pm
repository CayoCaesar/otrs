# --
# Copyright (C) 2001-2018 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Preferences::Avatar;

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::System::Web::Request',
    'Kernel::Config',
    'Kernel::System::AuthSession',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    for my $Needed (qw(UserID UserObject ConfigItem)) {
        die "Got no $Needed!" if ( !$Self->{$Needed} );
    }

    return $Self;
}

sub Param {
    my ( $Self, %Param ) = @_;

    my $AvatarEngine = $Kernel::OM->Get('Kernel::Config')->Get('Frontend::AvatarEngine');
    my $Return       = {
        AvatarEngine => $AvatarEngine,
    };

    if ( $AvatarEngine eq 'Gravatar' && $Self->{UserEmail} ) {
        $Return->{Avatar} = '//www.gravatar.com/avatar/' . md5_hex( lc $Self->{UserEmail} ) . '?s=45&d=mm';
    }

    return $Return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    return 1;
}

sub Error {
    my ( $Self, %Param ) = @_;

    return $Self->{Error} || '';
}

sub Message {
    my ( $Self, %Param ) = @_;

    return $Self->{Message} || '';
}

1;
