import { LightningElement,api } from 'lwc';
export default class SpecialityInfo extends LightningElement {


    // ── Single @api value — Agentforce injects the entire
    //    SpecialtyOutput object here. See CLT docs.
    @api value;

    // ── Safe reads from value ─────────────────────────────────────────────
    get specialtyName()   { return this.value?.specialtyName || ''; }
    get about()           { return this.value?.about || ''; }
    get whenToVisit()     { return this.value?.whenToVisit || ''; }
    get whatToExpect()    { return this.value?.whatToExpect || ''; }
    get insuranceNote()   { return this.value?.insuranceNote || ''; }
    get sourceCount()     { return this.value?.sourceCount || 0; }
    get message()         { return this.value?.message || ''; }
    get isFound()         { return this.value?.found === true; }

    get treatments() {
        return Array.isArray(this.value?.treatments) ? this.value.treatments : [];
    }

    get supportServices() {
        return Array.isArray(this.value?.supportServices) ? this.value.supportServices : [];
    }

    get hasTreatments() {
        return this.treatments.length > 0;
    }

    get hasSupport() {
        return this.supportServices.length > 0;
    }

    // ── Action button handler ────────────────────────────────────────────
    // Dispatches valuechange so the agent conversation can
    // pick up the next intent
    handleAction(evt) {
        const action = evt.currentTarget.dataset.action;

        let intent = '';
        switch (action) {
            case 'find-doctor':
                intent = `Find a doctor in ${this.specialtyName}`;
                break;
            default:
                intent = action;
        }

        this.dispatchEvent(new CustomEvent('valuechange', {
            detail: { value: intent, action },
            bubbles: true,
            composed: true
        }));
    }
}