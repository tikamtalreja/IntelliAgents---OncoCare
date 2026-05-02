/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : Onco_AppointmentController
 * Description     : This class implements to Fetch Service Appointment details
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Apr 26, 2026  │ <YourName>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public class Onco_AppointmentController {

    @AuraEnabled(cacheable=true)
    public static Integer getFutureAppointmentCount(String accountId) {
        if(accountId == null) return 0;
        return [
            SELECT COUNT()
            FROM ServiceAppointment
            WHERE AccountId = :accountId
            AND SchedStartTime > :System.now()
            AND Status = 'Scheduled'
        ];
    }
    @AuraEnabled(cacheable=true)
    public static Integer getRecentKnowledgeCount() {
        DateTime fourDaysAgo = System.now().addDays(-4);
        return [
            SELECT COUNT()
            FROM Knowledge__kav
            WHERE PublishStatus = 'Online'
            AND Language = 'en_US'
            AND LastModifiedDate >= :fourDaysAgo
        ];
    }

}