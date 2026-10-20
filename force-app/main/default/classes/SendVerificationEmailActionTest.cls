/**
 * @description Tests for SendVerificationEmailAction.
 * `sendAsyncEmailConfirmation` returns nothing and changes no records, so these tests assert
 * that the action completes without throwing for single, bulk, and empty inputs.
 * @author Riley Meyer
 * @group Email Verification
 */
@IsTest
private class SendVerificationEmailActionTest {
    private static final String TEST_LAST_NAME = 'verifiedUser';

    @TestSetup
    static void makeData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        List<User> users = new List<User>();
        for (Integer i = 0; i < 2; i++) {
            users.add(
                new User(
                    Alias = 'veruser' + i,
                    Email = 'noreply' + i + '@example.com',
                    EmailEncodingKey = 'UTF-8',
                    LastName = TEST_LAST_NAME,
                    LanguageLocaleKey = 'en_US',
                    LocaleSidKey = 'en_US',
                    ProfileId = p.Id,
                    TimeZoneSidKey = 'America/Los_Angeles',
                    Username = 'verifiedUser' + i + '.' + System.currentTimeMillis() + '@example.com'
                )
            );
        }
        Database.insert(users, AccessLevel.SYSTEM_MODE);
    }

    @IsTest
    static void sendEmailShouldNotThrowForSingleUser() {
        List<User> users = [SELECT Id FROM User WHERE LastName = :TEST_LAST_NAME LIMIT 1];
        Assert.areEqual(1, users.size(), 'Expected the test user to exist');

        Exception caught;
        Test.startTest();
        try {
            SendVerificationEmailAction.sendEmail(
                new List<SendVerificationEmailAction.FlowInput>{ buildInput(users[0].Id) }
            );
        } catch (Exception e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNull(caught, 'Sending a verification email to one user should not throw: ' + caught);
    }

    @IsTest
    static void sendEmailShouldNotThrowForMultipleUsers() {
        List<User> users = [SELECT Id FROM User WHERE LastName = :TEST_LAST_NAME LIMIT 2];
        Assert.areEqual(2, users.size(), 'Expected both test users to exist');

        List<SendVerificationEmailAction.FlowInput> inputs = new List<SendVerificationEmailAction.FlowInput>();
        for (User u : users) {
            inputs.add(buildInput(u.Id));
        }

        Exception caught;
        Test.startTest();
        try {
            SendVerificationEmailAction.sendEmail(inputs);
        } catch (Exception e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNull(caught, 'Sending verification emails to multiple users should not throw: ' + caught);
    }

    @IsTest
    static void sendEmailShouldNotThrowForEmptyInputs() {
        Exception caught;
        Test.startTest();
        try {
            SendVerificationEmailAction.sendEmail(new List<SendVerificationEmailAction.FlowInput>());
        } catch (Exception e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNull(caught, 'An empty input list should be a no-op: ' + caught);
    }

    private static SendVerificationEmailAction.FlowInput buildInput(Id userId) {
        SendVerificationEmailAction.FlowInput input = new SendVerificationEmailAction.FlowInput();
        input.userId = userId;
        return input;
    }
}
