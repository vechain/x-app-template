import React, { useEffect, useState } from 'react';
import { getMealPlans } from '../utils/localStorageUtils'; // Import the utility function
import { Box, Text, Heading, VStack } from '@chakra-ui/react';

interface MealPlan {
  date: Date | null;
  preference: string;
  exclusions: string[];
}

const ViewSavedPlans: React.FC = () => {
  const [savedPlans, setSavedPlans] = useState<MealPlan[]>([]);

  useEffect(() => {
    const plans = getMealPlans(); // Retrieve meal plans using the utility function
    setSavedPlans(plans);
  }, []);

  return (
    <Box p={5} textAlign="center">
      <Heading as="h1" size="lg" mb={6}>Saved Meal Plans</Heading>
      {savedPlans.length === 0 ? (
        <Text>No meal plans saved.</Text>
      ) : (
        <VStack spacing={4}>
          {savedPlans.map((plan, index) => (
            <Box key={index} p={5} borderWidth="1px" borderRadius="md" boxShadow="lg" width="400px" textAlign="left">
              <Text><strong>Date:</strong> {new Date(plan.date as Date).toLocaleDateString()}</Text>
              <Text><strong>Preference:</strong> {plan.preference}</Text>
              <Text><strong>Exclusions:</strong> {plan.exclusions.join(', ')}</Text>
            </Box>
          ))}
        </VStack>
      )}
    </Box>
  );
};

export default ViewSavedPlans;
