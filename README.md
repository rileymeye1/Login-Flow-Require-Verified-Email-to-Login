# DISCLAIMER: I did not come up with this solution I only implented it.
## Credit goes to GitHub User @surajp (https://www.github.com/surajp)
## Article found here https://medium.com/@Suraj_Pillai/using-flows-to-verify-emails-in-salesforce-a25858be5f25

Steps To Implement In Your Org
1. Deploy Apex Class
2. Deploy Apex Test Class
3. Deploy Permission Set
4. Assign Permission Set to your User. (Without the Permission Set you cannot deploy the Flow because you need access to the TwoFactorMethods Object.)
5. Deploy the Flow
6. Set the Flow as a Login Flow (Setup > Quick Find > Identity > Login Flows)
7. Test with a User
8. ENJOY!


During the Spring’22 release, Salesforce reiterated the need for users to verify their email addresses to be able to send emails from within their orgs. This includes any automated emails that are sent as the current user. Reason being that there are users in older orgs whose emails were verified using the previous generation of Salesforce’s email verification method who are now considered “unverified” according to their current email verification method. There’s also SSO users who may have never verified their emails. As of Winter’23, Salesforce plans to prevent users whose emails have not been verified with their current verification method from sending emails. To remind users to verify their emails, Salesforce had also announced that they would be sending them verification requests once in Spring’22 and again in Summer’22 when an unverified user tries to send an email.

As for SSO users, Salesforce does not have any plans of sending them reminder emails at this time. These users,too, are unable to send emails from Salesforce until they verify their emails and any automated processes sending emails as them fails silently.

Fortunately, there is a simple solution to this problem that also serves to nicely illustrate the combined power of Flows and Apex. For best results, the Flow should be configured as a Login Flow that doesn’t let the user proceed till they verify their email.

Salesforce Login Flow to verify user emails
The process starts by querying the TwoFactorMethodsInfo object for the user in question. (Note: The running user needs Manage Multi-Factor Logins permission to see this object, which shouldn’t matter during actual runs since the Flow needs to be configured to run in System mode. However, during development and debugging you may find yourself needing this permission). If you do decide to make this a login flow, define an input variable called LoginFlow_UserId which automatically gets set to the current user’s Id. (For additional Login Flow variables, refer to this page.)

Get TwoFactorMethodsInfo records for current user
Next we check to see if the HasUserVerifiedEmailAdress field is set to true on the TwofactorMethodInfo record for this user. If not, the user hasn’t verified their email. We then use an Invocable Action to send a verification email to them and show them a message requesting that they click the link in the email before moving ahead in the Flow. The action is quite barebones and is merely a bulkified wrapper around the UserManagement.sendAsyncEmailConfirmation method.

Invocable action to send verification email
EmailTemplateId is optional, and if left null, Salesforce sends the standard verification email. NetworkId should be null for internal users and should be the relevant Community Id for external users. landingPageUrl may be left blank as well as the user will be redirected to the Org/Site Home Page once they complete the Login Flow.

When the user proceeds from this screen, we query the TwoFactorMethodInfo object again to check if their email is now verified. If it still isn’t we go back to the screen requesting them to click the link. They can optionally choose to have the email resent.

As stated earlier, for best results, configure this as a Login Flow running in the System context (since the user logging in may not have access to the TwoFactorMethodsInfo object). Doing so will ensure all users in your org have emails verified with Salesforce’s new verification method. Orgs not using SSO can turn this Flow off after a reasonable amount of time as new users will always have verified emails. For orgs using SSO, I’d recommend keeping this Login Flow in place to ensure their users’ emails are always verified.
