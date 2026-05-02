@isTest
private class OnCo_WhatsAppInboundHandlerTest {

    // -------------------------------------------------------
    // Test data setup
    // -------------------------------------------------------
    @TestSetup
    static void setupTestData() {

        // Create Account (Patient)
        Account patient = new Account(
            Name = 'Anika Das',
            Phone = '+919656789876'
        );
        insert patient;

        // Create a ServiceAppointment with an appointment code
        ServiceAppointment sa = new ServiceAppointment(
            ParentRecordId = patient.Id,
            DueDate = Date.today().addDays(1),
            SchedStartTime = DateTime.now().addDays(1),
            SchedEndTime = DateTime.now().addDays(1).addHours(1),
            OnCo_Appointment_Code__c = 'APT-Q7MBL',
            Status = 'Scheduled'
        );
        insert sa;
    }

    // -------------------------------------------------------
    // Helper: Build a mock REST request
    // -------------------------------------------------------
    private static void setupRestRequest(String fromNumber, String body, String messageSid) {

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/whatsapp/inbound';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/x-www-form-urlencoded');

        // Simulate Twilio's form params (as Salesforce parses them into req.params)
        req.params.put('From', 'whatsapp:' + fromNumber);
        req.params.put('Body', body);
        req.params.put('MessageSid', messageSid);
        req.params.put('ProfileName', 'Test Patient');
        req.params.put('AccountSid', 'AC_TEST_PLACEHOLDER');
        req.params.put('NumMedia', '0');

        RestContext.request = req;
        RestContext.response = res;
    }

    // -------------------------------------------------------
    // Test: Patient confirms appointment with YES
    // -------------------------------------------------------
    @isTest
    static void testConfirmAppointment() {

        setupRestRequest('+919656789876', 'YES APT-Q7MBL', 'SM_TEST_001');

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new TwilioCalloutMock());
        OnCo_WhatsAppInboundHandler.handleIncomingMessage();
        Test.stopTest();

        // Verify appointment status updated to Confirmed
        ServiceAppointment sa = [
            SELECT Status
            FROM ServiceAppointment
            WHERE OnCo_Appointment_Code__c = 'APT-Q7MBL'
            LIMIT 1
        ];
        System.assertEquals('Confirmed', sa.Status, 'Appointment should be confirmed');

        // Verify message log was created
        List<OnCo_WhatsApp_Message_Log__c> logs = [
            SELECT OnCo_Phone_Number__c, OnCo_Message_Body__c, OnCo_Direction__c
            FROM OnCo_WhatsApp_Message_Log__c
            WHERE OnCo_Message_SID__c = 'SM_TEST_001'
        ];
        System.assertEquals(1, logs.size(), 'One log record should be created');
        System.assertEquals('Inbound', logs[0].OnCo_Direction__c);
        System.assertEquals('+919656789876', logs[0].OnCo_Phone_Number__c);
    }

    // -------------------------------------------------------
    // Test: Patient cancels appointment with NO
    // -------------------------------------------------------
    @isTest
    static void testCancelAppointment() {

        setupRestRequest('+919656789876', 'NO APT-Q7MBL', 'SM_TEST_002');

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new TwilioCalloutMock());
        OnCo_WhatsAppInboundHandler.handleIncomingMessage();
        Test.stopTest();

        ServiceAppointment sa = [
            SELECT Status
            FROM ServiceAppointment
            WHERE OnCo_Appointment_Code__c = 'APT-Q7MBL'
            LIMIT 1
        ];
        System.assertEquals('Canceled', sa.Status, 'Appointment should be cancelled');
    }

    // -------------------------------------------------------
    // Test: Patient confirms with lowercase "y"
    // -------------------------------------------------------
    @isTest
    static void testConfirmWithLowercase() {

        setupRestRequest('+919656789876', 'y APT-Q7MBL', 'SM_TEST_003');

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new TwilioCalloutMock());
        OnCo_WhatsAppInboundHandler.handleIncomingMessage();
        Test.stopTest();

        ServiceAppointment sa = [
            SELECT Status
            FROM ServiceAppointment
            WHERE OnCo_Appointment_Code__c = 'APT-Q7MBL'
            LIMIT 1
        ];
        System.assertEquals('Confirmed', sa.Status, 'Lowercase y should also confirm');
    }

    // -------------------------------------------------------
    // Test: Patient sends code first "APT-Q7MBL YES"
    // -------------------------------------------------------
    @isTest
    static void testCodeFirstThenAction() {

        setupRestRequest('+919656789876', 'APT-Q7MBL YES', 'SM_TEST_004');

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new TwilioCalloutMock());
        OnCo_WhatsAppInboundHandler.handleIncomingMessage();
        Test.stopTest();

        ServiceAppointment sa = [
            SELECT Status
            FROM ServiceAppointment
            WHERE OnCo_Appointment_Code__c = 'APT-Q7MBL'
            LIMIT 1
        ];
        System.assertEquals('Confirmed', sa.Status, 'Code-first format should work');
    }

    // -------------------------------------------------------
    // Test: No appointment code in message
    // -------------------------------------------------------
    @isTest
    static void testMissingAppointmentCode() {

        setupRestRequest('+919656789876', 'YES', 'SM_TEST_005');

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new TwilioCalloutMock());
        OnCo_WhatsAppInboundHandler.handleIncomingMessage();
        Test.stopTest();

        // Appointment should remain unchanged
        ServiceAppointment sa = [
            SELECT Status
            FROM ServiceAppointment
            WHERE OnCo_Appointment_Code__c = 'APT-Q7MBL'
            LIMIT 1
        ];
        System.assertEquals('Scheduled', sa.Status, 'Status should not change without a valid code');
    }

    // -------------------------------------------------------
    // Test: Invalid appointment code
    // -------------------------------------------------------
    @isTest
    static void testInvalidAppointmentCode() {

        setupRestRequest('+919656789876', 'YES APT-ZZZZZ', 'SM_TEST_006');

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new TwilioCalloutMock());
        OnCo_WhatsAppInboundHandler.handleIncomingMessage();
        Test.stopTest();

        // Appointment should remain unchanged
        ServiceAppointment sa = [
            SELECT Status
            FROM ServiceAppointment
            WHERE OnCo_Appointment_Code__c = 'APT-Q7MBL'
            LIMIT 1
        ];
        System.assertEquals('Scheduled', sa.Status, 'Status should not change with invalid code');
    }

    // -------------------------------------------------------
    // Test: Phone number mismatch
    // -------------------------------------------------------
    @isTest
    static void testPhoneMismatch() {

        // Different phone number than what's on the Account
        setupRestRequest('+919656789876', 'YES APT-Q7MBL', 'SM_TEST_007');

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new TwilioCalloutMock());
        OnCo_WhatsAppInboundHandler.handleIncomingMessage();
        Test.stopTest();

        // Appointment should remain unchanged
        ServiceAppointment sa = [
            SELECT Status
            FROM ServiceAppointment
            WHERE OnCo_Appointment_Code__c = 'APT-Q7MBL'
            LIMIT 1
        ];
        System.assertEquals('Scheduled', sa.Status, 'Mismatched phone should not update status');
    }

    // -------------------------------------------------------
    // Test: Unrecognized action (e.g. "MAYBE")
    // -------------------------------------------------------
    @isTest
    static void testUnrecognizedAction() {

        setupRestRequest('+919656789876', 'MAYBE APT-Q7MBL', 'SM_TEST_008');

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new TwilioCalloutMock());
        OnCo_WhatsAppInboundHandler.handleIncomingMessage();
        Test.stopTest();

        // Appointment should remain unchanged
        ServiceAppointment sa = [
            SELECT Status
            FROM ServiceAppointment
            WHERE OnCo_Appointment_Code__c = 'APT-Q7MBL'
            LIMIT 1
        ];
        System.assertEquals('Scheduled', sa.Status, 'Unrecognized action should not update status');
    }

    // -------------------------------------------------------
    // Test: Empty message body
    // -------------------------------------------------------
    @isTest
    static void testEmptyMessageBody() {

        setupRestRequest('+919656789876', '', 'SM_TEST_009');

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new TwilioCalloutMock());
        OnCo_WhatsAppInboundHandler.handleIncomingMessage();
        Test.stopTest();

        // Log should still be created
        List<OnCo_WhatsApp_Message_Log__c> logs = [
            SELECT Id
            FROM OnCo_WhatsApp_Message_Log__c
            WHERE OnCo_Message_SID__c = 'SM_TEST_009'
        ];
        System.assertEquals(1, logs.size(), 'Log should be created even for empty messages');
    }

    // -------------------------------------------------------
    // Test: CONFIRM keyword works same as YES
    // -------------------------------------------------------
    @isTest
    static void testConfirmKeyword() {

        setupRestRequest('+919656789876', 'CONFIRM APT-Q7MBL', 'SM_TEST_010');

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new TwilioCalloutMock());
        OnCo_WhatsAppInboundHandler.handleIncomingMessage();
        Test.stopTest();

        ServiceAppointment sa = [
            SELECT Status
            FROM ServiceAppointment
            WHERE OnCo_Appointment_Code__c = 'APT-Q7MBL'
            LIMIT 1
        ];
        System.assertEquals('Confirmed', sa.Status, 'CONFIRM keyword should confirm appointment');
    }

    // -------------------------------------------------------
    // Test: CANCEL keyword works same as NO
    // -------------------------------------------------------
    @isTest
    static void testCancelKeyword() {

        setupRestRequest('+919656789876', 'CANCEL APT-Q7MBL', 'SM_TEST_011');

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new TwilioCalloutMock());
        OnCo_WhatsAppInboundHandler.handleIncomingMessage();
        Test.stopTest();

        ServiceAppointment sa = [
            SELECT Status
            FROM ServiceAppointment
            WHERE OnCo_Appointment_Code__c = 'APT-Q7MBL'
            LIMIT 1
        ];
        System.assertEquals('Canceled', sa.Status, 'CANCEL keyword should cancel appointment');
    }

    // -------------------------------------------------------
    // Mock HTTP callout for Twilio auto-reply
    // -------------------------------------------------------
    private class TwilioCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setBody('{"sid":"SM_MOCK_SID","status":"queued"}');
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }
}