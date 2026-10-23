import { LegalPage } from '../src/legal/LegalPage';

export default function Privacy() {
  return (
    <LegalPage
      title="Privacy Policy"
      intro="Care information is some of the most personal information there is. This page says exactly what Cura stores, who can see it, and what you can do about it."
      sections={[
        {
          heading: 'What we store',
          body: [
            'Your account: name, email, phone number if you add one, your relationship to the person you care for, and the language you read in.',
            'The care profile for your loved one: the details the family enters, such as name, age, address, routine, conditions, medications and calming notes.',
            'Everything the care circle adds: daily check-ins, notes, comments and messages.',
            'If you are a caregiver: your public listing, including your work area rounded to about one kilometre. We never store a caregiver\'s home address.',
          ],
        },
        {
          heading: 'Who can see it',
          body: [
            'A care profile, its notes, check-ins and messages are visible only to members of that care circle: the family members who created or joined it, and a caregiver after they accept the family\'s request. This is enforced by the database itself, not only by the app.',
            'Before accepting, a caregiver sees only the family\'s request: the loved one\'s first name, age, general area, listed conditions and mobility. They do not see the full address until they accept.',
            'Caregiver listings (name, area, specialties, languages, rate and bio) are visible to signed-in families searching for care. A caregiver\'s phone number and email are not shown in search.',
          ],
        },
        {
          heading: 'Services we use',
          body: [
            'Supabase hosts the database and handles sign-in. Data is encrypted in transit.',
            'Google Gemini receives the text of messages to translate them, and a summary of the care record when you ask Cura a question or open the home summary. It is not used to advertise to you.',
            'OpenStreetMap (Nominatim) receives the address you type when you search for a location, to turn it into map coordinates.',
          ],
        },
        {
          heading: 'What we do not do',
          body: [
            'We do not sell your data. We do not show ads. We do not share care information with anyone outside your circle except the services listed above, which process it only to provide the feature you used.',
          ],
        },
        {
          heading: 'Your choices',
          body: [
            'You can edit your account and the care profile at any time from the Info tab.',
            'You can delete notes you wrote. To delete your account and everything you added, contact the Cura team and we will remove it.',
            'Cura is meant for adults arranging or providing care. If you are helping a family member as a student, a parent or guardian should set up the account.',
          ],
        },
      ]}
    />
  );
}
