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
            'Manage your email preferences',
            'You are about to unsubscribe from One Algorithm marketing and outreach emails.',
            '<form class="oa-form" method="post" action="?t=' + htmlEscape(EncodingUtil.urlEncode(token, 'UTF-8')) + '">' +
            '<button type="submit" class="oa-btn">Unsubscribe from marketing emails</button>' +
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
                'You\'re unsubscribed.',
                'You will no longer receive One Algorithm marketing and outreach emails.',
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
        String t = htmlEscape(title);
        String m = htmlEscape(message);
        String trust = (extraHtml == null) ? '' :
            '<ul class="oa-trust"><li>&#10003; No login required</li>' +
            '<li>&#10003; Your request is processed immediately</li></ul>';
        return '<!doctype html><html lang="en"><head>'
            + '<meta charset="utf-8">'
            + '<meta name="viewport" content="width=device-width, initial-scale=1">'
            + '<title>' + t + ' | One Algorithm</title>'
            + '<style>'
            + '.oa-page{background:#f4f4f4;min-height:100vh;margin:0;padding:32px 16px;box-sizing:border-box;font-family:Arial,Helvetica,sans-serif;color:#333}'
            + '.oa-card{max-width:460px;margin:0 auto;background:#fff;border:1px solid #e4e4e4;border-radius:12px;overflow:hidden}'
            + '.oa-rule{height:4px;background:#1a3a5c}'
            + '.oa-body{padding:28px 28px 22px}'
            + '.oa-brand{margin-bottom:20px}'
            + '.oa-wordmark{font-size:15px;font-weight:bold;color:#1a3a5c;letter-spacing:.2px}'
            + '.oa-tag{font-size:11px;color:#777;margin-top:2px}'
            + '.oa-h1{font-size:21px;color:#1a3a5c;margin:0 0 10px;font-weight:bold}'
            + '.oa-lead{font-size:15px;line-height:1.55;color:#555;margin:0 0 22px}'
            + '.oa-form{margin:0 0 18px}'
            + '.oa-btn{display:block;width:100%;min-height:48px;padding:13px 18px;border-radius:8px;font-size:15px;font-weight:bold;font-family:inherit;cursor:pointer;text-align:center;line-height:1.3;background:#1a3a5c;color:#fff;border:1px solid #1a3a5c}'
            + '.oa-btn:hover{background:#14304a}'
            + '.oa-btn:focus-visible{outline:3px solid #7aa8cc;outline-offset:2px}'
            + '.oa-trust{list-style:none;padding:0;margin:0 0 8px;font-size:12px;color:#777}'
            + '.oa-trust li{padding:3px 0}'
            + '.oa-foot{margin-top:22px;padding-top:14px;border-top:1px solid #eee}'
            + '.oa-q{font-size:13px;color:#555;margin:0 0 8px}'
            + '.oa-legal{font-size:11px;color:#777;line-height:1.5;margin:0 0 4px}'
            + '.oa-flinks{font-size:12px;margin:0}'
            + '.oa-link{color:#1a3a5c;text-decoration:underline}'
            + '</style></head><body>'
            + '<div class="oa-page"><main class="oa-card" role="main"><div class="oa-rule"></div><div class="oa-body">'
            + '<div class="oa-brand"><div class="oa-wordmark">One Algorithm LLC</div>'
            + '<div class="oa-tag">Think bigger. Build smarter. Move faster.</div></div>'
            + '<h1 class="oa-h1">' + t + '</h1>'
            + '<p class="oa-lead">' + m + '</p>'
            + (extraHtml == null ? '' : extraHtml)
            + trust
            + '<div class="oa-foot">'
            + '<p class="oa-q">Questions? <a class="oa-link" href="mailto:service@onealgorithm.com">service@onealgorithm.com</a></p>'
            + '<p class="oa-legal">One Algorithm LLC &#8226; Certified EDWOSB &#8226; CAGE 14G18</p>'
            + '<p class="oa-flinks"><a class="oa-link" href="https://www.onealgorithm.com">onealgorithm.com</a></p>'
            + '</div></div></main></div></body></html>';
    }

    private static String htmlEscape(String value) {
        return value == null ? '' : value.escapeHtml4();
    }
}