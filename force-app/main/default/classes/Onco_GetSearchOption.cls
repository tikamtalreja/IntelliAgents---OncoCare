public  class Onco_GetSearchOption {

    // ── INPUT ───────────────────────────────────────────────────────────
    public class OptionInput {

        @InvocableVariable(
            label       = 'Option Type'
            description = 'SPECIALITY, DEPARTMENT or FACILITY'
            required    = true
        )
        public String optionType;

        @InvocableVariable(
            label       = 'User Id'
            description = 'Logged-in User Id — used to resolve the patient\'s Contact and MailingCity.'
            required    = true
        )
        public String userId;
    }
    public class JSONOutput{
        @invocableVariable public optionOutput optionDetails;
    }
   
    // ── OUTPUT ──────────────────────────────────────────────────────────
    public class OptionOutput {

         public Boolean      success;
         public String       message;
         public String       optionType;
         public List<String> options;
         public Integer      optionCount;
         public String       userCity;
         public String       userName;
         public String 		errorMessage;
    }

    // ── INVOCABLE METHOD ────────────────────────────────────────────────
    @InvocableMethod(
        label       = 'Get Search Options'
        description = 'Returns a list of options (specialities, departments, or facilities) for the patient to pick from.'
        category    = 'Doctor Search'
    )
    public static List<JSONOutput> getOptions(List<OptionInput> inputs) {
        List<JSONOutput> jSONOutputList = new List<JSONOutput>();
		JSONOutput outputInstance = new JSONOutput();
        if (inputs == null || inputs.isEmpty()) return jSONOutputList;

        OptionInput  inp = inputs[0];
        OptionOutput out = new OptionOutput();
        out.options      = new List<String>();
        out.optionCount  = 0;
        out.success      = false;

        try {
            // ── Normalize and validate ──────────────────────────────────
            if (String.isBlank(inp.optionType)) {
                out.message = 'Missing option type. Please specify SPECIALITY, DEPARTMENT or FACILITY.';
                outputInstance.optionDetails = out;
        jSONOutputList.add(outputInstance);
        return jSONOutputList;
            }

            String optType = inp.optionType.toUpperCase().trim();
            out.optionType = optType;

            // ── Resolve patient context from user Id ────────────────────
            PatientContext ctx = resolvePatient(inp.userId);
            if(ctx==null){	
                out.errorMessage ='Please end the chat conversation and refresh the browser to start again';
                
                outputInstance.optionDetails = out;
                jSONOutputList.add(outputInstance);
                return jSONOutputList;  
            }                        
            out.userCity = ctx.city;
            out.userName = ctx.name;

            // ── Route by option type ────────────────────────────────────
            switch on optType {
                when 'SPECIALITY' {
                    out.options = listSpecialities();
                }
                when 'DEPARTMENT' {
                    out.options = listDepartments();
                }
                when 'FACILITY' {
                    out.options = listFacilities();
                }
                when else {
                    out.message = 'Unknown option type: ' + optType
                        + '. Use SPECIALITY, DEPARTMENT or FACILITY.';
                    outputInstance.optionDetails = out;
        jSONOutputList.add(outputInstance);
        return jSONOutputList;
                }
            }

            out.optionCount = out.options.size();
            out.success     = true;
            out.message     = out.options.isEmpty()
                ? 'No ' + optType.toLowerCase() + ' options found.'
                : 'Found ' + out.optionCount + ' ' + optType.toLowerCase() + ' option(s).';

        } catch (Exception e) {
            out.success = false;
            out.message = 'Error fetching options: ' + e.getMessage();
            System.debug('GetSearchOptionsAction error: ' + e.getStackTraceString());
        }

        outputInstance.optionDetails = out;
        jSONOutputList.add(outputInstance);
        return jSONOutputList;
    }

    // ── Option queries ──────────────────────────────────────────────────

    /**
     * Specialty is a Long Text Area field — can't use GROUP BY or WHERE.
     * So we fetch and dedup in Apex. Returns broad speciality names.
     */
    private static List<String> listSpecialities() {
        Set<String> unique = new Set<String>();
        for (CareProviderSearchableField r : [ SELECT Specialty FROM CareProviderSearchableField
            LIMIT 2000
        ]) {
            String cleaned = stripPipes(r.Specialty);
            if (String.isNotBlank(cleaned)) unique.add(cleaned);
        }
        List<String> sorted = new List<String>(unique);
        sorted.sort();
        return sorted;
    }

    /**
     * PersonDepartment is filterable — we can use GROUP BY.
     * Path: CareProviderSearchableField → Provider → Account → PersonDepartment
     */
    private static List<String> listDepartments() {
        List<String> departments = new List<String>();
        for (AggregateResult row : [
            SELECT Provider.Practitioner.Account.PersonDepartment dept
            FROM CareProviderSearchableField
            WHERE ProviderType = 'Medical Doctor'
              AND Provider.Practitioner.Account.PersonDepartment != null
            GROUP BY Provider.Practitioner.Account.PersonDepartment
            ORDER BY Provider.Practitioner.Account.PersonDepartment ASC
        ]) {
            String d = (String) row.get('dept');
            if (String.isNotBlank(d)) departments.add(d);
        }
        return departments;
    }

    /**
     * FacilityName is a filterable text field — GROUP BY works directly.
     * Returns only facilities that have at least one doctor.
     */
    private static List<String> listFacilities() {
        List<String> facilities = new List<String>();
        for (AggregateResult row : [
            SELECT FacilityName fac
            FROM CareProviderSearchableField
            WHERE FacilityName != null
            GROUP BY FacilityName
            ORDER BY FacilityName ASC
        ]) {
            String f = (String) row.get('fac');
            if (String.isNotBlank(f)) facilities.add(f);
        }
        return facilities;
    }

    // ── Patient resolution ──────────────────────────────────────────────

    private class PatientContext {
        String city;
        String name;
    }

    /**
     * Resolves the logged-in user's Contact and MailingCity.
     * Falls back gracefully if user has no linked Contact (e.g. internal users).
     */
    private static PatientContext resolvePatient(String userId) {
        PatientContext ctx = new PatientContext();
        if (String.isBlank(userId)) return null;

        List<User> users = [
            SELECT Id, Name, ContactId, contact.Account.BillingCity, Contact.Name
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];
        if (users.isEmpty()) return ctx;

        User u = users[0];
        if (u.ContactId != null) {
            ctx.city = u.contact.Account.BillingCity;
            ctx.name = u.Contact.Name;
        } else {
            ctx.name = u.Name;
        }
        return ctx;
    }

    private static String stripPipes(String val) {
        if (String.isBlank(val)) return '';
        return val.replace('|', '').trim();
    }
}