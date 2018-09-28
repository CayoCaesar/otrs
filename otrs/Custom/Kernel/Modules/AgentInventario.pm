# --
 # Kernel/Modules/AgentInventario.pm - frontend module
 # Copyright (C) (year) (Jorge Hernandez) (jorge.hernandez@ex-cle.com)
 # --
 # This software comes with ABSOLUTELY NO WARRANTY.  For details, see
 # the enclosed file COPYING for license information (GPL).  If you
 # did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
 # --

 package Kernel::Modules::AgentInventario;

 use strict;
 use warnings;

 # Frontend modules are not handled by the ObjectManager.
 our $ObjectManagerDisabled = 1;

#Recibe los parámetros.
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

    #Crea el objeto inventario y el objeto LayoutObject
     my $InventarioObject = $Kernel::OM->Get('Kernel::System::Inventario');
     my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');


    #Del objeto Inventario usa el método GetInventarioText y lo almacena en la variable Data{InventarioText}
     $Data{InventarioText} = $InventarioObject->GetInventarioText();

     # Construye la salida
     my $Output = $LayoutObject->Header(Title => "Inventario");
     $Output .= $LayoutObject->NavigationBar();
     $Output .= $LayoutObject->Output(
         Data => \%Data,
         TemplateFile => 'AgentInventario',
     );
     $Output .= $LayoutObject->Footer();

     return $Output;
 }

 1;