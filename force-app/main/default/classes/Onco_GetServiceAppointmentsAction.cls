public without sharing class Onco_GetServiceAppointmentsAction {

    public class Input {
        @InvocableVariable
        public String uniqueCode;

        @InvocableVariable
        public Id healthcareProviderId;

        @InvocableVariable
        public String healthcareProviderName;
    }

    public class Output {
        @InvocableVariable
        public Id appointmentId;

        @InvocableVariable
        public String appointmentNumber;

        @InvocableVariable
        public String status;

        @InvocableVariable
        public Datetime startTime;

        @InvocableVariable
        public String startTimeFormatted;

        @InvocableVariable
        public String appointmentLink;

        @InvocableVariable
        public String appointmentLinkFormatted;

        @InvocableVariable
        public String patientName;

        @InvocableVariable
        public String serviceResourceName;

        @InvocableVariable
        public String hcpName;
    }

    @InvocableMethod(
        label='Get Service Appointments'
        description='Retrieve Service Appointments via Unique Code Authentication'
    )
    public static List<List<Output>> getAppointments(List<Input> inputs) {

        List<List<Output>> results = new List<List<Output>>();

        for (Input inputRec : inputs) {

            List<AssignedResource> assignedList = new List<AssignedResource>();
            List<Output> outputList = new List<Output>();
            ServiceResource sr;

            System.debug('uniqueCode: ' + inputRec.uniqueCode);
            System.debug('providerName: ' + inputRec.healthcareProviderName);
            System.debug('providerId: ' + inputRec.healthcareProviderId);

            // ─────────────────────────────────────────────
            // STEP 1: PRIMARY — Resolve via Unique Code
            // ─────────────────────────────────────────────
            if (String.isNotBlank(inputRec.uniqueCode)) {

                List<User> userList = [
                    SELECT Id, Name, Onco_Unique_Code__c
                    FROM User
                    WHERE Onco_Unique_Code__c = :inputRec.uniqueCode
                    AND IsActive = true
                    LIMIT 1
                ];

                if (!userList.isEmpty()) {
                    System.debug('User found: ' + userList[0].Name);

                    List<ServiceResource> srList = [
                        SELECT Id, Name,RelatedRecord.name
                        FROM ServiceResource
                        WHERE RelatedRecordId = :userList[0].Id
                        AND IsActive = true
                        LIMIT 1
                    ];

                    if (!srList.isEmpty()) {
                        sr = srList[0];
                        System.debug('SR via unique code: ' + sr.Name);
                    } else {
                        Output outRec = new Output();
                        outRec.status  = 'No service resource linked to this code';
                        outRec.hcpName = userList[0].Name;
                        outputList.add(outRec);
                        results.add(outputList);
                        continue;
                    }

                } else {
                    Output outRec = new Output();
                    outRec.status = 'Invalid unique code. Please try again.';
                    outputList.add(outRec);
                    results.add(outputList);
                    continue;
                }
            }

            // ─────────────────────────────────────────────
            // STEP 2: FALLBACK — UserInfo auto-detect
            // ─────────────────────────────────────────────
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
                    System.debug('SR via UserInfo: ' + sr.Name);
                }
            }

            // ─────────────────────────────────────────────
            // STEP 3: FALLBACK — Provider Name
            // ─────────────────────────────────────────────
            if (sr == null
                && String.isNotBlank(inputRec.healthcareProviderName)) {

                List<ServiceResource> srList = [
                    SELECT Id, Name
                    FROM ServiceResource
                    WHERE Name LIKE :('%' + inputRec.healthcareProviderName + '%')
                    LIMIT 1
                ];

                if (!srList.isEmpty()) {
                    sr = srList[0];
                    System.debug('SR via name: ' + sr.Name);
                }
            }

            // ─────────────────────────────────────────────
            // STEP 4: FALLBACK — Provider Id
            // ─────────────────────────────────────────────
            if (sr == null && inputRec.healthcareProviderId != null) {

                List<ServiceResource> srList = [
                    SELECT Id, Name,RelatedRecord.name
                    FROM ServiceResource
                    WHERE Id = :inputRec.healthcareProviderId
                    LIMIT 1
                ];

                if (!srList.isEmpty()) {
                    sr = srList[0];
                    System.debug('SR via Id: ' + sr.Name);
                }
            }

            // ─────────────────────────────────────────────
            // STEP 5: No provider found
            // ─────────────────────────────────────────────
            if (sr == null) {
                Output outRec = new Output();
                outRec.status = 'No matching healthcare provider found';
                outputList.add(outRec);
                results.add(outputList);
                continue;
            }

            // ─────────────────────────────────────────────
            // STEP 6: Fetch Appointments
            // ─────────────────────────────────────────────
            assignedList = [
                SELECT
                    ServiceAppointment.Id,
                    ServiceAppointment.AppointmentNumber,
                    ServiceAppointment.Status,
                    ServiceAppointment.SchedStartTime,
                    ServiceAppointment.Account.Name,
                    ServiceResource.RelatedRecord.name
                FROM AssignedResource
                WHERE ServiceResourceId = :sr.Id and ServiceAppointment.SchedStartTime =today
                ORDER BY ServiceAppointment.SchedStartTime DESC
                LIMIT 10
            ];

            String baseUrl = URL.getOrgDomainUrl().toExternalForm();

            // ─────────────────────────────────────────────
            // STEP 7: No appointments found
            // ─────────────────────────────────────────────
            if (assignedList.isEmpty()) {
                Output outRec = new Output();
                outRec.status   = 'No appointments found for ' + sr.Name;
                outRec.hcpName  = sr.RelatedRecord.name;
                outputList.add(outRec);
                results.add(outputList);
                continue;
            }

            // ─────────────────────────────────────────────
            // STEP 8: Build response
            // ─────────────────────────────────────────────
            for (AssignedResource ar : assignedList) {

                ServiceAppointment sa = ar.ServiceAppointment;

                Output outRec = new Output();
                outRec.appointmentId            = sa.Id;
                outRec.appointmentNumber        = sa.AppointmentNumber;
                outRec.status                   = sa.Status;
                outRec.startTime                = sa.SchedStartTime;
                outRec.startTimeFormatted       = sa.SchedStartTime != null
                    ? DateTime.valueOf(sa.SchedStartTime)
                              .format('dd-MMM-yyyy hh:mm a', 'Asia/Kolkata')
                    : 'Not scheduled yet';
                outRec.patientName              = sa.Account.Name;
                outRec.serviceResourceName      = ar.ServiceResource != null
                                                  ? ar.ServiceResource.RelatedRecord.name
                                                  : null;
                outRec.hcpName                  = sr.RelatedRecord.name;
                outRec.appointmentLink          = baseUrl + '/' + sa.Id;
                outRec.appointmentLinkFormatted = 'Link: <' + baseUrl + '|View Appointment>';
                                              

                outputList.add(outRec);
            }

            results.add(outputList);
        }

        return results;
    }
}