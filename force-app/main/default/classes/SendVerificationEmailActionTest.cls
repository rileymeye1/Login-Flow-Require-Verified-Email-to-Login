/**
 * @description       : 
 * @author            : Riley Meyer
 * @group             : 
 * @last modified on  : 07-26-2024
 * @last modified by  : Riley Meyer
**/
@isTest
private class SendVerificationEmailActionTest {

    @TestSetup
    static void makeData(){
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User']; 
        User u = new User(Alias = 'veruser', Email='noreply@orion.com', 
            EmailEncodingKey='UTF-8', LastName='verifiedUser', LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', UserName='verifiedUser@testorg.com');

        Database.insert(u, AccessLevel.SYSTEM_MODE);
    }

    @isTest
    static void testNotVerifiedUser() {
        List<User> usersList = [SELECT Id FROM User WHERE LastName = 'verifiedUser'];
        System.assertEquals(1, usersList.size(), 'Should only be one user');

        List<SendVerificationEmailAction.FlowInput> inputList = new List<SendVerificationEmailAction.FlowInput>();
        SendVerificationEmailAction.FlowInput input = new SendVerificationEmailAction.FlowInput();
        input.userId = usersList[0].Id;
        input.emailTemplateId = null;
        input.networkId = null;
        input.landingPageUrl = null;
        inputList.add(input);

        Test.startTest();
        SendVerificationEmailAction.sendEmail(inputList);
        Test.stopTest();

        // No asserts are possible when only sending an email
        // Class and Test make no changes in the Org, make no calls an external service, and do not return a value
    }
}