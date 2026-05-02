import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import ACCOUNT_NAME from '@salesforce/schema/User.Account.Name';
import PATIENT_ID from '@salesforce/schema/User.Account.Onco_Patient_ID__c';
import PATIENT_IMG from '@salesforce/resourceUrl/patient';
import ONCO_LOGO from '@salesforce/resourceUrl/onco_logo';

export default class PatientCard extends NavigationMixin(LightningElement) {

    patientName = '';
    patientId = '';
    greeting = '';
    avatarUrl = PATIENT_IMG;
    logoUrl = ONCO_LOGO;

    @wire(getRecord, { recordId: USER_ID, fields: [ACCOUNT_NAME, PATIENT_ID] })
    wiredUser({ data, error }) {
        console.log('Wire Data:', data);
        console.log('Wire Error:', error);
        if (data) {
            this.patientName = getFieldValue(data, ACCOUNT_NAME);
            this.patientId = getFieldValue(data, PATIENT_ID);
        } else if (error) {
            console.error('Error:', JSON.stringify(error));
        }
    }

    connectedCallback() {
        console.log('RecordId:', this.recordId);
        this.setGreeting();
    }

    setGreeting() {
        const hour = new Date().getHours();
        if (hour < 12) {
            this.greeting = 'Good morning';
        } else if (hour < 18) {
            this.greeting = 'Good afternoon';
        } else {
            this.greeting = 'Good evening';
        }
    }

    // Directly opens My Profile page — no dropdown, no menu
    handleProfileClick() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/profile/' + USER_ID
            }
        });
    }
}