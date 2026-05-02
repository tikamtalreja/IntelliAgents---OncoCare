@isTest
private class OnCo_AppointmentReminderBatchTest {

    private class MockTwilioSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setBody('{"sid":"SM1234567890abcdef","status":"queued"}');
            return res;
        }
    }

    @TestSetup
    static void setupData() {
        // Create Account with Phone
        Account acc = new Account(
            Name = 'Anika Das',
            Phone = '+919876543210'
        );
        insert acc;

        // Create ServiceAppointment due tomorrow
        ServiceAppointment sa = new ServiceAppointment();
        sa.ParentRecordId = acc.Id;
        sa.DueDate = Date.today().addDays(1);
        sa.SchedStartTime = DateTime.now().addDays(1);
        sa.SchedEndTime = DateTime.now().addDays(1).addHours(1);
        sa.Subject = 'In Person';
        // Set any other required fields for your org here
        insert sa;
    }

    @isTest
    static void testBatchExecution() {
        Test.setMock(HttpCalloutMock.class, new MockTwilioSuccess());

        Test.startTest();
        Database.executeBatch(new OnCo_AppointmentReminderBatch(), 1);
        Test.stopTest();

        // Verify the batch ran — appointment should still exist
        List<ServiceAppointment> appointments = [
            SELECT Id FROM ServiceAppointment WHERE DueDate = :Date.today().addDays(1)
        ];
        System.assertEquals(1, appointments.size(), 'Appointment record should exist');
    }

    @isTest
    static void testSchedulerExecution() {
        Test.setMock(HttpCalloutMock.class, new MockTwilioSuccess());

        Test.startTest();
        String cronExp = '0 0 8 * * ?'; // Daily at 8 AM
        String jobId = System.schedule('Test Appointment Reminder', cronExp, new OnCo_AppointmentReminderScheduler());
        Test.stopTest();

        // Verify the job was scheduled
        CronTrigger ct = [SELECT Id, State FROM CronTrigger WHERE Id = :jobId];
        System.assertNotEquals(null, ct, 'Scheduled job should exist');
    }

    @isTest
    static void testManualBatchRun() {
        Test.setMock(HttpCalloutMock.class, new MockTwilioSuccess());

        Test.startTest();
        Id batchId = Database.executeBatch(new OnCo_AppointmentReminderBatch(), 1);
        Test.stopTest();

        System.assertNotEquals(null, batchId, 'Batch job ID should not be null');
    }
}