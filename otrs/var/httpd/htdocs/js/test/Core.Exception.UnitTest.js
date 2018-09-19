// --
// Copyright (C) 2001-2018 OTRS AG, http://otrs.com/
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (AGPL). If you
// did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};

Core.Exception = (function (Namespace) {
    Namespace.RunUnitTests = function(){
        QUnit.module('Core.Exception');

        // ApplicationError
        QUnit.test('Core.Exception.ApplicationError()', function(Assert){
            var ErrorMessage = 'Test error message',
                ErrorTypes = ['Error', 'InternalError', 'TypeError', 'CommunicationError', 'ConnectionError'],
                ExceptionObject;

            Assert.expect(15);

            Core.Exception.HandleFinalError = function (Exception, ErrorType) {
                Assert.equal(Exception.GetType(), ErrorType, "Handle error type - " + ErrorType + ', error message - ' + ErrorMessage);
            };

            $.each(ErrorTypes, function() {
                try {
                    ExceptionObject = new Core.Exception.ApplicationError(ErrorMessage, this);
                    Core.Exception.HandleFinalError(ExceptionObject, this);

                    // test IsErrorOfType
                    Assert.equal(Core.Exception.IsErrorOfType(ExceptionObject,this), true, 'Exception type is - ' +  this);

                    // test Thrown function
                    Core.Exception.Throw(ErrorMessage, this);
                }
                catch (Error) {

                    // check if the exception is caught
                    Assert.ok(true, 'Error caught, error type \'' + ExceptionObject.GetType() + '\' is not correct!');
                }
            });

        });
    };

    return Namespace;
}(Core.Exception || {}));
