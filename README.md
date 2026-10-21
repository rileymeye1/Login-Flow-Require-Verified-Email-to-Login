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
| `Email_Verification_Required_Login_Flow` | The Login Flow (Screen Flow, runs in system mode without sharing; see Gotcha 10) |
| `Manage_Multi_Factor_Logins`             | Permission set the **deploying** user needs (see Setup)                          |

## Setup

1. Deploy the permission set:
   `sf project deploy start -o <org alias> -m PermissionSet:Manage_Multi_Factor_Logins`
2. Assign it to the user who will deploy the flow:
   `sf org assign permset -o <org alias> -n Manage_Multi_Factor_Logins`
   Without it the flow deploy fails with
   `The field "UserId" for the object "TwoFactorMethodsInfo" doesn't exist.`
3. Deploy the Apex classes and the flow, running the action's tests:
   `sf project deploy start -o <org alias> -l RunSpecifiedTests -t SendVerificationEmailActionTest -m ApexClass:SendVerificationEmailAction ApexClass:SendVerificationEmailActionTest Flow:Email_Verification_Required_Login_Flow`
4. In Setup > Identity > Login Flows, add a Login Flow per profile (internal and/or site profiles)
   pointing at `Email_Verification_Required_Login_Flow`.
   - Leave **Render Flow in Lightning Runtime** unchecked. See [Gotchas](#gotchas-read-before-changing-anything).
   - Login Flow assignments are not deployable metadata; this step is always manual.
   - Roll out to a cloned pilot profile with test users first, then to the remaining profiles. Never
     start with your own System Administrator profile.
5. Test with a real login (see [Testing](#testing)).

### Kill switch

Delete the Login Flow assignment for the profile (Setup > Identity > Login Flows). It takes effect on
the next login, with no deploy. Deactivating the flow also works, but affects every assigned profile.

### Deploying through CI

The flow deploy fails unless the user running it already holds `ManageTwoFactor`, and assigning the
permission set in the same deploy does not help. If your pipeline deploys the whole project as a user
without it, list the flow in `.forceignore` and deploy it separately with steps 1-3. An explicit
`-m Flow:...` deploy does not get past `.forceignore`, so comment the line out for that deploy, confirm
that the output lists the flow, and restore the line. The permission set and Apex can deploy through
CI as normal.

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
10. **The flow must run in System Mode without Sharing.** The user logging in is the running user,
    and ordinary users, including every site user, do not have `ManageTwoFactor`, so they cannot
    read `TwoFactorMethodsInfo`. In user mode both lookups would fail for them, and every login
    would either error or be treated as unverified. System mode without sharing lets the flow read
    the record for any user without granting that admin-level permission set to anyone. Do not
    switch the flow to user context, and do not hand out `Manage_Multi_Factor_Logins` as a
    workaround.

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

Expected behavior:

| Scenario                                           | Expected                                      |
| -------------------------------------------------- | --------------------------------------------- |
| Verified user logs in                              | No screen; straight in                        |
| Unverified internal user                           | Internal screen; email arrives                |
| Unverified site user                               | Community screen; link opens on the site      |
| Click the link, then **Email Verified**            | Logged in, same session                       |
| **Resend Email** checked, then **Email Verified**  | A new email arrives; the screen shows again   |
| **Email Verified** 3 times without clicking a link | Logout message; **Log Out** logs the user out |

## Troubleshooting

| Symptom                                                                          | Cause / fix                                                                 |
| -------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| Deploy: `The field "UserId" for the object "TwoFactorMethodsInfo" doesn't exist` | The deploying user lacks `Manage_Multi_Factor_Logins`; deploy and assign it |
| SOQL: `sObject type 'TwoFactorMethodsInfo' is not supported`                     | Same: the querying user lacks `Manage_Multi_Factor_Logins`                  |
| Permission set deploy: `data value too large` on Description                     | Permission set descriptions are limited to 255 characters                   |
| "We can't display the ... field" at login                                        | A conditional visibility rule was added; see Gotcha 2                       |
| User reaches the org after 3 failed attempts                                     | `Logging_Out` was removed or bypassed; see Gotchas 3 and 4                  |
| **Email Verified** never works without logging in again                          | The post-email decision reads the wrong lookup; see Gotcha 5                |
| Users can skip the flow                                                          | Lightning runtime was enabled on the Login Flow assignment; see Gotcha 1    |

## Background (from the original article)

During the Spring '22 release, Salesforce reiterated the need for users to verify their email
addresses to be able to send emails from within their orgs, including automated emails sent as the
current user. Users in older orgs whose emails were verified with the previous verification method are
now considered unverified, and SSO users may never have verified their emails at all. Unverified users
cannot send email from Salesforce, and automated processes sending email as them fail silently.
Salesforce does not send SSO users verification reminders, which is why this Login Flow exists.
