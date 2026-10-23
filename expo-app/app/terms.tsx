import { LegalPage } from '../src/legal/LegalPage';

export default function Terms() {
  return (
    <LegalPage
      title="Terms of Service"
      intro="These terms cover your use of Cura, an app that helps families and caregivers look after someone living with dementia. By creating an account you agree to them."
      sections={[
        {
          heading: 'What Cura is, and what it is not',
          body: [
            'Cura helps a family find caregivers near their loved one, keep a shared care profile, record daily check-ins and notes, and message each other across languages.',
            'Cura is not a medical service. It does not diagnose any condition, judge how far a disease has progressed, or recommend changes to medication. When Cura points out a change, it is describing what was recorded, not explaining why it happened. Always talk to a doctor or nurse about health decisions.',
            'Cura is not an emergency service. If someone is hurt, unresponsive, missing, or in danger, call your local emergency number first.',
          ],
        },
        {
          heading: 'Caregivers are independent',
          body: [
            'Caregivers on Cura are not employed by Cura. Cura does not yet verify identity documents, training or background checks. A profile marked "New on Cura" has not been reviewed by anyone.',
            'Families are responsible for checking references and qualifications before inviting someone into a home, and for agreeing pay and hours with the caregiver directly. Payments are not processed inside Cura at this time.',
          ],
        },
        {
          heading: 'Your account',
          body: [
            'Give accurate information about yourself, and only create a care profile for someone you are responsible for or have permission to help.',
            'Keep your password private. You are responsible for what happens under your account.',
            'Do not use Cura to harass anyone, to share someone else\'s information without a good reason, or to post anything unlawful. We may close accounts that do.',
          ],
        },
        {
          heading: 'What you post',
          body: [
            'Notes, check-ins and messages you add belong to you. You let Cura store them and show them to the other members of your care circle, and to translate them so each member can read them in their own language.',
            'Some features send text to an AI service (Google Gemini) to translate messages or write summaries. AI output can be wrong. Treat it as a draft, and check anything important with the person who wrote the original.',
          ],
        },
        {
          heading: 'A student project',
          body: [
            'Cura is built by a student team. It is provided as it is, without guarantees that it will always be available or free of errors. To the extent the law allows, the team is not liable for losses that come from using it.',
            'We may change these terms as the app grows. If the change is significant, we will say so in the app before it applies.',
          ],
        },
      ]}
    />
  );
}
