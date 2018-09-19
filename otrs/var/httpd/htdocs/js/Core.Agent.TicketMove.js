// --
// Copyright (C) 2001-2018 OTRS AG, http://otrs.com/
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (AGPL). If you
// did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};

/**
 * @namespace Core.Agent.TicketMove
 * @memberof Core.Agent
 * @author OTRS AG
 * @description
 *      This namespace contains special module functions for AgentTicketMove.
 */
Core.Agent.TicketMove = (function (TargetNS) {

    /**
     * @name Init
     * @memberof Core.Agent.TicketMove
     * @function
     * @description
     *      This function initializes the module functionality.
     */
    TargetNS.Init = function () {

        var DynamicFieldNames = Core.Config.Get('DynamicFieldNames'),
            Fields = ['NewUserID', 'DestQueueID', 'NewStateID', 'NewPriorityID'],
            ModifiedFields;

        // Bind event to Owner get all button
        $('#OwnerSelectionGetAll').on('click', function () {
            $('#OwnerAll').val('1');
            Core.AJAX.FormUpdate($('#MoveTicketToQueue'), 'AJAXUpdate', 'OwnerAll', ['NewUserID'], function() {
                $('#NewUserID').focus();
            });
            return false;
        });

        // Bind events to specific fields
        $.each(Fields, function(Index, Value) {
            ModifiedFields = Core.Data.CopyObject(Fields).concat(DynamicFieldNames);
            ModifiedFields.splice(Index, 1);

            if (Value !== 'DestQueueID') {
                ModifiedFields.push('StandardTemplateID');
            }

            FieldUpdate(Value, ModifiedFields);
        });

        // Bind event to StandardTemplate field
        $('#StandardTemplateID').on('change', function () {
            Core.Agent.TicketAction.ConfirmTemplateOverwrite('RichText', $(this), function () {
                Core.AJAX.FormUpdate($('#MoveTicketToQueue'), 'AJAXUpdate', 'StandardTemplateID', ['RichTextField']);
            });
            return false;
        });

        // Initialize the ticket action popup.
        Core.Agent.TicketAction.Init();
    };

    /**
     * @private
     * @name FieldUpdate
     * @memberof Core.Agent.TicketMove
     * @function
     * @param {String} Value - FieldID
     * @param {Array} ModifiedFields - Fields
     * @description
     *      Create on change event handler
     */
    function FieldUpdate (Value, ModifiedFields) {
        $('#' + Value).on('change', function () {
            Core.AJAX.FormUpdate($('#MoveTicketToQueue'), 'AJAXUpdate', Value, ModifiedFields);
        });
    }

    Core.Init.RegisterNamespace(TargetNS, 'APP_MODULE');

    return TargetNS;
}(Core.Agent.TicketMove || {}));
