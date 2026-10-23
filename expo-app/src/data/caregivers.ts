/**
 * The caregiver directory.
 *
 * Profiles are location-independent templates; `caregiversNear` places each one
 * at a stable pseudo-random offset around the person needing care and sorts by
 * real distance. Swapping this file for a real API call is the only change
 * needed to go live.
 */
import type { CaregiverProfile, GeoPoint } from '../models/types';
import { haversineKm, hashUnit, offsetPoint } from '../lib/geo';

interface Template extends Omit<CaregiverProfile, 'location' | 'distanceKm'> {
  /** How far from the client this caregiver typically works, in km. */
  radiusKm: number;
}

const TEMPLATES: Template[] = [
  {
    id: 'cg-priya',
    name: 'Priya Sharma',
    photoInitials: 'PS',
    headline: 'Dementia & memory care specialist',
    bio: '6 years supporting families through memory loss. Calm, unhurried approach, I am at my best with evening restlessness and building a routine that sticks. I speak Marathi at home, so many families find their parent settles faster with me.',
    rating: 4.9,
    reviewCount: 47,
    yearsExperience: 6,
    hourlyRate: 320,
    specialties: ['Memory care', 'Dementia support', 'Evening restlessness', 'Medication reminders'],
    languages: ['Marathi', 'Hindi', 'English'],
    certifications: ['ID verified', 'Background check', 'First aid certified'],
    neighborhood: 'Shivaji Nagar',
    availability: 'Weekday mornings',
    respondsIn: 'Usually replies in 1 hour',
    radiusKm: 1.2,
  },
  {
    id: 'cg-anjali',
    name: 'Anjali Patil',
    photoInitials: 'AP',
    headline: 'Mobility & fall-prevention focus',
    bio: '4 years with elderly clients recovering strength after a fall or surgery. I build up walking slowly and keep detailed daily notes so the family can see progress week to week.',
    rating: 4.7,
    reviewCount: 31,
    yearsExperience: 4,
    hourlyRate: 280,
    specialties: ['Mobility assistance', 'Fall prevention', 'Post-surgery care', 'Physiotherapy follow-through'],
    languages: ['Marathi', 'Hindi'],
    certifications: ['ID verified', 'Background check'],
    neighborhood: 'Deccan',
    availability: 'Available from tomorrow',
    respondsIn: 'Usually replies in 3 hours',
    radiusKm: 2.4,
  },
  {
    id: 'cg-sunita',
    name: 'Sunita Desai',
    photoInitials: 'SD',
    headline: "Alzheimer's care, trained in validation therapy",
    bio: "8 years specialising in Alzheimer's. Trained in validation therapy, I never argue or correct, I meet them where they are. Very structured about medication timing and hydration tracking.",
    rating: 4.8,
    reviewCount: 52,
    yearsExperience: 8,
    hourlyRate: 360,
    specialties: ["Alzheimer's care", 'Personal care', 'Medication management', 'Hydration tracking'],
    languages: ['Hindi', 'English', 'Gujarati'],
    certifications: ['ID verified', 'Background check', 'First aid certified', 'Dementia care diploma'],
    neighborhood: 'Kothrud',
    availability: 'Available this week',
    respondsIn: 'Usually replies in 2 hours',
    radiusKm: 3.1,
  },
  {
    id: 'cg-kavya',
    name: 'Kavya Nair',
    photoInitials: 'KN',
    headline: 'Companionship & daily living support',
    bio: '3 years in home-based elderly care. Warm and chatty, good with someone who is lonely more than unwell. I cook, I sit and talk, and I am patient with people who take a while to trust a new face.',
    rating: 4.6,
    reviewCount: 24,
    yearsExperience: 3,
    hourlyRate: 240,
    specialties: ['Companionship', 'Meal preparation', 'Light housekeeping', 'Appointment escort'],
    languages: ['Malayalam', 'Hindi', 'English'],
    certifications: ['ID verified', 'Background check'],
    neighborhood: 'Aundh',
    availability: 'Available now',
    respondsIn: 'Usually replies in 30 minutes',
    radiusKm: 4.3,
  },
  {
    id: 'cg-meera',
    name: 'Meera Joshi',
    photoInitials: 'MJ',
    headline: 'Overnight & behavioural support',
    bio: '10 years in dementia and behavioural care, much of it overnight. Sundowning is what I know best. Certified in dementia communication, and I write a full handover every morning.',
    rating: 4.9,
    reviewCount: 61,
    yearsExperience: 10,
    hourlyRate: 400,
    specialties: ['Overnight care', 'Sundowning', 'Behavioural support', 'Family handover notes'],
    languages: ['Marathi', 'Hindi', 'English'],
    certifications: ['ID verified', 'Background check', 'First aid certified', 'Dementia communication certified'],
    neighborhood: 'Baner',
    availability: 'Available from next week',
    respondsIn: 'Usually replies in 4 hours',
    radiusKm: 5.6,
  },
  {
    id: 'cg-rahul',
    name: 'Rahul Kulkarni',
    photoInitials: 'RK',
    headline: 'Male attendant, lifting & transfers',
    bio: '5 years as a care attendant. Trained in safe transfers and bed-bound care, helpful when a parent needs physical support that is hard for family to manage alone. Certified nursing assistant.',
    rating: 4.7,
    reviewCount: 38,
    yearsExperience: 5,
    hourlyRate: 300,
    specialties: ['Safe transfers', 'Bed-bound care', 'Personal hygiene', 'Wound dressing support'],
    languages: ['Marathi', 'Hindi', 'English'],
    certifications: ['ID verified', 'Background check', 'Certified nursing assistant'],
    neighborhood: 'Hadapsar',
    availability: 'Weekday afternoons',
    respondsIn: 'Usually replies in 2 hours',
    radiusKm: 6.8,
  },
  {
    id: 'cg-fatima',
    name: 'Fatima Shaikh',
    photoInitials: 'FS',
    headline: 'Diabetes & chronic condition management',
    bio: '7 years supporting clients with diabetes, hypertension and kidney conditions. I track readings carefully, cook to the diet the doctor set, and flag anything drifting out of range early.',
    rating: 4.8,
    reviewCount: 44,
    yearsExperience: 7,
    hourlyRate: 340,
    specialties: ['Diabetes care', 'Blood pressure monitoring', 'Therapeutic diets', 'Vitals logging'],
    languages: ['Hindi', 'Urdu', 'English', 'Marathi'],
    certifications: ['ID verified', 'Background check', 'First aid certified'],
    neighborhood: 'Camp',
    availability: 'Available this week',
    respondsIn: 'Usually replies in 1 hour',
    radiusKm: 3.7,
  },
  {
    id: 'cg-lakshmi',
    name: 'Lakshmi Iyer',
    photoInitials: 'LI',
    headline: 'Palliative & comfort-focused care',
    bio: '9 years in palliative and end-of-life care. Gentle, quiet presence. I focus on comfort, dignity and keeping the family close and informed through every stage.',
    rating: 5.0,
    reviewCount: 29,
    yearsExperience: 9,
    hourlyRate: 380,
    specialties: ['Palliative care', 'Pain comfort', 'Family support', 'Spiritual sensitivity'],
    languages: ['Tamil', 'English', 'Hindi'],
    certifications: ['ID verified', 'Background check', 'Palliative care certified'],
    neighborhood: 'Viman Nagar',
    availability: 'Limited availability',
    respondsIn: 'Usually replies in 6 hours',
    radiusKm: 8.2,
  },
];

/** Caregiver profiles placed around a location, nearest first. */
export function caregiversNear(origin: GeoPoint): CaregiverProfile[] {
  return TEMPLATES
    .map(t => {
      const bearing = hashUnit(t.id, 7) * 360;
      const jitter = 0.75 + hashUnit(t.id, 13) * 0.5; // 0.75×–1.25× the base radius
      const location = offsetPoint(origin, t.radiusKm * jitter, bearing);
      const { radiusKm: _radiusKm, ...profile } = t;
      return { ...profile, location, distanceKm: haversineKm(origin, location) };
    })
    .sort((a, b) => (a.distanceKm ?? 0) - (b.distanceKm ?? 0));
}

export function caregiverById(id: string): Omit<CaregiverProfile, 'location'> | undefined {
  const t = TEMPLATES.find(c => c.id === id);
  if (!t) return undefined;
  const { radiusKm: _radiusKm, ...profile } = t;
  return profile;
}

export const ALL_SPECIALTIES = Array.from(
  new Set(TEMPLATES.flatMap(t => t.specialties)),
).sort();
