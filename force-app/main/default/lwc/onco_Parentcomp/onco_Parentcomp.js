import { LightningElement } from 'lwc';
export default class Onco_Parentcomp extends LightningElement {
    knowledgeDetails = JSON.stringify({
        objectApiName: 'Knowledge__kav',
        filterValue: 'LastModifiedDate'
    });
    appointmentDetails = JSON.stringify({
        objectApiName: 'ServiceAppointment',
        filterValue: 'SchedStartTime'
    });
}