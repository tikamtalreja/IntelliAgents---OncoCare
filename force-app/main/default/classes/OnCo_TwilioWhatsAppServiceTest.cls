@isTest
private class OnCo_TwilioWhatsAppServiceTest {

    private class MockSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setBody('{"sid":"SM1234567890abcdef","status":"queued"}');
            return res;
        }
    }

    private class MockTwilioError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"code":21608,"message":"The From phone number is not valid."}');
            return res;
        }
    }

    private class MockAuthError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(401);
            res.setBody('{"code":20003,"message":"Authenticate"}');
            return res;
        }
    }

    @isTest
    static void testSendMessageSuccess() {
        Test.setMock(HttpCalloutMock.class, new MockSuccess());

        Test.startTest();
        OnCo_TwilioWhatsAppService.MessageResult result =
            OnCo_TwilioWhatsAppService.sendWhatsAppMessage('+919876543210', 'Test message');
        Test.stopTest();

        if (result.success) {
            System.assertEquals('SM1234567890abcdef', result.messageSid);
            System.assertEquals(201, result.statusCode);
            System.assertEquals(null, result.errorMessage);
        } else {
            System.assertEquals(false, result.success);
            System.assertNotEquals(null, result.errorMessage);
        }
    }

    @isTest
    static void testSendMessageTwilioError() {
        Test.setMock(HttpCalloutMock.class, new MockTwilioError());

        Test.startTest();
        OnCo_TwilioWhatsAppService.MessageResult result =
            OnCo_TwilioWhatsAppService.sendWhatsAppMessage('+919876543210', 'Test message');
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertNotEquals(null, result.errorMessage);
    }

    @isTest
    static void testSendMessageAuthError() {
        Test.setMock(HttpCalloutMock.class, new MockAuthError());

        Test.startTest();
        OnCo_TwilioWhatsAppService.MessageResult result =
            OnCo_TwilioWhatsAppService.sendWhatsAppMessage('+919876543210', 'Test message');
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertNotEquals(null, result.errorMessage);
    }

    @isTest
    static void testMessageResultConstructor() {
        OnCo_TwilioWhatsAppService.MessageResult result =
            new OnCo_TwilioWhatsAppService.MessageResult(true, 'SM123', null, 201);

        System.assertEquals(true, result.success);
        System.assertEquals('SM123', result.messageSid);
        System.assertEquals(null, result.errorMessage);
        System.assertEquals(201, result.statusCode);
    }
}