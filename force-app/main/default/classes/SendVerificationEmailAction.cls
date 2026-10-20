/**
 * @description Invocable action that sends the Salesforce email verification message to users.
 * Called by the Email Verification Required Login Flow so that users whose email address is
 * not yet verified (for example SSO users) receive a verification link before they can log in.
 * Thin bulkified wrapper around `System.UserManagement.sendAsyncEmailConfirmation`.
 * @author Riley Meyer
 * @group Email Verification
 */
public class SendVerificationEmailAction {
    /**
     * @description Sends a verification email to each user in the inputs. When the optional
     * inputs are null, Salesforce uses its default verification email template, the internal
     * org (no Experience Cloud site), and lands the user on the org home page.
     * @param inputs One entry per user who should receive a verification email.
     */
    @InvocableMethod(
        label='Send Verification Email'
        category='Email'
        description='Send Emails to users to verify their email address'
    )
    public static void sendEmail(List<FlowInput> inputs) {
        for (FlowInput inp : inputs) {
            System.UserManagement.sendAsyncEmailConfirmation(
                inp.userId,
                inp.emailTemplateId,
                inp.networkId,
                inp.landingPageUrl
            );
        }
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
