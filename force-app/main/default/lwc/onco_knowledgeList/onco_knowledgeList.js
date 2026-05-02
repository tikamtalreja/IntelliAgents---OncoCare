import { LightningElement, wire, track } from 'lwc';
import getKnowledgeArticles from '@salesforce/apex/Onco_KnowledgeController.getKnowledgeArticles';
import getArticleDocuments from '@salesforce/apex/Onco_KnowledgeController.getArticleDocuments';

const COLUMNS = [
    {
        label: 'Title',
        fieldName: 'Title',
        type: 'button',
        typeAttributes: {
            label: { fieldName: 'Title' },
            name: 'view_article',
            variant: 'base'
        }
    },
    {
        label: 'Article Number',
        fieldName: 'ArticleNumber',
        type: 'text'
    },
    {
        label: 'Last Published Date',
        fieldName: 'LastPublishedDate',
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: 'long',
            day: '2-digit'
        }
    },
    {
        label: 'Article Language',
        fieldName: 'Language',
        type: 'text'
    }
];
export default class Onco_knowledgeList extends LightningElement {
     @track articles = [];
    @track isLoading = true;
    columns = COLUMNS;

    @wire(getKnowledgeArticles)
    wiredArticles({ data, error }) {
        if (data) {
            this.articles = data;
            this.isLoading = false;
        } else if (error) {
            console.error('Error:', error);
            this.isLoading = false;
        }
    }

    get isEmpty() {
        return !this.isLoading && this.articles.length === 0;
    }
   
    handleRowAction(event) {
        const row = event.detail.row;
        const articleId = row.Id;

        getArticleDocuments({ articleId: articleId })
            .then(docs => {
                if (docs && docs.length > 0) {
                    const versionId = docs[0].versionId;
                    const documentId = docs[0].documentId;

                    window.location.href = `/OncoGlobal/s/detail/${documentId}`;
                }
            })
            .catch(err => console.error(err));
    }
}