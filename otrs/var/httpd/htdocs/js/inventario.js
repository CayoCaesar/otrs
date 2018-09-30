// inventario.js. Creado por Jorge Hernandez (jorge.hernandez@ex-cle.com)
//
// Archivo JS cuya función es la de realizar las validaciones necesarias para que se despliegue 
// el frame que permite la autorización de reemplazo. La validaciones sólo se harán en la vista
// de creación de tickets. El frame se despliegará en la vista de creación y en la de detalle del
// ticket.

//función que crea el frame que despliega el formulario. Se le debe de pasar al frame el código del centro de votación.
//cuando se abre el frame debe de mostrarse un formulario de autenticación y, luego de autenticar
//el correspondiente a la autorización. Al cerrar el formulario debe de pasarle a la vista que invocó
// el frame, los datos correspondientes a las notas que se deben de generar.

//Esta función debe cargarse con el loader o por medio de un enlace en el template.

function frameInv(event){
    var InvFrame = '<iframe class="TextOption FAQ" src="' + Core.Config.Get('CGIHandle') + '?' + '' + 'Action=AgentInventario;"></iframe>';
    Core.UI.Dialog.ShowContentDialog(InvFrame, '', '10px', 'Center', true);
    return false;
}