@RestResource(urlMapping='/whatsapp/inbound')
global class OnCo_WhatsAppInboundHandler {

    @HttpPost
    global static void handleIncomingMessage() {

        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        // Twilio sends data as form params
        Map<String, String> params = req.params;

        String fromNumber  = params.get('From');
        String body        = params.get('Body');
        String messageSid  = params.get('MessageSid');
        String profileName = params.get('ProfileName');

        System.debug(LoggingLevel.INFO, '--- Incoming WhatsApp Message ---');
        System.debug(LoggingLevel.INFO, 'From: ' + fromNumber);
        System.debug(LoggingLevel.INFO, 'Body: ' + body);
        System.debug(LoggingLevel.INFO, 'MessageSid: ' + messageSid);
        System.debug(LoggingLevel.INFO, 'ProfileName: ' + profileName);

        // Clean the phone number
        String cleanPhone = '';
        if (String.isNotBlank(fromNumber)) {
            cleanPhone = fromNumber.replace('whatsapp:', '').replaceAll('\\s', '').trim();
        }

        System.debug(LoggingLevel.INFO, 'Cleaned phone: ' + cleanPhone);

        // Process the reply FIRST (this does callouts via sendAutoReply)
        if (String.isNotBlank(body)) {
            processPatientReply(cleanPhone, body.trim());
        }

        // Log the inbound message AFTER all callouts are done
        createInboundLog(cleanPhone, body, messageSid);

        // Respond to Twilio with empty TwiML
        res.statusCode = 200;
        res.addHeader('Content-Type', 'text/xml');
        res.responseBody = Blob.valueOf(
            '<?xml version="1.0" encoding="UTF-8"?><Response></Response>'
        );
    }

    // -------------------------------------------------------
    // Log every inbound message for audit trail
    // -------------------------------------------------------
    private static void createInboundLog(String phone, String body, String sid) {
        try {
            OnCo_WhatsApp_Message_Log__c log = new OnCo_WhatsApp_Message_Log__c();
            log.OnCo_Phone_Number__c  = phone;
            log.OnCo_Message_Body__c  = body;
            log.OnCo_Message_SID__c   = sid;
            log.OnCo_Direction__c     = 'Inbound';
            log.OnCo_Received_At__c   = Datetime.now();
            insert log;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error creating message log: ' + e.getMessage());
        }
    }

    // -------------------------------------------------------
    // Parse the reply and extract action + appointment code
    // -------------------------------------------------------
    private static void processPatientReply(String phone, String reply) {

        String aptCode = extractAppointmentCode(reply);
        String action  = extractAction(reply);

        System.debug(LoggingLevel.INFO, 'Parsed action: ' + action + ' | Code: ' + aptCode);

        if (String.isBlank(aptCode)) {
            sendAutoReply(phone,
                'We could not identify your appointment. '
                + 'Please reply in the format: YES APT-XXXXX or NO APT-XXXXX '
                + '(using the code from your reminder message).');
            return;
        }

        List<ServiceAppointment> appointments = [
            SELECT Id,
                   Account.Name,
                   Account.Phone,
                   DueDate,
                   SchedStartTime,
                   OnCo_Appointment_Code__c,
                   Status
            FROM ServiceAppointment
            WHERE OnCo_Appointment_Code__c = :aptCode
            LIMIT 1
        ];

        if (appointments.isEmpty()) {
            System.debug(LoggingLevel.WARN, 'No appointment found for code: ' + aptCode);
            sendAutoReply(phone,
                'We could not find an appointment with code ' + aptCode + '. '
                + 'Please double-check the code from your reminder message '
                + 'or call our office for assistance.');
            return;
        }

        ServiceAppointment appt = appointments[0];
        String patientName = appt.Account.Name;
        String apptDate    = appt.SchedStartTime != null
            ? appt.SchedStartTime.format('EEEE, MMMM d, yyyy \'at\' h:mm a')
            : appt.DueDate.format();

        // Verify phone matches
        String apptPhone = appt.Account.Phone != null
            ? appt.Account.Phone.replaceAll('\\s', '')
            : '';

        if (apptPhone != phone) {
            System.debug(LoggingLevel.WARN,
                'Phone mismatch. Incoming: ' + phone + ' | Appointment: ' + apptPhone);
            sendAutoReply(phone,
                'The appointment code ' + aptCode
                + ' does not match your phone number on file. '
                + 'Please call our office for assistance.');
            return;
        }

        // Handle the action
        // NOTE: Update appointment AFTER the callout to avoid the same error
        if (action == 'YES' || action == 'CONFIRM' || action == 'Y') {

            // Callout first
            sendAutoReply(phone,
                'Thank you ' + patientName + '! '
                + 'Your appointment (' + aptCode + ') on '
                + apptDate + ' has been confirmed. '
                + 'We look forward to seeing you!');

            // DML after callout
            appt.Status = 'Confirmed';
            update appt;

            System.debug(LoggingLevel.INFO,
                'Appointment ' + aptCode + ' confirmed by ' + patientName);

        } else if (action == 'NO' || action == 'CANCEL' || action == 'N') {

            // Callout first
            sendAutoReply(phone,
                'Your appointment (' + aptCode + ') on '
                + apptDate + ' has been cancelled. '
                + 'Please call us if you would like to reschedule.');

            // DML after callout
            appt.Status = 'Canceled';
            update appt;

            System.debug(LoggingLevel.INFO,
                'Appointment ' + aptCode + ' cancelled by ' + patientName);

        } else {
            sendAutoReply(phone,
                'We received your message for appointment ' + aptCode + '. '
                + 'Please reply with:\n'
                + 'YES ' + aptCode + ' - to confirm\n'
                + 'NO ' + aptCode + ' - to cancel');
        }
    }

    // -------------------------------------------------------
    // Extract appointment code (APT-XXXXX) from message
    // -------------------------------------------------------
    private static String extractAppointmentCode(String message) {
        if (String.isBlank(message)) return null;

        String upperMsg = message.toUpperCase().trim();
        Pattern p = Pattern.compile('APT-[A-Z0-9]{4,6}');
        Matcher m = p.matcher(upperMsg);

        if (m.find()) {
            return m.group();
        }
        return null;
    }

    // -------------------------------------------------------
    // Extract the action word (YES/NO/CONFIRM/CANCEL)
    // -------------------------------------------------------
    private static String extractAction(String message) {
        if (String.isBlank(message)) return '';

        String upperMsg = message.toUpperCase().trim();

        Pattern p = Pattern.compile('APT-[A-Z0-9]{4,6}');
        Matcher m = p.matcher(upperMsg);
        String actionPart = m.replaceAll('').trim();

        actionPart = actionPart.replaceAll('\\s+', ' ').trim();

        return actionPart;
    }

    // -------------------------------------------------------
    // Send auto-reply using existing Twilio service
    // -------------------------------------------------------
    private static void sendAutoReply(String toPhone, String message) {
        try {
            OnCo_TwilioWhatsAppService.sendWhatsAppMessage(toPhone, message);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error sending auto-reply to '
                         + toPhone + ': ' + e.getMessage());
        }
    }
}