public class OnCo_TwilioWhatsAppService {

    public class MessageResult {
        public Boolean success;
        public String messageSid;
        public String errorMessage;
        public Integer statusCode;

        public MessageResult(Boolean success, String messageSid, String errorMessage, Integer statusCode) {
            this.success = success;
            this.messageSid = messageSid;
            this.errorMessage = errorMessage;
            this.statusCode = statusCode;
        }
    }

    public static MessageResult sendWhatsAppMessage(String toNumber, String messageBody) {

        try {
            // Fetch credentials from Custom Metadata
            Twilio_Setting__mdt settings = Twilio_Setting__mdt.getInstance('Default');

            String accountSid = settings.OnCo_Account_SID__c;
            String authToken  = settings.OnCo_Account_Token__c;
            String fromNumber  = settings.OnCo_From_Number__c;

            System.debug(LoggingLevel.INFO, 'Twilio: Sending WhatsApp message to ' + toNumber);

            // Build the request
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.twilio.com/2010-04-01/Accounts/' + accountSid + '/Messages.json');
            req.setMethod('POST');
            req.setTimeout(30000);

            // Basic Auth header
            String credentials = accountSid + ':' + authToken;
            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(credentials)));
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

            // Message parameters
            String body = 'From=' + EncodingUtil.urlEncode('whatsapp:'+ fromNumber, 'UTF-8')
                + '&To=' + EncodingUtil.urlEncode('whatsapp:' + toNumber, 'UTF-8')
                + '&Body=' + EncodingUtil.urlEncode(messageBody, 'UTF-8');
            req.setBody(body);

            // Send the request
            Http http = new Http();
            HttpResponse res = http.send(req);

            // Parse response
            Integer statusCode = res.getStatusCode();
            String responseBody = res.getBody();

            System.debug(LoggingLevel.INFO, 'Twilio Response Status: ' + statusCode);
            System.debug(LoggingLevel.DEBUG, 'Twilio Response Body: ' + responseBody);

            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);

            if (statusCode == 201) {
                String messageSid = (String) responseMap.get('sid');
                System.debug(LoggingLevel.INFO, 'Twilio: Message sent successfully. SID: ' + messageSid);
                return new MessageResult(true, messageSid, null, statusCode);
            } else {
                String errorMsg = (String) responseMap.get('message');
                Integer errorCode = (Integer) responseMap.get('code');
                System.debug(LoggingLevel.ERROR, 'Twilio Error [' + errorCode + ']: ' + errorMsg);
                return new MessageResult(false, null, 'Twilio Error ' + errorCode + ': ' + errorMsg, statusCode);
            }

        } catch (System.CalloutException ce) {
            System.debug(LoggingLevel.ERROR, 'Twilio Callout Exception: ' + ce.getMessage());
            System.debug(LoggingLevel.ERROR, '   Stack Trace: ' + ce.getStackTraceString());
            return new MessageResult(false, null, 'Callout failed: ' + ce.getMessage(), 0);

        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, ' Twilio Unexpected Exception: ' + ex.getMessage());
            System.debug(LoggingLevel.ERROR, '   Type: ' + ex.getTypeName());
            System.debug(LoggingLevel.ERROR, '   Stack Trace: ' + ex.getStackTraceString());
            return new MessageResult(false, null, 'Unexpected error: ' + ex.getMessage(), 0);
        }
    }
}