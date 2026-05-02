public class OnCo_AppointmentReminderBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Date tomorrow = Date.today().addDays(1);
        String CANCELLED= 'Canceled';
        String query = 'SELECT Id, Account.Name, Account.Phone, DueDate, SchedStartTime '
            + 'FROM ServiceAppointment '
            + 'WHERE DueDate >= :tomorrow and id =\'08pak000000M4TBAA0\' '
            + 'AND Account.Phone != null '
            + 'AND Status!=: CANCELLED';

        System.debug(LoggingLevel.INFO, 'Appointment Reminder Batch: Querying appointments due on ' + tomorrow + query);

        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<ServiceAppointment> scope) {
        System.debug(LoggingLevel.INFO, 'Processing ' + scope.size() + ' appointment(s) in this batch.');
        List<ServiceAppointment> toUpdate = new List<ServiceAppointment>();
        
        for (ServiceAppointment sa : scope) {
            String patientName = sa.Account.Name;
            //String phone = sa.Account.Phone;
            String phone = sa.Account.Phone.replaceAll('\\s', '');
            DateTime schedTime = sa.SchedStartTime;
            System.debug('schedTime+'+schedTime);
            // Generate unique appointment code
            String aptCode = 'APT-' + generateCode(5);
            sa.OnCo_Appointment_Code__c = aptCode;
            toUpdate.add(sa);

            // Format the appointment time for the message
            String formattedTime = schedTime != null
                ? schedTime.format('EEEE, MMMM d, yyyy \'at\' h:mm a')
                : 'scheduled for tomorrow';

 			String message = 'Hello ' + patientName + ', '
                + 'this is a reminder that you have an appointment '
                + formattedTime + '. '
                + 'Please reply YES ' + aptCode + ' to confirm or '
                + 'NO ' + aptCode + ' to cancel. '
                + 'Thank you!';

            System.debug(LoggingLevel.INFO, 'Sending reminder to ' + patientName + ' at ' + phone);

            OnCo_TwilioWhatsAppService.MessageResult result =
                OnCo_TwilioWhatsAppService.sendWhatsAppMessage(phone, message);

            if (result.success) {
                System.debug(LoggingLevel.INFO, ' Reminder sent to ' + patientName + ' | SID: ' + result.messageSid);
            } else {
                System.debug(LoggingLevel.ERROR, ' Failed to send to ' + patientName + ' | Error: ' + result.errorMessage);
            }
        }
        // Save the appointment codes
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO, 'Appointment Reminder Batch completed.');
    }
    
    // Generate a random alphanumeric code
    private String generateCode(Integer length) {
        String chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Excluded I, O, 0, 1 to avoid confusion
        String code = '';
        for (Integer i = 0; i < length; i++) {
            Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length());
            code += chars.substring(idx, idx + 1);
        }
        return code;
    }
    
}