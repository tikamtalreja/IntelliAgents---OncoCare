import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import ACCOUNT_ID from '@salesforce/schema/User.AccountId';
import getFutureAppointmentCount from '@salesforce/apex/Onco_AppointmentController.getFutureAppointmentCount';
import getRecentKnowledgeCount from '@salesforce/apex/Onco_AppointmentController.getRecentKnowledgeCount';

export default class OncoAppointmentCard extends NavigationMixin(LightningElement) {
   @api title;
    @api subtitle;
    @api icon;
    @api url;
    @api objectDetails;

    @track badgeCount;
    @track accountId;

    userId = USER_ID;

    // get AccountId from logged in User
    @wire(getRecord, {
        recordId: '$userId',
        fields: [ACCOUNT_ID]
    })
    wiredUser({ data, error }) {
        if (data) {
            this.accountId = getFieldValue(data, ACCOUNT_ID);
            console.log('AccountId:', this.accountId);
        } else if (error) {
            console.error('User error:', error);
        }
    }

    // parse objectDetails JSON
    get parsedDetails() {
        try {
            return this.objectDetails ? JSON.parse(this.objectDetails) : null;
        } catch (e) {
            return null;
        }
    }

    get objectApiName() {
        return this.parsedDetails ? this.parsedDetails.objectApiName : null;
    }

    // check if appointment card
    get isAppointmentCard() {
        return this.objectApiName === 'ServiceAppointment';
    }

    // check if knowledge card
    get isKnowledgeCard() {
        return this.objectApiName === 'Knowledge__kav';
    }

    // wire appointment count — filters by logged in user accountId
    @wire(getFutureAppointmentCount, {
        accountId: '$accountId'
    })
    wiredAppointmentCount({ data, error }) {
        if (this.isAppointmentCard) {
            if (data !== undefined && data !== null) {
                console.log('Appointment count:', data);
                this.badgeCount = data > 0 ? data + ' upcoming' : null;
            } else if (error) {
                console.error('Appointment error:', error);
            }
        }
    }

    // wire knowledge count — articles updated in last 4 days
    @wire(getRecentKnowledgeCount)
    wiredKnowledgeCount({ data, error }) {
    console.log('isKnowledgeCard:', this.isKnowledgeCard);
    console.log('objectApiName:', this.objectApiName);
    console.log('objectDetails:', this.objectDetails);
    console.log('Knowledge data:', data);
    console.log('Knowledge error:', JSON.stringify(error));

    if (this.isKnowledgeCard) {
        if (data !== undefined && data !== null) {
            this.badgeCount = data > 0 ? data + ' new' : null;
            console.log('Knowledge badge:', this.badgeCount);
        }
    }
}

    handleClick() {
        if (this.url) {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: this.url
                }
            });
        }
    }
}