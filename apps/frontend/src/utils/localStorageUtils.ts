// localStorageUtils.ts

const MEAL_PLANS_KEY = 'mealPlans';

export const saveMealPlan = (mealPlan: any) => {
  const savedPlans = JSON.parse(localStorage.getItem(MEAL_PLANS_KEY) || '[]');
  savedPlans.push(mealPlan);
  localStorage.setItem(MEAL_PLANS_KEY, JSON.stringify(savedPlans));
};

export const getMealPlans = () => {
  const savedPlans = localStorage.getItem(MEAL_PLANS_KEY);
  if (savedPlans) {
    return JSON.parse(savedPlans).map((plan: any) => ({
      ...plan,
      date: new Date(plan.date), // Convert the saved date string back into a Date object
    }));
  }
  return [];
};

export const clearMealPlans = () => {
  localStorage.removeItem(MEAL_PLANS_KEY);
};
