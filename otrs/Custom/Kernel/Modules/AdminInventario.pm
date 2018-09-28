# --
 # Kernel/Modules/AgentHelloWorld.pm - frontend module
 # Copyright (C) (year) (name of author) (email of author)
 # --
 # This software comes with ABSOLUTELY NO WARRANTY.  For details, see
 # the enclosed file COPYING for license information (GPL).  If you
 # did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
 # --

 package Kernel::Modules::AgentHelloWorld;

 use strict;
 use warnings;

 # Frontend modules are not handled by the ObjectManager.
 our $ObjectManagerDisabled = 1;

 sub new {
     my ( $Type, %Param ) = @_;

     # allocate new hash for object
     my $Self = {%Param};
     bless ($Self, $Type);

     return $Self;
 }

 sub Run {
     my ( $Self, %Param ) = @_;
     my %Data = ();

     my $HelloWorldObject = $Kernel::OM->Get('Kernel::System::HelloWorld');
     my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

     $Data{HelloWorldText} = $HelloWorldObject->GetHelloWorldText();

     # build output
     my $Output = $LayoutObject->Header(Title => "HelloWorld");
     $Output .= $LayoutObject->NavigationBar();
     $Output .= $LayoutObject->Output(
         Data => \%Data,
         TemplateFile => 'AgentHelloWorld',
     );
     $Output .= $LayoutObject->Footer();

     return $Output;
 }

 1;