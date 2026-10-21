# Login Flow: Require a Verified Email to Log In

> **Disclaimer:** I did not come up with the original solution, I only implemented and extended it.
> Credit goes to GitHub user [@surajp](https://www.github.com/surajp).
> Original article: [Using Flows to Verify Emails in Salesforce](https://medium.com/@Suraj_Pillai/using-flows-to-verify-emails-in-salesforce-a25858be5f25)

A Salesforce Login Flow that stops users from logging in until their email address is verified. Once a
user is verified they are never prompted again. It works for internal users and for Experience Cloud
(site) users, including users who log in through SAML SSO and so never get Salesforce's own
verification reminders.

## What's in the repo

| Component                                | Purpose                                                                          |
| ---------------------------------------- | -------------------------------------------------------------------------------- |
| `SendVerificationEmailAction`            | Invocable Apex wrapper around `System.UserManagement.sendAsyncEmailConfirmation` |
| `SendVerificationEmailActionTest`        | Tests for the action                                                             |
| `Email_Verification_Required_Login_Flow` | The Login Flow (Screen Flow, runs in system mode without sharing)                |
| `Manage_Multi_Factor_Logins`             | Permission set the **deploying** user needs (see Setup)                          |

## Setup

1. Deploy the permission set: `sf project deploy start -d force-app/main/default/permissionsets`
2. Assign it to the user who will deploy the flow:
   `sf org assign permset -n Manage_Multi_Factor_Logins`
   Without it the flow deploy fails with
   `The field "UserId" for the object "TwoFactorMethodsInfo" doesn't exist.`
3. Deploy the Apex classes and the flow:
   `sf project deploy start -d force-app/main/default/classes -d force-app/main/default/flows`
4. In Setup > Identity > Login Flows, add a Login Flow per profile (internal and/or site profiles)
   pointing at `Email_Verification_Required_Login_Flow`.
   - Leave **Render Flow in Lightning Runtime** unchecked. See [Gotchas](#gotchas-read-before-changing-anything).
   - Login Flow assignments are not deployable metadata; this step is always manual.
   - Test on a cloned profile first, and never assign it to your own admin profile until it works.
5. Test with a real login (see [Testing](#testing)).

## How it works

1. Look up the user's `TwoFactorMethodsInfo` record. If `HasUserVerifiedEmailAddress` is true, the flow
   ends and the user logs in.
2. Otherwise send a verification email through `SendVerificationEmailAction`, passing
   `LoginFlow_UserId` and `LoginFlow_Community`.
3. A decision on `LoginFlow_Community` (blank = internal, set = site) picks the internal or the
   community screen. The community wording does not mention Salesforce.
4. When the user clicks **Email Verified**, look the record up again. If verified, the flow ends and
   the user logs in.
5. If still unverified, increase `attemptCount`. Below 3, resend the email if **Resend Email** was
   checked and show the screen again.
6. At 3 failed attempts, show a message, set `LoginFlow_ForceLogout = true`, and move to the
   `Logging_Out` screen, which logs the user out. Logging in again starts over with a new email.

A user with no `TwoFactorMethodsInfo` record is treated as unverified (fail closed).

### Login Flow variables used

| Variable                | Direction        | Value seen in testing                                                        |
| ----------------------- | ---------------- | ---------------------------------------------------------------------------- |
| `LoginFlow_UserId`      | Input            | The logging-in user's Id                                                     |
| `LoginFlow_Community`   | Input            | Site base URL, e.g. `https://example.my.site.com`. Blank for internal logins |
| `LoginFlow_ForceLogout` | Output (Boolean) | Set to `true` to log the user out                                            |

### The Apex action

Inputs: `userId` (required), and optional `emailTemplateId`, `networkId`, `landingPageUrl` and
`communityUrl`. Null optional inputs mean the default Salesforce verification email and landing page.

When `networkId` is blank and `communityUrl` is set, the action finds the site by comparing each live
site's `Network.getLoginUrl()`, minus `/login`, with `communityUrl` (case-insensitive, trailing `/`
ignored). It queries `Network` once per call. If nothing matches, `networkId` stays null.

## Gotchas (read before changing anything)

Each of these was hit while building this. The flow looks the way it does on purpose.

1. **Do not enable "Render Flow in Lightning Runtime".** Salesforce warns that in Lightning runtime
   users can access Salesforce before finishing the Login Flow, which defeats the purpose. The flow
   must run in Classic runtime.
2. **No conditional field visibility.** Classic runtime cannot render it ("We can't display the
   '...' field, because it uses conditional field visibility rules..."). That is why there are two
   screens chosen by the `Is_the_User_a_Community_User` decision instead of one screen with
   show/hide rules. Decisions also offer _Is Blank_, which visibility rules do not.
3. **`LoginFlow_ForceLogout` is only checked when the flow moves to a screen.** Setting it and then
   going to End is ignored and the user is logged in. `LoginFlow_FinishLocation` (for example a
   `/secur/logout.jsp` redirect) was ignored as well, at least for SAML SSO site logins. The
   `Logging_Out` screen exists only so the flow moves to a screen after the assignment. Users never
   see it.
4. **`Logging_Out` must keep its footer hidden.** If the logout ever fails, the user is left on that
   screen with nothing to click, so the flow cannot finish and log them in. Flow Builder won't let
   both Finish and Back be disabled ("You can set either allowFinish or allowBack to false, but not
   both"), so hide the footer instead of removing the button.
5. **The post-email decision must read `Get_Email_Verification_Info_Post_Email`.** The original flow
   read the first lookup, so clicking **Email Verified** could never succeed in the same session and
   users had to log in again.
6. **Increase `attemptCount` before checking it, and start it at 0.** Checking first gives the user 4
   tries instead of 3.
7. **The Resend Email checkboxes use "Refresh inputs" (`ResetValues`).** With stored values the box
   stays checked when the screen comes back and resends on every click.
8. **`LoginFlow_Community` is a URL, not a Network Id.** That is why the Apex action matches URLs.
   For users who belong to a single site, Salesforce already builds the verification link on that
   site when `networkId` is null. Passing `communityUrl` makes it correct for users in several sites.
9. **The permission set is already minimal.** `TwoFactorMethodsInfo` needs `ManageTwoFactor`
   (labelled "Manage MFA in API"), which depends on `ManageUsers`, which pulls in the other 15
   permissions. Removing any of them makes the deploy fail. The flow itself runs in system mode, so
   end users do not need this permission set.

## Testing

- "Log in as" a user does **not** run Login Flows. Use a real login (username/password or SSO) to the
  internal org or to the site URL.
- To get a fresh unverified user, create one with your own email address. New users get a
  `TwoFactorMethodsInfo` record with `HasUserVerifiedEmailAddress = false` as soon as they are
  created.
- Check a user's status (needs `Manage_Multi_Factor_Logins`):
  `SELECT Id, UserId, HasUserVerifiedEmailAddress FROM TwoFactorMethodsInfo WHERE UserId = '<user Id>'`
- To see what the flow did, add a trace flag on the test user with Workflow logging at FINEST. The
  Login Flow appears as `/loginflow/loginFlow.apexp` requests.
- With SSO, logging out after 3 attempts usually logs the user straight back in through the identity
  provider, which starts the flow again with a new email. That is expected.

Not yet tested end to end: the logout for internal (non-site) logins, and a user with no
`TwoFactorMethodsInfo` record.

## Background (from the original article)

During the Spring '22 release, Salesforce reiterated the need for users to verify their email
addresses to be able to send emails from within their orgs, including automated emails sent as the
current user. Users in older orgs whose emails were verified with the previous verification method are
now considered unverified, and SSO users may never have verified their emails at all. Unverified users
cannot send email from Salesforce, and automated processes sending email as them fail silently.
Salesforce does not send SSO users verification reminders, which is why this Login Flow exists.
