# WorkDay Privacy Policy

_Last updated: September 21, 2026_

WorkDay is an attendance-tracking and payroll app built for small businesses. This policy explains, in plain terms, what information WorkDay collects, where it actually lives, and how you can control or delete it.

**Quick facts**
- Stored in the cloud (Firebase), synced to your account — **not** local-only.
- Reminders are local only — no push notifications from a server.
- No ads, no analytics or tracking SDKs of any kind.
- You can delete your login, or ask us to erase your business data.

## 1. Information we collect

WorkDay collects only what it needs to run daily attendance and payroll for one business:

- **Account information.** When a business owner creates a WorkDay account, Firebase Authentication stores an email address and a securely hashed password (we never see or store it as plain text), plus a display name and the time of your last sign-in.
- **Business and employee records, entered by the account holder.** Organisation name; employee profiles (name, phone number, daily wage, overtime rate, active/inactive status); daily attendance records (status, work units, overtime minutes); payroll settings (currency, pay-period start day, holiday dates, holiday pay multiplier, standard work hours per day).
- **App preferences.** Your chosen daily reminder time, quick-entry overtime presets, and whether "remember login" is turned on for a device.
- **Feedback.** A star rating and optional comment, only if you choose to rate the app.

Employees do not create their own WorkDay accounts or sign in — this information is entered and controlled entirely by the business owner, who is responsible for informing employees that it is recorded. WorkDay does not currently have job-title fields, shift-planning schedules, to-do lists, notes, or theme/language settings — those features do not exist in the app.

## 2. Where your data is stored

All business, employee, and attendance data is stored in Google's **Cloud Firestore**, tied to your account, and encrypted in transit. WorkDay is **not** a local-only app: it is designed to keep your data synced so it's available if you ever sign in from another device.

The app also keeps a temporary offline copy on your phone (Firestore's built-in offline cache) so you can keep taking attendance without a signal — it syncs automatically once you're back online. Uninstalling the app or clearing its storage removes that temporary copy only; it does not delete anything from the cloud.

## 3. Who can access your data

Your business's records are isolated from every other business on WorkDay by Firebase security rules tied to your account — no other customer can read or write them. AscTechSoft keeps one internal, **read-only** support account that can view aggregated reports (attendance totals and payroll summaries) across businesses, used only to help customers and diagnose issues; it cannot edit or delete your records.

## 4. Third-party services

WorkDay is built on Google Firebase. The following Firebase services process data on our behalf, under Google's own privacy policy:

- **Firebase Authentication** — manages sign-in and password security.
- **Cloud Firestore** — stores and syncs your business, employee, attendance, and payroll data.
- **Firebase Remote Config** — lets us turn optional features (such as subscription plan pricing) on or off without an app update; it only downloads small configuration values, never your business data.

These services may process basic technical metadata needed to operate, such as your device's IP address. **WorkDay does not use** Firebase Analytics, Firebase Crashlytics, Firebase Cloud Messaging, advertising SDKs, or any other analytics or tracking service.

## 5. Notifications

WorkDay can remind you, at a time you choose, if some employees haven't been marked present by the end of the day. This reminder is scheduled on your own device using Android's WorkManager and shown as a **local notification** — it is not a push message sent from our servers, and no attendance data passes through a WorkDay server to deliver it. Turn it off any time in *Settings → General*, or disable notification permission for WorkDay in Android's system settings.

## 6. Permissions

WorkDay requests exactly one Android permission: **Notifications** (`POST_NOTIFICATIONS`), to show the daily reminder above. It does not request exact-alarm scheduling, camera, location, contacts, microphone, or storage access — exporting a payroll report to Excel uses temporary app-private storage that doesn't need a storage permission, and is shared onward only through the share sheet you choose (for example Zalo or Google Drive).

## 7. Data retention

Business, employee, and attendance records are kept for as long as your account exists, so payroll history stays available across months and years — WorkDay never deletes it automatically. Reviews you submit are stored indefinitely along with the app version you used. Technical metadata handled by Firebase infrastructure follows Google's own retention schedule.

## 8. Deleting your data

WorkDay separates these two actions on purpose, so a login mistake never destroys months of payroll history:

- **Delete your login only.** In the app, go to *Settings → Account → Delete account* and confirm with your password. Your sign-in is permanently removed and cannot be recovered — you won't be able to sign back in. Your business's attendance and payroll records are kept, in case you need them restored.
- **Delete your business data too.** Contact us (below) and we will permanently erase your business's records from Cloud Firestore.

## 9. Security

Data moving to and from Firebase is encrypted (HTTPS/TLS), and access to your business's records is restricted to your account by Firebase security rules. Passwords are stored in a form that neither we nor Google can read back. No method of transmission or storage can be guaranteed to be completely secure.

## 10. Children's privacy

WorkDay is a business tool intended for use by business owners to manage employees, and it is not directed at children. We do not knowingly collect personal information from children. If you believe a child's information has been entered into WorkDay, contact us and we will remove it.

## 11. Links to other websites

WorkDay's Play Store listing and support channels may link to third-party sites we do not operate. We are not responsible for their content or privacy practices, and recommend reviewing the privacy policy of any external site you visit.

## 12. Changes to this policy

We may update this policy to reflect changes in the app, applicable law, or the third-party services listed above. Updates are posted on this page with a revised "Last updated" date, and take effect when published unless a longer notice period is required by law.

## 13. Contact us

Questions, privacy concerns, or data-deletion requests can go to:

**AscTechSoft** — contact.support@asctechsoft.com
