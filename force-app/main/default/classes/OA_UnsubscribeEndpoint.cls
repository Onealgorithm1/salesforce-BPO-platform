@RestResource(urlMapping='/oa/unsubscribe/*')
global without sharing class OA_UnsubscribeEndpoint {
    private static final String TOKEN_PARAM = 't';

    @HttpGet
    global static void doGet() {
        String token = tokenFromRequest();
        if (String.isBlank(token)) {
            html(400, page('Invalid unsubscribe link', 'This unsubscribe link is missing its token.', null));
            return;
        }

        html(200, page(
            'Confirm unsubscribe',
            'Confirm that you want to unsubscribe from this campaign.',
            '<form method="post" action="?t=' + htmlEscape(EncodingUtil.urlEncode(token, 'UTF-8')) + '">' +
            '<button type="submit">Unsubscribe</button>' +
            '</form>'
        ));
    }

    @HttpPost
    global static void doPost() {
        String token = tokenFromRequest();
        if (String.isBlank(token)) {
            html(400, page('Unable to unsubscribe', 'This unsubscribe request is missing its token.', null));
            return;
        }

        // Phase 2: the public guest endpoint performs NO business-object access.
        // It computes the token hash (pure crypto, no object visibility required)
        // and publishes a Platform Event. The subscriber (Automated Process) applies
        // the unsubscribe asynchronously. Validity is determined async, so every
        // well-formed POST returns 202 Accepted.
        OA_Unsubscribe_Request__e evt = new OA_Unsubscribe_Request__e(
            Token_Hash__c = OA_UnsubscribeTokenService.hashToken(token),
            Correlation_Id__c = EncodingUtil.convertToHex(Crypto.generateAesKey(128)).toLowerCase(),
            Request_Metadata__c = requestMetadata()
        );
        Database.SaveResult publishResult = EventBus.publish(evt);

        if (publishResult.isSuccess()) {
            html(202, page(
                'Request received',
                'Your unsubscribe request has been received and will be processed shortly.',
                null
            ));
        } else {
            html(500, page(
                'Unable to process request',
                'We could not process your unsubscribe request. Please try again shortly.',
                null
            ));
        }
    }

    private static String tokenFromRequest() {
        if (RestContext.request == null || RestContext.request.params == null) {
            return null;
        }
        return RestContext.request.params.get(TOKEN_PARAM);
    }

    private static String requestMetadata() {
        return JSON.serialize(new Map<String, String>{
            'source' => 'public-site-rest',
            'method' => 'POST'
        });
    }

    private static void html(Integer statusCode, String body) {
        RestResponse response = RestContext.response == null ? new RestResponse() : RestContext.response;
        response.statusCode = statusCode;
        response.addHeader('Content-Type', 'text/html; charset=UTF-8');
        response.responseBody = Blob.valueOf(body);
        RestContext.response = response;
    }

    private static String page(String title, String message, String extraHtml) {
        return '<!doctype html><html><head><meta charset="utf-8"><title>' + htmlEscape(title) +
            '</title></head><body><h1>' + htmlEscape(title) + '</h1><p>' +
            htmlEscape(message) + '</p>' +
            (extraHtml == null ? '' : extraHtml) +
            '</body></html>';
    }

    private static String htmlEscape(String value) {
        return value == null ? '' : value.escapeHtml4();
    }
}
