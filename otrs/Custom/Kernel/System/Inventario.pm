 # --
 # Kernel/System/Inventario.pm - core module
 # Copyright (C) (year) (Jorge Hernández) (jorge.hernandez@ex-cle.com)
 # --
 # This software comes with ABSOLUTELY NO WARRANTY.  For details, see
 # the enclosed file COPYING for license information (GPL).  If you
 # did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
 # --

 package Kernel::System::Inventario;

 use strict;
 use warnings;

 # Lista todas las dependencias (eg Kernel::System::DB) aqui
 our @ObjectDependencies = (
     #'Kernel::System::DB',
 );


 #=head1 Name

# Inventario - Pequeño módulo de inventario

# =head1 DESCRIPTION

# Little OTRS module that displays the text 'Hello World' when called up.

# =head2 new()

# Create an object.  Do not use it directly, instead use:

#     my $InventarioObject = $Kernel::OM->Get('Kernel::System::Inventario');

# =cut*/

#Recibe los parámetros y crea un nuevo hash por objeto
 sub new {
     my ( $Type, %Param ) = @_;

     # allocate new hash for object
     my $Self = {};
     bless ($Self, $Type);

     return $Self;
 }

#

# =head2 GetHelloWorldText()

# Return the "Hello World" text.

#     my $HelloWorldText = $HelloWorldObject->GetHelloWorldText();

# =cut

 #método GetInventarioText()
 sub GetInventarioText {
     my ( $Self, %Param ) = @_;

     # Get the DBObject from the central object manager
     # my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    
     my $Inventario = $Self->_FormatInventarioText(
         String => 'Hello World',
     );

     return $Inventario;
 }

 #=begin Internal:

 #=cut

 #=head2 _FormatHelloWorldText()

# Format "Hello World" text to uppercase

     my $Inventario = $Self->_FormatInventarioText(
         String => 'Hello World',
     );

 sub _FormatInventarioText{
     my ( $Self, %Param ) = @_;
     #Formatea el texto en mayúsculas
     my $Inventario = uc $Param{String};

     return $Inventario;

 }

 #=end Internal:

 1;