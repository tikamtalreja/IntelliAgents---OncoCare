public class Onco_ServiceAppointmentHandler {


    public static final String ACTION_GET_DOCTORS        = 'GET_DOCTORS';
    public static final String ACTION_BOOK_APPOINTMENT   = 'BOOK_APPOINTMENT';
    public static final String ACTION_GET_APPOINTMENTS   = 'GET_APPOINTMENTS';
    public static final String ACTION_CANCEL_APPOINTMENT = 'CANCEL_APPOINTMENT';
    public static final String ACTION_RESCHEDULE         = 'RESCHEDULE_APPOINTMENT';

    public static final String VIEW_BOOK     = 'BOOK';
    public static final String VIEW_RESCHEDULE = 'RESCHEDULE';
    public static final String VIEW_LIST     = 'LIST';
    public static final String VIEW_CANCEL   = 'CANCEL';
    public static final String VIEW_CONFLICT = 'CONFLICT';

    private static final String STATUS_SCHEDULED  = 'Scheduled';
    private static final String STATUS_CANCELED   = 'Canceled';     // SF standard spelling
    private static final String STATUS_RESCHEDULED = 'Rescheduled';
    private static final Integer IST_OFFSET_SEC   = -19800;          // -5h30m for IST → UTC
    private static final Integer DEFAULT_DURATION_MIN = 30;
    private static final String  USER_FORMAT      = 'EEE, dd MMM yyyy · h:mm a';
    private static final String  TIME_ZONE        = 'Asia/Kolkata';

    private static final String CONFLICT_EXACT   = 'Exact Conflict';
    private static final String CONFLICT_NEARBY  = 'Near by Conflict';

    private static WorkType workTypeInstance;
    private static WorkType getWorkType() {
        if (workTypeInstance == null) {
            workTypeInstance = [
                SELECT Id, EstimatedDuration FROM WorkType
                WHERE Name = 'HCP Office Visit'
                LIMIT 1
            ];
        }
        return workTypeInstance;
    }

    public class ServiceAppointmentRequest {
        @InvocableVariable(label='Action Type'
            description='BOOK_APPOINTMENT | GET_APPOINTMENTS | CANCEL_APPOINTMENT | RESCHEDULE_APPOINTMENT')
        public String actionType;

        @InvocableVariable(label='Patient User Id')
        public Id patientUserId;

        @InvocableVariable(label='Start Time')
        public Datetime startTime;

        @InvocableVariable(label='Service Appointment Id')
        public Id serviceAppointmentId;

        @InvocableVariable(label='HealthcareProvider Record Id')
        public Id healthcareProviderRecordId;
    }
	public class AppointmentJSON{
        @invocableVariable public ServiceAppointmentResponse appointmentDetails;
    }
    
    public class ServiceAppointmentResponse {
        public Boolean isSuccess;
		public String  message;
		public String  viewType;          // BOOK | LIST | CANCEL | CONFLICT
		public Id serviceAppointmentId;
		public AppointmentDetail appointment;            // BOOK + CANCEL
		public List<AppointmentDetail> appointments;     // LIST
		public ConflictDetail conflict;                  // CONFLICT
		public String requestedDoctorName;               // CONFLICT
		public String requestedStartTime;                // CONFLICT — formatted
    }

    public class AppointmentDetail {
        @InvocableVariable public String  serviceAppointmentId;
        @InvocableVariable public String  appointmentNumber;
        @InvocableVariable public String  startTime;     // formatted display
        @InvocableVariable public String  endTime;       // formatted display
        @InvocableVariable public String  shortDate;     // "JUN 15" for list rows
        @InvocableVariable public String  shortDay;      // "15"
        @InvocableVariable public String  shortMonth;    // "JUN"
        @InvocableVariable public String  doctorName;
        @InvocableVariable public String  visitType;
        @InvocableVariable public Integer durationMinutes;
    }

    public class ConflictDetail {
        @InvocableVariable public String conflictType;            // 'Exact Conflict' | 'Near by Conflict'
        @InvocableVariable public String existingAppointmentId;
        @InvocableVariable public String existingStartTime;       // formatted
        @InvocableVariable public String existingEndTime;         // formatted
        @InvocableVariable public String existingSubject;
        @InvocableVariable public String existingDoctorName;
    }

    
    @InvocableMethod(label='Service Appointment Handler' description='Manages all appointment operations: Book, Get, Cancel, Reschedule')
    public static List<AppointmentJSON> execute(List<ServiceAppointmentRequest> requests) {
		List<AppointmentJSON> appointmentJSONList = new List<AppointmentJSON>();
        AppointmentJSON jsonInstance = new AppointmentJSON();
        for (ServiceAppointmentRequest req : requests) {
            ServiceAppointmentResponse resp;
            try {
                if (req.actionType == ACTION_BOOK_APPOINTMENT) {
                    Map<String, String> resourceMap = getServiceResourceTerritory(req.healthcareProviderRecordId);
                    resp = handleCreateAppointment(req, resourceMap);
                } else if (req.actionType == ACTION_GET_APPOINTMENTS) {
                    resp = handleGetAppointments(req);
                } else if (req.actionType == ACTION_CANCEL_APPOINTMENT) {
                    resp = handleCancelAppointment(req);
                } else if (req.actionType == ACTION_RESCHEDULE) {
                    resp = handleRescheduleAppointment(req);
                } else {
                    resp = newResponse(false, 'Invalid action type: ' + req.actionType  + '. Valid: BOOK_APPOINTMENT | GET_APPOINTMENTS | '
                        + 'CANCEL_APPOINTMENT | RESCHEDULE_APPOINTMENT');
                }
            } catch (Exception e) {
                resp = newResponse(false, 'Unexpected error: ' + e.getMessage());
                System.debug('ServiceAppointmentManager Error: ' + e.getMessage()
                    + '\n' + e.getStackTraceString());
            }
            jsonInstance.appointmentDetails = resp;
            appointmentJSONList.add(jsonInstance);
            
        }

        return appointmentJSONList;
    }
	
    private static ServiceAppointmentResponse handleCreateAppointment( ServiceAppointmentRequest req, Map<String, String> resource) {
        if (resource == null) {
            return newResponse(false,
                'Could not resolve doctor scheduling details. Please try again or contact support.');
        }
		try {
            User patientUser = [
                SELECT Id, Name, Contact.Name, Contact.AccountId FROM User WHERE Id = :req.patientUserId LIMIT 1];

            if (patientUser.ContactId == null) {
                return newResponse(false, 'No Contact found for patient user.');
            }
            Id patientAccountId = patientUser.Contact.AccountId;
			ConflictDetail conflict = checkConflict(patientAccountId, req.startTime, null);
            if (conflict != null) {
                ServiceAppointmentResponse cr = new ServiceAppointmentResponse();
                cr.isSuccess           = false;
                cr.viewType            = VIEW_CONFLICT;
                cr.conflict            = conflict;
                cr.requestedDoctorName = lookupDoctorNameByHcp(req.healthcareProviderRecordId);
                cr.requestedStartTime  = formatLocal(req.startTime);
                cr.message             = 'Time conflict detected. Please choose a different slot.';
                return cr;
            }
            DateTime utcStart = req.startTime.addSeconds(IST_OFFSET_SEC);
            
            ConnectApi.ExtendedFieldInput extStatus = new ConnectApi.ExtendedFieldInput();
            extStatus.name  = 'Status';
            extStatus.value = STATUS_SCHEDULED;

            ConnectApi.ServiceAppointmentInput sa = new ConnectApi.ServiceAppointmentInput();
            sa.parentRecordId  = patientAccountId;
            sa.workTypeId      = getWorkType().Id;
            sa.schedStartTime  = utcStart;
            sa.schedEndTime    = utcStart.addMinutes(DEFAULT_DURATION_MIN);
            sa.extendedFields = new List<ConnectApi.ExtendedFieldInput>{ extStatus };

            ConnectApi.AssignedResourcesInput ar = new ConnectApi.AssignedResourcesInput();
            ar.serviceResourceId = resource.get('ServiceResource');
            ar.isPrimaryResource = true;
            ar.isRequiredResource = true;

            ConnectApi.CreateServiceAppointmentInput input = new ConnectApi.CreateServiceAppointmentInput();
            input.serviceAppointment = sa;
            input.assignedResources  = new List<ConnectApi.AssignedResourcesInput>{ ar };

            ConnectApi.ServiceAppointmentOutput output = ConnectApi.LightningScheduler.createServiceAppointment(input);

            Id resultId = (output != null && output.result != null) ? output.result.serviceAppointmentId : null;

            if (resultId == null) {
                return newResponse(false, 'Appointment creation returned null. Please try again.');
            }

            // ── Re-query to populate display fields ──────────────────────
            AppointmentDetail detail = loadAppointmentDetail(resultId);
			ServiceAppointmentResponse resp = new ServiceAppointmentResponse();
            resp.isSuccess            = true;
            resp.viewType             = VIEW_BOOK;
            resp.serviceAppointmentId = resultId;
            resp.appointment          = detail;
            resp.message              = 'Appointment booked successfully.';
            return resp;

        } catch (Exception e) {
            System.debug('handleCreateAppointment Error: ' + e.getMessage());
            return newResponse(false, 'Could not book appointment: ' + e.getMessage());
        }
    }
	 private static ServiceAppointmentResponse handleGetAppointments(ServiceAppointmentRequest req ) {
        try {
            User patientUser = [SELECT Id, Name, Contact.Name, Contact.AccountId FROM User WHERE Id = :req.patientUserId LIMIT 1 ];

            ServiceAppointmentResponse resp = new ServiceAppointmentResponse();
            resp.viewType     = VIEW_LIST;
            resp.appointments = new List<AppointmentDetail>();

            if (patientUser.Contact == null || patientUser.Contact.AccountId == null) {
                resp.isSuccess = true;
                resp.message   = 'No contact found for patient.';
                return resp;
            }
			Id accountId = patientUser.Contact.AccountId;

            List<ServiceAppointment> rows = [ SELECT Id, AppointmentNumber, SchedStartTime, SchedEndTime, Status,
                       (SELECT Id, ServiceResourceId, ServiceResource.Name,ServiceResource.RelatedRecord.name FROM ServiceResources) FROM ServiceAppointment
                WHERE ParentRecordId = :accountId  AND SchedStartTime >= :Datetime.now() AND Status != :STATUS_CANCELED
                ORDER BY SchedStartTime ASC LIMIT 50 ];

            for (ServiceAppointment sa : rows) {
                resp.appointments.add(buildAppointmentDetail(sa));
            }

            resp.isSuccess = true;
            resp.message   = resp.appointments.size() + ' upcoming appointment(s) found.';
            return resp;

        } catch (Exception e) {
            System.debug('handleGetAppointments Error: ' + e.getMessage());
            return newResponse(false, 'Error fetching appointments: ' + e.getMessage());
        }
    }

    private static ServiceAppointmentResponse handleCancelAppointment( ServiceAppointmentRequest req) {
        try {
            ServiceAppointment appt = [SELECT Id, AppointmentNumber, Status, SchedStartTime, SchedEndTime,
                       (SELECT Id, ServiceResourceId, ServiceResource.Name,ServiceResource.RelatedRecord.name FROM ServiceResources)
                FROM ServiceAppointment WHERE Id = :req.serviceAppointmentId LIMIT 1];

            if (appt.Status == STATUS_CANCELED) {
                return newResponse(false, 'Appointment is already cancelled.');
            }

            if (appt.SchedStartTime < Datetime.now()) {
                return newResponse(false, 'Cannot cancel a past appointment.');
            }
			AppointmentDetail detail = buildAppointmentDetail(appt);

            appt.Status = STATUS_CANCELED;
            update appt;

            ServiceAppointmentResponse resp = new ServiceAppointmentResponse();
            resp.isSuccess            = true;
            resp.viewType             = VIEW_CANCEL;
            resp.serviceAppointmentId = appt.Id;
            resp.appointment          = detail;
            resp.message              = 'Appointment successfully cancelled.';
            return resp;

        } catch (Exception e) {
            System.debug('handleCancelAppointment Error: ' + e.getMessage());
            return newResponse(false, 'Error cancelling appointment: ' + e.getMessage());
        }
    }

    private static ServiceAppointmentResponse handleRescheduleAppointment( ServiceAppointmentRequest req    ) {
        try {
            ServiceAppointment appt = [SELECT Id, AppointmentNumber, Status, SchedStartTime, ServiceTerritoryId, ParentRecordId,
                       (SELECT Id, ServiceResourceId, ServiceResource.Name FROM ServiceResources)
                FROM ServiceAppointment WHERE Id = :req.serviceAppointmentId  LIMIT 1 ];

            // ── Conflict pre-check, EXCLUDING the SA being rescheduled ──
            ConflictDetail conflict = checkConflict(appt.ParentRecordId, req.startTime, appt.Id);
            if (conflict != null) {
                ServiceAppointmentResponse cr = new ServiceAppointmentResponse();
                cr.isSuccess           = false;
                cr.viewType            = VIEW_CONFLICT;
                cr.conflict            = conflict;
                cr.requestedDoctorName = !appt.ServiceResources.isEmpty() ? appt.ServiceResources[0].ServiceResource.Name : 'your doctor';
                cr.requestedStartTime  = formatLocal(req.startTime);
                cr.message             = 'Time conflict detected. Please choose a different slot.';
                return cr;
            }

            // ── Build update input ──────────────────────────────────────
            DateTime utcStart = req.startTime.addSeconds(IST_OFFSET_SEC);

            ConnectApi.ExtendedFieldInput extStatus = new ConnectApi.ExtendedFieldInput();
            extStatus.name  = 'Status';
            extStatus.value = STATUS_SCHEDULED;

            ConnectApi.ServiceAppointmentInput saInput = new ConnectApi.ServiceAppointmentInput();
            saInput.schedStartTime = utcStart;
            saInput.schedEndTime   = utcStart.addMinutes(DEFAULT_DURATION_MIN);
            saInput.extendedFields = new List<ConnectApi.ExtendedFieldInput>{ extStatus };

            ConnectApi.AssignedResourcesInput arInput = new ConnectApi.AssignedResourcesInput();
            arInput.serviceResourceId = !appt.ServiceResources.isEmpty()
                ? appt.ServiceResources[0].ServiceResourceId
                : null;
            arInput.isRequiredResource = true;
            arInput.isPrimaryResource  = true;

            ConnectApi.UpdateServiceAppointmentInput updateInput = new ConnectApi.UpdateServiceAppointmentInput();
            updateInput.serviceAppointment   = saInput;
            updateInput.assignedResources    = new List<ConnectApi.AssignedResourcesInput>{ arInput };
            updateInput.serviceAppointmentId = appt.Id;

            ConnectApi.ServiceAppointmentOutput result =
                ConnectApi.LightningScheduler.updateServiceAppointment(updateInput);

            Id resultId = (result != null && result.result != null)
                ? result.result.serviceAppointmentId
                : appt.Id;

            // ── Re-query for fresh display values ───────────────────────
            AppointmentDetail detail = loadAppointmentDetail(resultId);

            ServiceAppointmentResponse resp = new ServiceAppointmentResponse();
            resp.isSuccess            = true;
            resp.viewType             = VIEW_RESCHEDULE;
            resp.serviceAppointmentId = resultId;
            resp.appointment          = detail;
            resp.message              = 'Appointment rescheduled successfully.';
            return resp;

        } catch (Exception e) {
            System.debug('handleRescheduleAppointment Error: ' + e.getMessage());
            return newResponse(false, 'Error rescheduling appointment: ' + e.getMessage());
        }
    }

    private static Map<String, String> getServiceResourceTerritory( String healthcareProviderRecordId) {
        try {
            HealthcareProvider hcp = [SELECT Id, PractitionerId, Name FROM HealthcareProvider WHERE Id = :healthcareProviderRecordId 
                                      AND IsActive = true LIMIT 1];

            User hcpUser = [SELECT Id FROM User WHERE PractitionerId__c = :hcp.PractitionerId LIMIT 1];

            ServiceTerritoryMember stm = [
                SELECT Id, ServiceResourceId, ServiceResource.Name,
                       ServiceTerritoryId, ServiceTerritory.Name
                FROM ServiceTerritoryMember
                WHERE ServiceResource.RelatedRecordId = :hcpUser.Id
                  AND ServiceResource.IsActive = true
                  AND EffectiveStartDate <= TODAY
                  AND (EffectiveEndDate = null OR EffectiveEndDate >= TODAY)
                LIMIT 1
            ];

            Map<String, String> teritorryMap = new Map<String, String>();
            teritorryMap.put('ServiceResource',  stm.ServiceResourceId);
            teritorryMap.put('ServiceTerritory', stm.ServiceTerritoryId);
            return teritorryMap;

        } catch (Exception e) {
            System.debug('getServiceResourceTerritory Error: ' + e.getMessage());
            return null;
        }
    }
    
	private static ConflictDetail checkConflict( Id accountId, DateTime reqTime, Id excludeSaId ) {
         DateTime utcStart = reqTime.addSeconds(IST_OFFSET_SEC);
        Date utcDate    = reqTime.date();
        DateTime dayStart = Datetime.newInstance(utcDate.year(), utcDate.month(), utcDate.day(), 0, 0, 0);
        DateTime dayEnd   = dayStart.addDays(1);

        List<ServiceAppointment> sameDay = [
            SELECT Id, Subject, SchedStartTime, SchedEndTime,AppointmentNumber ,
                   (SELECT Id, ServiceResource.Name,ServiceResource.RelatedRecord.name FROM ServiceResources)
            FROM ServiceAppointment
            WHERE ParentRecordId = :accountId
              AND Status IN (:STATUS_SCHEDULED, :STATUS_RESCHEDULED)
              AND SchedStartTime >= :dayStart
              AND SchedStartTime < :dayEnd
            WITH SECURITY_ENFORCED
            ORDER BY SchedStartTime ASC
            LIMIT 50
        ];

        for (ServiceAppointment sa : sameDay) {
            if (excludeSaId != null && sa.Id == excludeSaId) continue;

            Long diffMinutes = Math.abs(sa.SchedStartTime.getTime() - utcStart.getTime()) / 60000L;

            String type;
            if (diffMinutes == 0L) {
                type = CONFLICT_EXACT;
            } else if (diffMinutes < 60L) {
                type = CONFLICT_NEARBY;
            } else {
                continue;
            }

            ConflictDetail c = new ConflictDetail();
            c.conflictType           = type;
            c.existingAppointmentId  = sa.AppointmentNumber ;
            c.existingStartTime      = formatLocal(sa.SchedStartTime);
            c.existingEndTime        = formatLocal(sa.SchedEndTime);
            c.existingSubject        = sa.Subject;
            c.existingDoctorName     = !sa.ServiceResources.isEmpty()
                ? sa.ServiceResources[0].ServiceResource.RelatedRecord.name
                : null;
            return c;
        }
        return null;
    }
 private static AppointmentDetail loadAppointmentDetail(Id saId) {
        if (saId == null) return null;
        try {
            ServiceAppointment sa = [SELECT Id, AppointmentNumber, SchedStartTime, SchedEndTime,(SELECT Id, ServiceResource.Name,ServiceResource.RelatedRecord.name FROM ServiceResources)
                FROM ServiceAppointment WHERE Id = :saId LIMIT 1 ];
            return buildAppointmentDetail(sa);
        } catch (Exception e) {
            return null;
        }
    }

    
    private static AppointmentDetail buildAppointmentDetail(ServiceAppointment sa) {
        AppointmentDetail d = new AppointmentDetail();
        d.serviceAppointmentId = sa.Id;
        d.appointmentNumber    = sa.AppointmentNumber;
        d.startTime            = formatLocal(sa.SchedStartTime);
        d.endTime              = formatLocal(sa.SchedEndTime);
        d.shortMonth           = sa.SchedStartTime != null ? sa.SchedStartTime.format('MMM', TIME_ZONE).toUpperCase()  : null;
        d.shortDay             = sa.SchedStartTime != null ? sa.SchedStartTime.format('dd', TIME_ZONE) : null;
        d.shortDate            = (d.shortMonth == null) ? null : (d.shortMonth + ' ' + d.shortDay);

        d.doctorName = !sa.ServiceResources.isEmpty() ? sa.ServiceResources[0].ServiceResource.RelatedRecord.name  : 'Not Assigned';

        d.visitType        = 'In-person · HCP Office Visit';
        d.durationMinutes  = (sa.SchedStartTime != null && sa.SchedEndTime != null)
            ? Integer.valueOf((sa.SchedEndTime.getTime() - sa.SchedStartTime.getTime()) / 60000L)
            : DEFAULT_DURATION_MIN;
        return d;
    }

   private static String formatLocal(Datetime dt) {
        if (dt == null) return null;
        return dt.format(USER_FORMAT, TIME_ZONE);
    }

     private static String lookupDoctorNameByHcp(Id hcpId) {
        if (hcpId == null) return 'your doctor';
        try {
            HealthcareProvider hcp = [ SELECT Name FROM HealthcareProvider WHERE Id = :hcpId LIMIT 1];
            return hcp.Name;
        } catch (Exception e) {
            return 'your doctor';
        }
    }
	private static ServiceAppointmentResponse newResponse(Boolean ok, String msg) {
        ServiceAppointmentResponse r = new ServiceAppointmentResponse();
        r.isSuccess = ok;
        r.message   = msg;
        return r;
    }
}