# --
# Kernel/System/Inventario.pm - core modul
# Copyright (C) (year) (name of author) (email of author)
# --
# $Id: writing-otrs-application.xml,v 1.18 2010/01/28 12:47:33 martin Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Inventario;

use strict;
use warnings;

#se crea el constructor de la clase inventario (módulo de inventario)

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
	#se asigna un nuevo hash al objeto.
    my $Self = {};
    bless ($Self, $Type);
    # get needed objects
    # Obtiene los objetos necesarios
    for (qw(ConfigObject LogObject TimeObject DBObject MainObject EncodeObject)) {
        if ( $Param{$_} ) {
            $Self->{$_} = $Param{$_};
        }
        else {
            die "Got no $_!";
        }
    }
    return $Self;
}


sub GetInventarioText {
    my ( $Self, %Param ) = @_;

    return 'Seleccionar centro de acopios';
}

#Obtiene los elementos que se encuentran disponibles en un CAC.(Consulta de inventario)
sub GetElementoCentro{
	my ( $Self, %Param ) = @_;
	my %ElementoCentro = ();
		
	my $SQL =	'SELECT i.id, it.descripcion
				  FROM inventario i,
					   items it,
					   baul b,
					   centros c
				 WHERE     i.id_item = it.id
					   AND i.id_baul = b.id
					   AND b.id_centro = c.id
					   AND c.id = ?
					   AND(i.reserva_item = 0 AND i.entregado = 0)
				 group by it.descripcion
				 order by 2';

    # fetch the result
    return if !$Self->{DBObject}->Prepare(
        SQL   => $SQL,
        Bind  => [ \$Param{IDCentro} ],
	);
	
	
	while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
		$ElementoCentro{$Row[0]} = $Row[1];
		
#		$Self->{LogObject}->Log(
#			Priority => 'Notice',
#			Message => 'centro: '.$Row[1],
#		);		
	}	
	
	#$Data{CentroProblema} = $Self->{ParamObject}->GetParam( Param => 'Centro' );
	# Buscar centros de acopios en base de datos.	
	return \%ElementoCentro;
}


#obtine el código del centro de votación de destino del reemplazo
sub GetCodigoCentroProblema{
	my ( $Self, %Param ) = @_;
	my $CentroAcopio;
	
	my $SQL =	'select substring(s.name,1,9) from ticket t 
					inner join service s on s.id = t.service_id
					where t.id = ?';

    # fetch the result
    return if !$Self->{DBObject}->Prepare(
        SQL   => $SQL,
        Bind  => [ \$Param{IDTicket} ],
	);
	
#		$Self->{LogObject}->Log(
#			Priority => 'Notice',
#			Message => 'centro: '.$Param{IDTicket},
#		);	
		
	while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {

		$CentroAcopio = $Row[0];
	
	}

	my @CentroAcopioDepurado = split('-',$CentroAcopio);
	$CentroAcopio=$CentroAcopioDepurado[0];

	$CentroAcopio =~ s/^\s+//;
	$CentroAcopio =~ s/\s+$//;

	if(length($CentroAcopio)==8)
	{
		$CentroAcopio = '0'.$CentroAcopio;
	}
	
	return $CentroAcopio;
}

#obtiene los datos del centro de acopio (id, nombre y código)
sub GetCentroAcopio {
	my ( $Self, %Param ) = @_;
	my %CentroAcopio = ();

		$Self->{LogObject}->Log(
			Priority => 'Notice',
			Message => 'centro: '.$Param{IDCentro},
		);	

	my $SQL =	'SELECT DISTINCT C1.codigo_centro, C1.nombre_centro, C1.id
					FROM centros C1
					INNER JOIN centro_acopio CA ON C1.id = CA.id_centro
					INNER JOIN centros C ON CA.codigo_estado = C.codigo_estado AND CA.circunscripcion = C.circunscripcion
					WHERE C.codigo_centro = ?';

    # fetch the result
    return if !$Self->{DBObject}->Prepare(
        SQL   => $SQL,
        Bind  => [ \$Param{IDCentro}],
	);
	
	
	while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {

		$CentroAcopio{$Row[2]} = $Row[0].' - '.$Row[1];
	
	}	

	return \%CentroAcopio;
}

#Busca si existe el ticket.
sub BuscarSiExisteElTicket{
	my ( $Self, %Param ) = @_;
	my $siExiste;

	my $SQL ="SELECT count(*) FROM inventario i
				inner join ticket t on t.id = i.id_ticket
				where id_ticket = ?";

	$Self->{DBObject}->Prepare(
		SQL   => $SQL,
		Bind  => [ \$Param{IDTicket} ],
	);

	while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {

		$siExiste = $Row[0];	
	}	

    #$Self->{LogObject}->Log(
    #    Priority => 'error',
    #    Message => 'el ticket '. $Param{IDTicket}.' tiene un '.$siExiste,
    #);

	return $siExiste;
}


#realiza la reserva del item del inventario

sub ReservarItemCentroAcopio {
	my ( $Self, %Param ) = @_;
	my $IdBaul;
	my $IdItem;

	
	my $SQL = "update inventario set 
				reserva_item = 1, 
				id_ticket = ?, 
				codigo_centro_destino = ?, 
				seleccionado = 1
			WHERE id = ?";
	
		$Self->{DBObject}->Do(
			SQL=> $SQL,
			Bind  => [ \$Param{IdTicket},\$Param{IDCentro},\$Param{IdInventario} ],
		);
		
#		$Self->{LogObject}->Log(
#			Priority => 'error',
#			Message => 'mensaje '.$SQL.' '.$Param{IdTicket} ,
#		);		

		$SQL ="select i.id_baul, i.id_item from inventario i where i.id=?";
		$Self->{DBObject}->Prepare(
				SQL   => $SQL,
				Bind  => [ \$Param{IdInventario} ],
				Limit => 1,
			);
						
			while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {

				$IdBaul = $Row[0];
				$IdItem = $Row[1];
			
			}		
		if($IdItem != 5)
		{
			$Self->{DBObject}->Do(
			SQL=> "update inventario
						set inventario.reserva_item = 1
					WHERE inventario.id_baul = ?
						and inventario.entregado = 0
						and inventario.seleccionado = 0
						and inventario.id_item <> 5",
					
			Bind  => [ \$IdBaul ],
			);
		}
	#$Data{CentroProblema} = $Self->{ParamObject}->GetParam( Param => 'Centro' );
	# Verificar si el item requiere reservar el baul, en caso afirmativo se actualiza el campo reserva en baul.
	# Actualizar en el contenedor el campo reservar_item = true, id_centro_destino = centroProblema y id_ticket = IdTicket.
}

sub ConfirmarEntregaItem {
	my ( $Self, %Param ) = @_;
		
	my $SQL =	'update inventario set reserva_item = 1, entregado = 1 where id_ticket = ? and seleccionado = 1';

    # fetch the result
    return if !$Self->{DBObject}->Do(
        SQL   => $SQL,
        Bind  => [ \$Param{IDTicket} ],
	);
}
sub CambiarStatusTicket {
	my ( $Self, %Param ) = @_;
		
	my $SQL =	'update ticket set ticket_state_id = 6 where id = ?';

    # fetch the result
    return if !$Self->{DBObject}->Do(
        SQL   => $SQL,
        Bind  => [ \$Param{IdTicket} ],
	);	
}
sub RealizarDevolucion {
	my ( $Self, %Param ) = @_;
		
#	my $SQL =	'update inventario set reserva_item = 0 where id_baul = ? and reserva_item = 1 and entregado = 0';
	my $SQL =	'update inventario set reserva_item = 0 where id_baul = ?';

    # fetch the result
    return if !$Self->{DBObject}->Do(
        SQL   => $SQL,
        Bind  => [ \$Param{IdBaul} ],
	);	
}
sub GetListaItemEnReserva {
	my ( $Self, %Param ) = @_;
		my $Datos;
		my $Contador = 0;
		my $SQL ="SELECT i.codigo_centro_destino,
				c.nombre_centro,
				i.id_baul,
				i.id_ticket,
				concat(cu.first_name, ' ', cu.last_name) nombre_ts,
				cu.mobile,
				cu.phone,
				t.tn
			FROM inventario i,
				centros c,
				ticket t,
				customer_user cu
			WHERE     i.codigo_centro_destino = c.codigo_centro
				AND i.id_baul IN (SELECT id_baul
                           FROM inventario
                          WHERE inventario.entregado = 1 and inventario.reserva_item =1 and inventario.id_item <>5)
				AND i.id_ticket = t.id
				AND t.customer_id = cu.customer_id
				and i.id_item <>5
				and i.entregado = 1
				and i.reserva_item =1";
		$Self->{DBObject}->Prepare(
				SQL   => $SQL,
#				Bind  => [ \$Param{IdInventario} ],
				Limit => 30,
			);
			
			while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
			
			if($Contador == 0){
				$Datos = $Datos.'<tr class="searchactive">';
				$Contador == 1;
			}else{
				$Contador == 0;
				$Datos = $Datos.'<tr class="searchpassive">';
			}
				$Datos = $Datos.'<td > <a href="" onclick="DevolucionSubmit('.$Row[2].');">
							'.$Row[7].'</a>
							</td>
							<td > '.$Row[0].'</td>
							<td > '.$Row[1].'</td>
							<td > '.$Row[4].'</td>
							<td > '.$Row[6].'</td>
							<td > '.$Row[5].'</td>
						</tr>';
			
			}
		return $Datos;
}
1;
