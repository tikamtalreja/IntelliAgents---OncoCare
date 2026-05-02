import { LightningElement,api } from 'lwc';
const PAGE_SIZE = 5;

export default class Onco_OptionList extends LightningElement {
   
        @api value;
 
    visibleCount = PAGE_SIZE;
 
    get allOptions() {
        return Array.isArray(this.value?.options) ? this.value.options : [];
    }
 
    get hasError() {
        const msg = this.value?.errorMessage;
        return typeof msg === 'string' && msg.trim().length > 0;
    }
 
    get hasOptions() {
        return this.allOptions.length > 0;
    }
 
    get visibleOptions() {
        return this.allOptions.slice(0, this.visibleCount);
    }
 
    get hasMore() {
        return this.allOptions.length > this.visibleCount;
    }
 
    get remainingCount() {
        return Math.max(0, this.allOptions.length - this.visibleCount);
    }
 
    get loadMoreLabel() {
        const nextBatch = Math.min(PAGE_SIZE, this.remainingCount);
        return `Load ${nextBatch} more (${this.remainingCount} remaining)`;
    }
 
    get headerTitle() {
        const type = (this.value?.optionType || '').toUpperCase();
        if (type === 'SPECIALITY')  return 'Choose a speciality';
        if (type === 'DEPARTMENT')  return 'Choose a department';
        if (type === 'FACILITY')    return 'Choose a hospital';
        return 'Choose an option';
    }
 
    get headerSub() {
        const city = this.value?.userCity;
        const total = this.allOptions.length;
        const shown = this.visibleOptions.length;
        const countPart = (shown < total)
            ? `Showing ${shown} of ${total}`
            : `${total} available`;
        if (city) return `${countPart} · (your city: ${city})`;
        return countPart;
    }
 
    handleLoadMore() {
        this.visibleCount = Math.min(this.visibleCount + PAGE_SIZE, this.allOptions.length);
    }
 
    handleSelect(evt) {
        const opt  = evt.currentTarget.dataset.option;
        const type = (this.value?.optionType || '').toUpperCase();
 
        let intent;
        switch (type) {
            case 'SPECIALITY':
                intent = `Show me doctors in ${opt}`;
                break;
            case 'DEPARTMENT':
                intent = `Show me doctors in the ${opt} department`;
                break;
            case 'FACILITY':
                intent = `Show me doctors at ${opt}`;
                break;
            default:
                intent = `I pick ${opt}`;
        }
 
        this.dispatchEvent(new CustomEvent('valuechange', {
            detail: { value: intent, selectedOption: opt, optionType: type },
            bubbles: true,
            composed: true
        }));
    }
}