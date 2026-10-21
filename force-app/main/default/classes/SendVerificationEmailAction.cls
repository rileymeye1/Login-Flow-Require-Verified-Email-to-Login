/**
 * @description Invocable action that sends the Salesforce email verification message to users.
 * Called by the Email Verification Required Login Flow so that users whose email address is
 * not yet verified (for example SSO users) receive a verification link before they can log in.
 * Thin bulkified wrapper around `System.UserManagement.sendAsyncEmailConfirmation`.
 * @author Riley Meyer
 * @group Email Verification
 */
public class SendVerificationEmailAction {
    private static final String LOGIN_PATH = '/login';

    /**
     * @description Sends a verification email to each user in the inputs. When the optional
     * inputs are null, Salesforce uses its default verification email template, picks the
     * user's site itself, and lands the user on the org or site home page. When networkId is
     * blank but communityUrl is set (a Login Flow passes LoginFlow_Community), the Experience
     * Cloud site is resolved from that URL so the email always targets the site the user is
     * logging in to, even if they belong to more than one site.
     * @param inputs One entry per user who should receive a verification email.
     */
    @InvocableMethod(
        label='Send Verification Email'
        category='Email'
        description='Send Emails to users to verify their email address'
    )
    public static void sendEmail(List<FlowInput> inputs) {
        Map<Id, String> siteUrlByNetworkId = needsSiteLookup(inputs)
            ? getLiveSiteUrlsByNetworkId()
            : new Map<Id, String>();

        for (FlowInput inp : inputs) {
            Id networkId = inp.networkId != null
                ? inp.networkId
                : resolveNetworkId(inp.communityUrl, siteUrlByNetworkId);
            System.UserManagement.sendAsyncEmailConfirmation(
                inp.userId,
                inp.emailTemplateId,
                networkId,
                inp.landingPageUrl
            );
        }
    }

    /**
     * @description Finds the site whose base URL matches the Login Flow community URL.
     * @param communityUrl Base URL of the site the user is logging in to, e.g.
     * `https://example.my.site.com`. Blank for internal logins.
     * @param siteUrlByNetworkId Normalized base URL of each live site, keyed by Network Id.
     * @return The matching Network Id, or null when the URL is blank or matches no site.
     */
    @TestVisible
    private static Id resolveNetworkId(String communityUrl, Map<Id, String> siteUrlByNetworkId) {
        if (String.isBlank(communityUrl)) {
            return null;
        }
        String target = normalizeUrl(communityUrl);
        for (Id networkId : siteUrlByNetworkId.keySet()) {
            if (siteUrlByNetworkId.get(networkId) == target) {
                return networkId;
            }
        }
        return null;
    }

    /**
     * @description Builds the base URL of every live site from its login URL, which is the
     * base URL plus `/login` (for example `https://example.my.site.com/lp/login`).
     * @return Normalized base URL of each live site, keyed by Network Id.
     */
    @TestVisible
    private static Map<Id, String> getLiveSiteUrlsByNetworkId() {
        Map<Id, String> siteUrlByNetworkId = new Map<Id, String>();
        for (Network site : [SELECT Id FROM Network WHERE Status = 'Live' LIMIT 200]) {
            String loginUrl = Network.getLoginUrl(site.Id);
            if (String.isNotBlank(loginUrl)) {
                siteUrlByNetworkId.put(site.Id, normalizeUrl(loginUrl).removeEnd(LOGIN_PATH));
            }
        }
        return siteUrlByNetworkId;
    }

    private static Boolean needsSiteLookup(List<FlowInput> inputs) {
        for (FlowInput inp : inputs) {
            if (inp.networkId == null && String.isNotBlank(inp.communityUrl)) {
                return true;
            }
        }
        return false;
    }

    private static String normalizeUrl(String url) {
        return url.trim().toLowerCase().removeEnd('/');
    }

    /**
     * @description Flow input for a single verification email request.
     */
    public class FlowInput {
        /**
         * @description Id of the user who should receive the verification email.
         */
        @InvocableVariable(
            label='User Id'
            description='Insert the userId for the user who should receive the Verification Email'
            required=true
        )
        public Id userId;

        /**
         * @description Optional email template Id. Null uses the default Salesforce verification email.
         */
        @InvocableVariable(
            label='Email Template Id'
            description='Leave this blank to use Default Salesforce Verification Email Template'
            required=false
        )
        public Id emailTemplateId;

        /**
         * @description Optional Experience Cloud site (Network) Id. Null for internal users.
         */
        @InvocableVariable(
            label='Network Id'
            description='Leave this blank to use Default Salesforce Verification Network Id'
            required=false
        )
        public Id networkId;

        /**
         * @description Optional base URL of the site the user is logging in to. Pass the Login
         * Flow's LoginFlow_Community variable. Ignored when networkId is set.
         */
        @InvocableVariable(
            label='Community URL'
            description='Pass LoginFlow_Community so the email targets the site the user is logging in to'
            required=false
        )
        public String communityUrl;

        /**
         * @description Optional URL the user lands on after verifying. Null lands on the home page.
         */
        @InvocableVariable(
            label='Landing Page URL'
            description='Leave this blank to have the User land on the Salesforce Home tab'
            required=false
        )
        public String landingPageUrl;
    }
}
