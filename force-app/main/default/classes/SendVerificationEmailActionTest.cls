/**
 * @description Tests for SendVerificationEmailAction.
 * `sendAsyncEmailConfirmation` returns nothing and changes no records, so these tests assert
 * that the action completes without throwing for single, bulk, and empty inputs. Site
 * resolution is tested directly against an in-memory map of site URLs.
 * @author Riley Meyer
 * @group Email Verification
 */
@IsTest
private class SendVerificationEmailActionTest {
    private static final String TEST_LAST_NAME = 'verifiedUser';
    private static final Id MAIN_SITE_ID = '0DB000000000001';
    private static final Id PREFIXED_SITE_ID = '0DB000000000002';

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

    @IsTest
    static void sendEmailShouldNotThrowWhenCommunityUrlIsSet() {
        List<User> users = [SELECT Id FROM User WHERE LastName = :TEST_LAST_NAME LIMIT 1];
        SendVerificationEmailAction.FlowInput input = buildInput(users[0].Id);
        input.communityUrl = 'https://no-such-site.example.com';

        Exception caught;
        Test.startTest();
        try {
            SendVerificationEmailAction.sendEmail(new List<SendVerificationEmailAction.FlowInput>{ input });
        } catch (Exception e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNull(caught, 'An unmatched community URL should fall back to the default site: ' + caught);
    }

    @IsTest
    static void resolveNetworkIdShouldMatchSiteIgnoringCaseAndTrailingSlash() {
        Test.startTest();
        Id result = SendVerificationEmailAction.resolveNetworkId('HTTPS://Example.my.site.com/', siteUrls());
        Test.stopTest();

        Assert.areEqual(MAIN_SITE_ID, result, 'Expected the root site to match the community URL');
    }

    @IsTest
    static void resolveNetworkIdShouldMatchPrefixedSiteOnlyOnFullPath() {
        Test.startTest();
        Id result = SendVerificationEmailAction.resolveNetworkId('https://example.my.site.com/lp', siteUrls());
        Test.stopTest();

        Assert.areEqual(PREFIXED_SITE_ID, result, 'Expected the path-prefixed site, not the root site');
    }

    @IsTest
    static void resolveNetworkIdShouldReturnNullForBlankUrl() {
        Test.startTest();
        Id result = SendVerificationEmailAction.resolveNetworkId('', siteUrls());
        Test.stopTest();

        Assert.isNull(result, 'Internal logins have no community URL and should not resolve a site');
    }

    @IsTest
    static void resolveNetworkIdShouldReturnNullWhenNoSiteMatches() {
        Test.startTest();
        Id result = SendVerificationEmailAction.resolveNetworkId('https://other.my.site.com', siteUrls());
        Test.stopTest();

        Assert.isNull(result, 'An unknown community URL should not resolve a site');
    }

    @IsTest
    static void getLiveSiteUrlsShouldStripLoginPath() {
        Test.startTest();
        Map<Id, String> result = SendVerificationEmailAction.getLiveSiteUrlsByNetworkId();
        Test.stopTest();

        for (String siteUrl : result.values()) {
            Assert.isFalse(siteUrl.endsWith('/login'), 'Site base URL should not end with /login: ' + siteUrl);
            Assert.areEqual(siteUrl.toLowerCase(), siteUrl, 'Site base URL should be lowercase: ' + siteUrl);
        }
    }

    private static Map<Id, String> siteUrls() {
        return new Map<Id, String>{
            MAIN_SITE_ID => 'https://example.my.site.com',
            PREFIXED_SITE_ID => 'https://example.my.site.com/lp'
        };
    }

    private static SendVerificationEmailAction.FlowInput buildInput(Id userId) {
        SendVerificationEmailAction.FlowInput input = new SendVerificationEmailAction.FlowInput();
        input.userId = userId;
        return input;
    }
}
