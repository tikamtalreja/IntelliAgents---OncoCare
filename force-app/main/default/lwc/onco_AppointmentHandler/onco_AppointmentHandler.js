import { LightningElement, api } from 'lwc';

const VIEW_BOOK       = 'BOOK';
const VIEW_RESCHEDULE = 'RESCHEDULE';
const VIEW_LIST       = 'LIST';
const VIEW_CANCEL     = 'CANCEL';
const VIEW_CONFLICT   = 'CONFLICT';

export default class Onco_AppointmentHandler extends LightningElement {




@api value;

// ─── View dispatch ───────────────────────────────────────────────
get isBookView() {
    return this.value && this.value.viewType === VIEW_BOOK;
}

get isRescheduleView() {
    return this.value && this.value.viewType === VIEW_RESCHEDULE;
}

get isListView() {
    return this.value && this.value.viewType === VIEW_LIST;
}

get isCancelView() {
    return this.value && this.value.viewType === VIEW_CANCEL;
}

get isConflictView() {
    return this.value && this.value.viewType === VIEW_CONFLICT;
}

// Renders an "Unable to process" fallback when viewType is missing
// or success=false without a typed conflict — covers generic errors.
get isErrorView() {
    if (!this.value) return false;
    if (this.value.isSuccess === true) return false;
    if (this.isConflictView) return false;
    return true;
}

// ─── BOOK / RESCHEDULE shared sub-header (uses appointmentNumber) ──
get bookHeaderSub() {
    if (!this.value || !this.value.appointment) return '';
    const num = this.value.appointment.appointmentNumber;
    return num
        ? `Confirmation #${num} · we've sent details to your email`
        : 'Booking confirmed';
}

get rescheduleHeaderSub() {
    if (!this.value || !this.value.appointment) return '';
    const num = this.value.appointment.appointmentNumber;
    return num
        ? `Confirmation #${num} · updated time confirmed via email`
        : 'New time confirmed';
}

// ─── LIST view ───────────────────────────────────────────────────
get listHeaderSub() {
    const count = this.value && this.value.appointments
        ? this.value.appointments.length
        : 0;
    if (count === 0) return 'No upcoming appointments';
    return `${count} scheduled`;
}

get hasAppointments() {
    return this.value
        && this.value.appointments
        && this.value.appointments.length > 0;
}

// ─── CANCEL view ─────────────────────────────────────────────────
get cancelHeaderSub() {
    if (!this.value || !this.value.appointment) return '';
    const num = this.value.appointment.appointmentNumber;
    return num
        ? `#${num} · this slot is now available for others`
        : 'Cancellation processed';
}

// ─── CONFLICT view ───────────────────────────────────────────────
get hasConflict() {
    return this.value && this.value.conflict;
}

// Conflict-type badge style — amber for near-by, red-ish for exact
get conflictPillClass() {
    if (!this.value || !this.value.conflict) return 'ds-pill ds-pill-warn';
    return this.value.conflict.conflictType === 'Exact Conflict'
        ? 'ds-pill ds-pill-danger'
        : 'ds-pill ds-pill-warn';
}

// ─── Error view ──────────────────────────────────────────────────
get errorMessage() {
    if (this.value && this.value.message) return this.value.message;
    return 'Something went wrong. Please try again.';
}
}