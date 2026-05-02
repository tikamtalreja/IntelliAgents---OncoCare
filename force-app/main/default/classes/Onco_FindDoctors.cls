global without sharing class Onco_FindDoctors {

    // ── INPUT ───────────────────────────────────────────────────────────
    public class FindInput {

        @InvocableVariable(
            label       = 'Search By'
            description = 'SPECIALITY, DEPARTMENT or FACILITY'
            required    = true
        )
        public String searchBy;

        @InvocableVariable(
            label       = 'Search Value'
            description = 'The chosen speciality / department / facility name'
            required    = true
        )
        public String searchValue;

        @InvocableVariable(
            label       = 'User Id'
            description = 'Logged-in User Id — used to resolve the patient\'s city for default filter.'
            required    = true
        )
        public String userId;
    }

    public class JSONOutput{
      @invocableVariable  public findOutput doctorOutputList;
    }
    public class FindOutput {

         public Boolean success;
         public String  message;

         public String  searchBy;
         public String  searchValue;

         public List<DoctorDetail> doctorList;
         public Integer             doctorCount;

         public List<String> cityOptions;
         public List<String> subSpecialityOptions;

         public String defaultCity;
    }

    public class DoctorDetail {
        @InvocableVariable public String providerName;
        @InvocableVariable public String specialty;
        @InvocableVariable public String subSpecialty;
        @InvocableVariable public String department;
        @InvocableVariable public String facilityName;
        @InvocableVariable public String facilityPhone;
        @InvocableVariable public String facilityCity;
        @InvocableVariable public String facilityState;
        @InvocableVariable public String facilityPostalCode;
        @InvocableVariable public String providerType;
        @InvocableVariable public string providerId;
        @InvocableVariable public String providerEmail;
 
        // ── NEW: reputation metrics aggregated from Data Cloud DMO ──
        @InvocableVariable public Decimal avgRating;
        @InvocableVariable public Decimal totalReviews;
        @InvocableVariable public Decimal recommendationRate;
    }

    // ── INVOCABLE METHOD ────────────────────────────────────────────────
    @InvocableMethod(
        label       = 'Find Doctors'
        description = 'Returns doctors matching the selected speciality, department, or facility.'
        category    = 'Doctor Search'
    )
    public static List<JSONOutput> findDoctors(List<FindInput> inputs) {
        List<JSONOutput> outputList = new List<JSONOutput>();
        JSONOutput outputInstance = new JSONOutput();
        if (inputs == null || inputs.isEmpty()) return outputList;

        FindInput  inp = inputs[0];
        system.debug(inp);
        FindOutput out = new FindOutput();
        out.success              = false;
        out.doctorList           = new List<DoctorDetail>();
        out.doctorCount          = 0;
        out.cityOptions          = new List<String>();
        out.subSpecialityOptions = new List<String>();

        try {
            // ── Normalize and validate ──────────────────────────────────
            if (String.isBlank(inp.searchBy) || String.isBlank(inp.searchValue)) {
                out.message = 'Please specify both searchBy and searchValue.';
                 outputInstance.doctorOutputList = out;
        outputList.add(outputInstance);
       
        return outputList;
            }
            String searchBy = inp.searchBy.toUpperCase().trim();
            out.searchBy    = searchBy;
            out.searchValue = inp.searchValue;

            // ── Resolve patient's city for default filter ───────────────
            out.defaultCity = resolveUserCity(inp.userId);

            // ── Route by searchBy ───────────────────────────────────────
            List<CareProviderSearchableField> records;
            switch on searchBy {
                when 'SPECIALITY' {
                    records = searchBySpeciality(inp.searchValue);
                }
                when 'DEPARTMENT' {
                    records = searchByDepartment(inp.searchValue);
                }
                when 'FACILITY' {
                    records = searchByFacility(inp.searchValue);
                }
                when else {
                    out.message = 'Unknown searchBy: ' + searchBy
                        + '. Use SPECIALITY, DEPARTMENT or FACILITY.';
                     outputInstance.doctorOutputList = out;
        outputList.add(outputInstance);
       
        return outputList;
                }
            }

            // ── Map records to DoctorDetail + build facets ──────────────
            Set<String> cities  = new Set<String>();
            Set<String> subs    = new Set<String>();

            for (CareProviderSearchableField rec : records) {
                DoctorDetail d           = new DoctorDetail();
                d.providerName           = rec.ProviderName;
                d.specialty              = stripPipes(rec.Specialty);
                d.subSpecialty           = stripPipes(rec.SubSpecialty);
                d.department             = rec.Provider?.Account?.PersonDepartment;
                d.facilityName           = rec.FacilityName;
                d.facilityPhone          = rec.FacilityPhone;
                d.facilityCity           = rec.FacilityCity;
                d.facilityState          = rec.FacilityState;
                d.facilityPostalCode     = rec.FacilityPostalCode;
                d.providerType           = rec.ProviderType;
                d.providerId             = rec.providerId;
                d.providerEmail          = rec.Provider.Email__c;
                d.recommendationRate     =rec.Provider.Practitioner.Onco_Recommendation__c;  
                d.totalReviews           = rec.Provider.Practitioner.Onco_Total_Review__c;
                d.avgRating             = rec.provider.Practitioner.Onco_Rating__c;
                out.doctorList.add(d);

                if (String.isNotBlank(d.facilityCity)) cities.add(d.facilityCity);
                if (String.isNotBlank(d.subSpecialty)) subs.add(d.subSpecialty);
            }

            out.doctorCount          = out.doctorList.size();
            out.cityOptions          = sorted(cities);
            out.subSpecialityOptions = sorted(subs);
            out.success              = true;
            out.message              = out.doctorCount == 0
                ? 'No doctors found for ' + searchBy.toLowerCase() + ' "' + inp.searchValue + '".'
                : 'Found ' + out.doctorCount + ' doctor(s) for '
                    + searchBy.toLowerCase() + ' "' + inp.searchValue + '".';

        } catch (Exception e) {
            out.success = false;
            out.message = 'Error finding doctors: ' + e.getMessage();
            System.debug('FindDoctorsAction error: ' + e.getStackTraceString());
        }
        outputInstance.doctorOutputList = out;
        
        outputList.add(outputInstance);
       
        return outputList;
    }

    // ── Search methods ──────────────────────────────────────────────────

    /**
     * Speciality is a Long Text Area — SOSL required.
     * We strip pipes and escape reserved characters before passing to SOSL.
     */
    private static List<CareProviderSearchableField> searchBySpeciality(String value) {
        String term = sanitizeSosl(value);
        String sosl =
            'FIND {' + term + '} IN ALL FIELDS ' +
        'RETURNING CareProviderSearchableField(' +
        '    ProviderName, Specialty, SubSpecialty, FacilityName, ' +
        '    FacilityPhone, FacilityCity, FacilityState, ' +
        '    FacilityPostalCode, IsAcceptingNewPatients, ProviderType, ' +
        '    Provider.Account.PersonDepartment, Provider.Email__c,Provider.Practitioner.Onco_Rating__c, Provider.Practitioner.Onco_Recommendation__c, Provider.Practitioner.Onco_Total_Review__c  ' +
        '    WHERE ProviderType = \'Medical Doctor\' ' +
        '    ORDER BY ProviderName ASC LIMIT 100' +
        ')';
        List<CareProviderSearchableField> results = 
        (List<CareProviderSearchableField>) Search.query(sosl)[0];

    // Post-filter on SubSpecialty in Apex
    List<CareProviderSearchableField> filtered = new List<CareProviderSearchableField>();
    for (CareProviderSearchableField cp : results) {
        if (cp.Specialty != null && 
            cp.Specialty.containsIgnoreCase(value)) {
            filtered.add(cp);
        }
    }
    return filtered;
    }

    /**
     * Department is filterable — regular SOQL.
     */
    private static List<CareProviderSearchableField> searchByDepartment(String value) {
        return [
            SELECT ProviderName, Specialty, SubSpecialty, FacilityName,
                   FacilityPhone, FacilityCity, FacilityState,
                   FacilityPostalCode, IsAcceptingNewPatients, ProviderType,
                   Provider.Account.PersonDepartment,Provider.Email__c,Provider.Practitioner.Onco_Rating__c, Provider.Practitioner.Onco_Recommendation__c, Provider.Practitioner.Onco_Total_Review__c
            FROM CareProviderSearchableField
            WHERE Provider.Practitioner.Account.PersonDepartment = :value
            ORDER BY ProviderName ASC
            LIMIT 100
        ];
    }

    /**
     * FacilityName is filterable — regular SOQL.
     */
    private static List<CareProviderSearchableField> searchByFacility(String value) {
        return [
            SELECT ProviderName, Specialty, SubSpecialty, FacilityName,
                   FacilityPhone, FacilityCity, FacilityState,
                   FacilityPostalCode, IsAcceptingNewPatients, ProviderType,
                   Provider.Account.PersonDepartment,Provider.Email__c, Provider.Practitioner.Onco_Rating__c, Provider.Practitioner.Onco_Recommendation__c, Provider.Practitioner.Onco_Total_Review__c
            FROM CareProviderSearchableField
            WHERE FacilityName = :value
            ORDER BY ProviderName ASC
            LIMIT 100
        ];
    }

    // ── Helpers ─────────────────────────────────────────────────────────

    private static String resolveUserCity(String userId) {
        if (String.isBlank(userId)) return null;
        List<User> users = [
            SELECT Name, ContactId, contact.Account.BillingCity, Contact.Name
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];
        if (users.isEmpty() || users[0].ContactId == null) return null;
        return users[0].contact.Account.BillingCity;
    }

    private static List<String> sorted(Set<String> s) {
        List<String> result = new List<String>(s);
        result.sort();
        return result;
    }

    private static String sanitizeSosl(String val) {
        if (String.isBlank(val)) return '';
        String cleaned = val.replace('|', '').trim()
            .replace('\\', '\\\\').replace('"',  '\\"')
            .replace('\'', '\\\'').replace('+',  '\\+')
            .replace('-',  '\\-') .replace('&',  '\\&')
            .replace('|',  '\\|') .replace('!',  '\\!')
            .replace('(',  '\\(') .replace(')',  '\\)')
            .replace('{',  '\\{') .replace('}',  '\\}')
            .replace('[',  '\\[') .replace(']',  '\\]')
            .replace('^',  '\\^') .replace('~',  '\\~')
            .replace('*',  '\\*') .replace('?',  '\\?')
            .replace(':',  '\\:');
        return cleaned.contains(' ') ? '"' + cleaned + '"' : cleaned;
    }

    private static String stripPipes(String val) {
        if (String.isBlank(val)) return '';
        return val.replace('|', '').trim();
    }
	
    public class ReviewDetail {
      @invocableVariable   public Decimal rating;
      @invocableVariable   public Date    reviewDate;
      @invocableVariable   public String  reviewText;
      @invocableVariable   public Boolean wouldRecommend;
    }
    @auraEnabled
    public static Map<String,List<ReviewDetail>> getReviewsForDoctor() {
        Map<String, List<ReviewDetail>> result = new Map<String, List<ReviewDetail>>();
        String soql =
            'SELECT  Rating__c, Review_Date__c, Review_Text__c, ' +
            'Would_Recommend__c, Provider_Email__c ' +
              'FROM Doctor_Reviews__dlm ' +
            'ORDER BY Review_Date__c DESC NULLS LAST ' +
            'LIMIT 1000'; 
        
                    Map<String, Integer> countByEmail = new Map<String, Integer>();

        for (SObject row : Database.query(soql)) {
            String email = (String) row.get('Provider_Email__c');
            if (String.isBlank(email)) continue;
            
            Integer current = countByEmail.containsKey(email) ? countByEmail.get(email) : 0;
                if (current >= 5) continue;  
            
            ReviewDetail rd = new ReviewDetail();
            rd.rating            = (Decimal) row.get('Rating__c');
            rd.reviewDate        = (Date)    row.get('Review_Date__c');
            rd.reviewText        = (String)  row.get('Review_Text__c');
            Object wr = row.get('Would_Recommend__c');
            if(wr!=null && wr==true){
                rd.wouldRecommend    = true;
            }else if(wr!=null){
                rd.wouldRecommend = false; 
            }
            
            
            if (!result.containsKey(email)) {
                result.put(email, new List<ReviewDetail>());
            }
            result.get(email).add(rd);
                            countByEmail.put(email, current + 1);

        }
        return result;
    }
    
}