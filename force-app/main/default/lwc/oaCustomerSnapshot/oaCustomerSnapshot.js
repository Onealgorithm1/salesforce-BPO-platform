import { LightningElement, api } from 'lwc';
import getSnapshot from '@salesforce/apex/OA_CustomerSnapshotController.getSnapshot';

/**
 * Live customer snapshot panel (PoC). Fetches the customer behind this record's
 * Customer UID from the external vault at page-open and displays it view-only.
 * The Apex method is non-cacheable and this component keeps no state beyond the
 * open page — close the record and the data is gone from Salesforce.
 */
export default class OaCustomerSnapshot extends LightningElement {
    @api recordId;
    snapshot;
    error;
    loading = true;

    connectedCallback() {
        getSnapshot({ recordId: this.recordId })
            .then((snap) => {
                this.snapshot = {
                    name: `${snap.first_name} ${snap.last_name}`,
                    company: snap.company,
                    email: snap.email,
                    phone: snap.phone,
                    location: `${snap.city}, ${snap.state}`,
                    isTest: snap.is_test === 1
                };
            })
            .catch((e) => {
                this.error = (e && e.body && e.body.message) || 'Snapshot lookup failed.';
            })
            .finally(() => {
                this.loading = false;
            });
    }
}
