/**
 * @description       : 
 * @author            : Riley Meyer
 * @group             : 
 * @last modified on  : 07-26-2024
 * @last modified by  : Riley Meyer
**/
public class SendVerificationEmailAction {
    @InvocableMethod(label='Send Verification Email' category='Email' description='Send Emails to users to verify their email address')
    public static void sendEmail(List<FlowInput> inputs){
        for(FlowInput inp: inputs){
            System.UserManagement.sendAsyncEmailConfirmation(
                inp.userId,
                // Whene these values are null the system will use the default Salesforce Verification Email
                inp.emailTemplateId,
                inp.networkId,
                inp.landingPageUrl
            );
        }
    }
    
    public class FlowInput{
        @InvocableVariable(label='User Id' Description='Insert the userId for the user who should recieve the Verification Email' required=true) public Id userId;
        // Whene these values are null the system will use the default Salesforce Verification Email
        @InvocableVariable(label='Email Template Id' description='Leave this blank to use Default Salesforce Verification Email Template' required=false) public Id emailTemplateId;
        @InvocableVariable(label='Network Id' description='Leave this blank to use Default Salesforce Verification Network Id' required=false) public Id networkId;
        @InvocableVariable(label='Landing Page URL' description='Leave this blank to have the User land on the Salesforce Home tab' required=false) public String landingPageUrl;
    }
}