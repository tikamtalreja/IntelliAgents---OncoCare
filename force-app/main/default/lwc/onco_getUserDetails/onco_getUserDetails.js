import { LightningElement,wire } from 'lwc';
import Id from '@salesforce/user/Id';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import First_Name from '@salesforce/schema/User.FirstName';
const fields = [First_Name];

export default class Onco_getUserDetails extends LightningElement {
    userId = Id;
    user;
    

    @wire(getRecord, { recordId: '$userId', fields })
   wiredRecord({ error, data }) {
       if (error) {
           let message = "Unknown error";
           if (Array.isArray(error.body)) {
               message = error.body.map((e) => e.message).join(", ");
           } else if (typeof error.body.message === "string") {
               message = error.body.message;
           }
           console.error("Error loading user record:" + message);
       } else if (data) {
           this.user = data;
           console.log('before custom event');
           var selectedEvent = new CustomEvent('Current_User_id',
                   {
                       detail: {
                           id: this.userId
                       },
                       bubbles: true,
                       composed: true
                   });


           // Dispatches the event.
           window.dispatchEvent(selectedEvent);
       }
   }
}