import { LightningElement, api } from 'lwc';

const AVATAR_PALETTE = [
    { bg: '#E8F4FD', fg: '#014486' },
    { bg: '#EDEEFF', fg: '#3A3A90' },
    { bg: '#E8F9F0', fg: '#1A5E32' },
    { bg: '#FDF0E8', fg: '#884812' },
    { bg: '#F9E8F0', fg: '#7A2745' },
    { bg: '#E8F4FE', fg: '#0176D3' },
    { bg: '#F0EDFF', fg: '#5867E8' },
    { bg: '#E1F5EE', fg: '#0F6E56' }
];

const ALL_VALUE = '__ALL__';
const NONE_VALUE = '__NONE__';
const PAGE_SIZE = 5;



export default class Onco_DoctorSearch extends LightningElement {
 @api value;
 
    // ── List state ───────────────────────────────────────────────────
    selectedCity = ALL_VALUE;
    selectedSubSpec = ALL_VALUE;
    visibleCount = PAGE_SIZE;
    emptyHomeCity = null;
 
    _initialised = false;
 
    renderedCallback() {
        if (this._initialised || !this.value) return;
        this._initialised = true;
 
        const def = this.value.defaultCity;
        if (!def) return;
 
        const doctorsInCity = (this.value.doctorList || [])
            .some(d => d.facilityCity === def);
 
        if (doctorsInCity) {
            // User's city has doctors — pre-select it (only if it's an option)
            if ((this.value.cityOptions || []).includes(def)) {
                this.selectedCity = def;
            }
        } else {
            // No doctors in user's city — inject a "None — <city>" option and select it.
            // User must manually pick a nearby city from the dropdown.
            this.emptyHomeCity = def;
            this.selectedCity = NONE_VALUE;
        }
    }
 
    get hasDoctors() {
        return this.value?.success && this.value?.doctorCount > 0;
    }
 
    get message() {
        return this.value?.message || '';
    }
 
    get headerTitle() {
        if (!this.value) return 'Doctors';
        const mode = this.value.searchBy;
        const val  = this.value.searchValue;
        if (mode === 'SPECIALITY')  return `Doctors in ${val}`;
        if (mode === 'DEPARTMENT')  return `Doctors in ${val} department`;
        if (mode === 'FACILITY')    return `Doctors at ${val}`;
        return 'Doctors';
    }
 
    get headerSub() {
        if (!this.value) return '';
        return `${this.value.doctorCount || 0} doctor(s) found`;
    }
 
    get hasCityFilters() {
        // Show the city picklist whenever we have ANY cities, not just multiple.
        // Even 1 city + the synthetic "All cities" option gives the user a
        // meaningful choice. Also covers the empty-home-city case where the
        // picklist must render so user can pick a nearby city.
        return (this.value?.cityOptions || []).length > 0;
    }
 
    get hasSubFilters() {
        return (this.value?.subSpecialityOptions || []).length > 0;
    }
 
    get hasFilters() {
        return this.hasCityFilters || this.hasSubFilters;
    }
 
    // ── Empty-home-city notice ────────────────────────────────────────
    // True while the user's home city has no doctors AND they haven't yet
    // picked a nearby city. Drives the message + empty list.
    get isInEmptyHomeState() {
        return this.emptyHomeCity !== null && this.selectedCity === NONE_VALUE;
    }
 
    get emptyHomeMessage() {
        if (!this.emptyHomeCity) return '';
        return `No doctors available in ${this.emptyHomeCity}. `
             + `Please select a nearby city from the filter above.`;
    }
 
    get cityOptions() {
        const opts = [{ label: 'All cities', value: ALL_VALUE }];
        // Only inject "None" when user's home city has no doctors.
        // Labels it clearly so the user knows WHY it's there.
        if (this.emptyHomeCity) {
            opts.push({
                label: `None (no doctors in ${this.emptyHomeCity})`,
                value: NONE_VALUE
            });
        }
        (this.value?.cityOptions || []).forEach(c => {
            opts.push({ label: c, value: c });
        });
        return opts;
    }
 
    get subOptions() {
        const base = [{ label: 'All sub-specialities', value: ALL_VALUE }];
        const extra = (this.value?.subSpecialityOptions || []).map(s => ({ label: s, value: s }));
        return base.concat(extra);
    }
 
    // ── Filtered doctor list (after filters, before pagination) ─────────
    get filteredDoctors() {
        if (!this.value?.doctorList) return [];
        return this.value.doctorList
            .filter(d => this._matchCity(d) && this._matchSub(d))
            .map(d => {
                const colors = this._avatarColors(d.providerName);
 
                // ── Badge / reputation derivations ─────────────────────
                // hasReviews drives both the badges AND the View Reviews link
                const totalReviews = d.totalReviews;
                const hasReviews = typeof totalReviews === 'number' && totalReviews > 0;
 
                let ratingDisplay = null;
                if (hasReviews && d.avgRating != null) {
                    // 1 dp is plenty for a small badge; 4.76 → "4.8"
                    ratingDisplay = Number(d.avgRating).toFixed(1);
                }
 
                let recommendDisplay = null;
                if (hasReviews && d.recommendationRate != null) {
                    // Round to integer for the pill — "95% recommend"
                    recommendDisplay = Math.round(d.recommendationRate);
                }
 
                return {
                    ...d,
                    initials: this._initials(d.providerName),
                    avatarStyle: `background-color: ${colors.bg}; color: ${colors.fg};`,
                    hasReviews,
                    ratingDisplay,
                    recommendDisplay
                };
            });
    }
 
    // ── Paginated slice that's actually rendered ────────────────────────
    get visibleDoctors() {
        return this.filteredDoctors.slice(0, this.visibleCount);
    }
 
    get hasVisibleDoctors() {
        return this.visibleDoctors.length > 0;
    }
 
    get noneVisibleDueToFilters() {
        return this.hasDoctors && this.filteredDoctors.length === 0;
    }
 
    // ── Load More visibility + label ────────────────────────────────────
    get hasMore() {
        return this.filteredDoctors.length > this.visibleCount;
    }
 
    get remainingCount() {
        return Math.max(0, this.filteredDoctors.length - this.visibleCount);
    }
 
    get loadMoreLabel() {
        const nextBatch = Math.min(PAGE_SIZE, this.remainingCount);
        return `Load ${nextBatch} more (${this.remainingCount} remaining)`;
    }
 
    // ── Result count ────────────────────────────────────────────────────
    get resultCountText() {
        const shown = this.visibleDoctors.length;
        const matching = this.filteredDoctors.length;
        const total = this.value?.doctorCount || 0;
 
        if (matching === total) {
            if (shown === total) return `Showing all ${total} doctor(s)`;
            return `Showing ${shown} of ${total} doctor(s)`;
        }
        if (shown === matching) return `Showing all ${matching} matching doctor(s) of ${total}`;
        return `Showing ${shown} of ${matching} matching doctor(s)`;
    }
 
    // ── Handlers ────────────────────────────────────────────────────────
    handleCityChange(evt) {
        const picked = evt.detail.value;
        this.selectedCity = picked;
        this.visibleCount = PAGE_SIZE;
 
        // Once the user picks a real city (anything other than NONE),
        // the "None" option is no longer needed — remove it from the picklist.
        if (picked !== NONE_VALUE) {
            this.emptyHomeCity = null;
        }
    }
 
    handleSubChange(evt) {
        this.selectedSubSpec = evt.detail.value;
        this.visibleCount = PAGE_SIZE;
    }
 
    handleLoadMore() {
        this.visibleCount = Math.min(
            this.visibleCount + PAGE_SIZE,
            this.filteredDoctors.length
        );
    }
 
    // ── Matchers + utils ────────────────────────────────────────────────
    _matchCity(d) {
        if (this.selectedCity === ALL_VALUE) return true;
        if (this.selectedCity === NONE_VALUE) return false;
        return d.facilityCity === this.selectedCity;
    }
 
    _matchSub(d) {
        if (this.selectedSubSpec === ALL_VALUE) return true;
        return d.subSpecialty === this.selectedSubSpec;
    }
 
    /**
     * Best-effort relative date formatting — kept for potential future use
     * if reviews view returns. Currently unused.
     */
    // _formatRelativeDate removed — re-add when reviews view is reintroduced.
 
 
    _initials(name) {
        if (!name) return '?';
        const parts = name.trim().split(/\s+/);
        if (parts.length === 1) return parts[0].substring(0, 2).toUpperCase();
        return (parts[0].charAt(0) + parts[parts.length - 1].charAt(0)).toUpperCase();
    }
 
    _avatarColors(name) {
        let hash = 0;
        const key = name || '';
        for (let i = 0; i < key.length; i++) {
            hash = ((hash << 5) - hash) + key.charCodeAt(i);
            hash |= 0;
        }
        const idx = Math.abs(hash) % AVATAR_PALETTE.length;
        return AVATAR_PALETTE[idx];
    }
}