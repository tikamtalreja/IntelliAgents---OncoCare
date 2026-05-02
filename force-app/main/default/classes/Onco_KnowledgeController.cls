/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : Onco_KnowledgeController 
 * Description     : This class implements to fetch Knowledge Details
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Apr 25, 2026  │ <YourName>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
public without sharing class Onco_KnowledgeController {

    @AuraEnabled(cacheable=true)
    public static List<Knowledge__kav> getKnowledgeArticles() {
         return [
            SELECT Id, Title, ArticleNumber, LastPublishedDate, Summary, Language
            FROM Knowledge__kav
            WHERE PublishStatus = 'Online'
            AND Language = 'en_US'
            ORDER BY Title ASC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getArticleDocuments(String articleId) {

        // Step 1 — get ContentDocumentIds linked to article
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :articleId
        ];

        Set<Id> docIds = new Set<Id>();
        for(ContentDocumentLink link : links) {
            docIds.add(link.ContentDocumentId);
        }

        if(docIds.isEmpty()) return new List<Map<String, String>>();

        // Step 2 — get ContentVersion Id (068) from ContentDocumentId (069)
        List<ContentVersion> versions = [
            SELECT Id, Title, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
            AND IsLatest = true
            ORDER BY Title ASC
        ];

        // Step 3 — build result with versionId
        List<Map<String, String>> result = new List<Map<String, String>>();
        for(ContentVersion v : versions) {
            Map<String, String> doc = new Map<String, String>();
            doc.put('versionId', v.Id);                        // 068 — for filePreview
            doc.put('documentId', v.ContentDocumentId);        // 069
            doc.put('Title', v.Title);
            result.add(doc);
        }
        return result;
    }
}