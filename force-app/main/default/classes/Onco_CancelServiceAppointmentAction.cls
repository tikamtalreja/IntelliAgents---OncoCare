public without sharing class Onco_CancelServiceAppointmentAction {

    public class Input {
        @InvocableVariable(required=true)
        public Id appointmentId;

        @InvocableVariable
        public String uniqueCode; 
    }

    public class Output {
        @InvocableVariable
        public String message;

        @InvocableVariable
        public Boolean success;

        @InvocableVariable
        public String appointmentLink;
        
        @InvocableVariable
        public String appointmentLinkFormatted;

        @InvocableVariable
        public String hcpName; 
    }

    @InvocableMethod(
        label='Cancel Service Appointment'
        description='Cancel a Service Appointment after authenticating via Unique Code'
    )
    public static List<Output> cancelAppointment(List<Input> inputs) {

        List<Output> results = new List<Output>();
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();

        for (Input inp : inputs) {

            Output outRec = new Output();
            outRec.appointmentLink = baseUrl + '/lightning/r/ServiceAppointment/' 
                                   + inp.appointmentId + '/view';
			outRec.appointmentLinkFormatted = 'Link: <' + baseUrl + '/lightning/r/ServiceAppointment/' + inp.appointmentId + '/view|View Appointment>'; 
            if (inp.appointmentId == null) {
                outRec.message = 'Appointment ID is required';
                outRec.success = false;
                results.add(outRec);
                continue;
            }

           
            ServiceResource sr = null;

            if (String.isNotBlank(inp.uniqueCode)) {

                // Find User by unique code
                List<User> userList = [
                    SELECT Id, Name, Onco_Unique_Code__c
                    FROM User
                    WHERE Onco_Unique_Code__c = :inp.uniqueCode
                    AND IsActive = true
                    LIMIT 1
                ];

                if (userList.isEmpty()) {
                    outRec.message = 'Invalid unique code. Authentication failed.';
                    outRec.success = false;
                    results.add(outRec);
                    continue;
                }

                System.debug('Authenticated User: ' + userList[0].Name);

                // Find ServiceResource linked to this User
                List<ServiceResource> srList = [
                    SELECT Id, Name
                    FROM ServiceResource
                    WHERE RelatedRecordId = :userList[0].Id
                    AND IsActive = true
                    LIMIT 1
                ];

                if (srList.isEmpty()) {
                    outRec.message = 'No service resource found for this HCP.';
                    outRec.success = false;
                    results.add(outRec);
                    continue;
                }

                sr = srList[0];
                outRec.hcpName = sr.Name;
                System.debug('SR found: ' + sr.Name);
            }

            
            if (sr == null) {
                String currentUserId = UserInfo.getUserId();
                System.debug('Fallback UserInfo: ' + currentUserId);

                List<ServiceResource> srList = [
                    SELECT Id, Name
                    FROM ServiceResource
                    WHERE RelatedRecordId = :currentUserId
                    AND IsActive = true
                    LIMIT 1
                ];

                if (!srList.isEmpty()) {
                    sr = srList[0];
                    outRec.hcpName = sr.Name;
                    System.debug('SR via UserInfo: ' + sr.Name);
                }
            }

            
            if (sr != null) {

                List<AssignedResource> arList = [
                    SELECT Id, ServiceAppointmentId
                    FROM AssignedResource
                    WHERE ServiceResourceId = :sr.Id
                    AND ServiceAppointmentId = :inp.appointmentId
                    LIMIT 1
                ];

                if (arList.isEmpty()) {
                    outRec.message = 'You are not authorized to cancel this appointment.';
                    outRec.success = false;
                    results.add(outRec);
                    continue;
                }

                System.debug('Ownership verified for SR: ' + sr.Name);
            }

            // ─────────────────────────────────────────────
            // STEP 5: Fetch the appointment
            // ─────────────────────────────────────────────
            List<ServiceAppointment> saList = [
                SELECT Id, Status, AppointmentNumber,
                       SchedStartTime, Account.Name
                FROM ServiceAppointment
                WHERE Id = :inp.appointmentId
                LIMIT 1
            ];

            if (saList.isEmpty()) {
                outRec.message = 'Appointment not found.';
                outRec.success = false;
                results.add(outRec);
                continue;
            }

            ServiceAppointment sa = saList[0];
            System.debug('Appointment found: ' + sa.AppointmentNumber 
                + ' | Status: ' + sa.Status);

            // ─────────────────────────────────────────────
            // STEP 6: Check if already cancelled
            // ─────────────────────────────────────────────
            if (sa.Status == 'Canceled') {
                outRec.message = 'Appointment ' + sa.AppointmentNumber 
                               + ' is already cancelled.';
                outRec.success = false;
                results.add(outRec);
                continue;
            }

            // ─────────────────────────────────────────────
            // STEP 7: Cancel the appointment
            // ─────────────────────────────────────────────
            try {
                sa.Status = 'Canceled';
                update sa;

                outRec.message = 'Appointment ' + sa.AppointmentNumber 
                               + ' for patient ' + sa.Account.Name 
                               + ' has been successfully cancelled.';
                outRec.success = true;
                System.debug('Cancelled: ' + sa.AppointmentNumber);

            } catch (DmlException e) {
                outRec.message = 'Failed to cancel appointment: ' + e.getMessage();
                outRec.success = false;
                System.debug('DML Error: ' + e.getMessage());
            }

            results.add(outRec);
        }

        return results;
    }
}