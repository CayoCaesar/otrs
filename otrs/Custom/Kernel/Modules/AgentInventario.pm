# --
# Kernel/Modules/AgentInventario.pm - frontend modul
# Copyright (C) (year) (name of author) (email of author)
# --
# $Id: writing-otrs-application.xml,v 1.18 2010/01/28 12:47:33 martin Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentInventario;

use strict;
use warnings;

#use lib '../../';
use Kernel::System::Inventario;
use Kernel::System::Web::UploadCache;
use Kernel::System::LinkObject;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless ($Self, $Type);

    # check needed objects
    for (qw(ParamObject DBObject TicketObject LayoutObject LogObject QueueObject ConfigObject EncodeObject MainObject)) {
        if ( !$Self->{$_} ) {
            $Self->{LayoutObject}->FatalError( Message => "Got no $_!" );
        }
    }

    # create needed objects
    $Self->{InventarioObject} = Kernel::System::Inventario->new(%Param);
	$Self->{UploadCachObject}   = Kernel::System::Web::UploadCache->new(%Param);
	$Self->{LinkObject}         = Kernel::System::LinkObject->new(%Param);

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;
    my %Data = ();
	my $CentroAcopio ={};
	my $ElementoCentro={};
	
	$Data{Usuario} = $Self->{ParamObject}->GetParam( Param => 'Usuario' ) || '';
	
	if($Self->{ParamObject}->GetParam( Param => 'TicketID' ))
	{
		$Data{IdCentroConProblema} = $Self->{InventarioObject}->GetCodigoCentroProblema(IDTicket => $Self->{ParamObject}->GetParam( Param => 'TicketID' ));			
	}else{
		$Data{IdCentroConProblema} = $Self->{ParamObject}->GetParam( Param => 'IdCentroConProblema' );
	}
		    
	$Data{InventarioText} = $Self->{InventarioObject}->GetInventarioText();
	
	$Data{IdCentroAcopio} = $Self->{ParamObject}->GetParam( Param => 'IdCentroAcopio' );
	
	
    # get list type
    my $TreeView = 0;
    if ( $Self->{ConfigObject}->Get('Inventario::Frontend::ListType') eq 'tree' ) {
        $TreeView = 1;
    }
	
	#Buscar los centros de acopios para el centro con problemas
	
	$CentroAcopio = $Self->{InventarioObject}->GetCentroAcopio( IDCentro => $Data{IdCentroConProblema});
	
	$ElementoCentro = $Self->{InventarioObject}->GetElementoCentro( IDCentro => $Data{IdCentroAcopio});
	
	$Data{CentrosAcopio} = $Self->{LayoutObject}->BuildSelection(
            Data         => $CentroAcopio,
            Name         => 'CodigoCentro',
            SelectedID   => $Data{IdCentroAcopio},
#			SelectedValue => $Data{IdCentroAcopio}, 
            PossibleNone => 1,
            TreeView     => $TreeView ,
            Sort         => 'TreeView',
            Translation  => 0,
            Max          => 200,
			OnChange	 => 'buscarItem()',
        );		
		
		$Data{Elementos} = $Self->{LayoutObject}->BuildSelection(
				Data         => $ElementoCentro,
				Name         => 'IdInventario',
				SelectedID   => 1,
				PossibleNone => 1,
				Multiple   => 0,
				TreeView     => $TreeView,
				Sort         => 'TreeView',
				Translation  => 0,
				Max          => 200,
		
			);		
#			$Self->{LogObject}->Log(
#				Priority => 'Notice',
#				Message => 'centro: '.$Data{IdCentroAcopio},
#			);		
	
    my $Output = $Self->{LayoutObject}->Header(Title => "Inventario");
#    $Output   .= $Self->{LayoutObject}->NavigationBar();
     $Output   .= $Self->{LayoutObject}->Output(
        Data => \%Data,
        TemplateFile => 'AgentInventario',
    );
    $Output   .= $Self->{LayoutObject}->Footer();
    return $Output;
}

1;