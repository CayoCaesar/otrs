"use strict";var Core=Core||{};Core.Agent=Core.Agent||{};Core.Agent.Admin=Core.Agent.Admin||{};Core.Agent.Admin.QueueTemplates=(function(TargetNS){TargetNS.Init=function(){Core.Form.InitSelectAllCheckboxes($('table td input[type="checkbox"][name=ItemsSelected]'),$('#SelectAllItemsSelected'));$('input[type="checkbox"][name=ItemsSelected]').click(function(){Core.Form.SelectAllCheckboxes($(this),$('#SelectAllItemsSelected'));});Core.UI.Table.InitTableFilter($("#Filter"),$("#ItemsTable"));Core.UI.Table.InitTableFilter($("#FilterTemplates"),$("#Templates"));Core.UI.Table.InitTableFilter($("#FilterQueues"),$("#Queues"));};Core.Init.RegisterNamespace(TargetNS,'APP_MODULE');return TargetNS;}(Core.Agent.Admin.QueueTemplates||{}));

