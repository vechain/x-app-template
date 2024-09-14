// src/components/MealPlanning.tsx

import React, { useState } from 'react';
import { saveMealPlan } from '../utils/localStorageUtils';
import MealCalendar from './MealCalendar';
import DietaryPreferences from './DietaryPreferences';
import {
  Button,
  Modal,
  ModalOverlay,
  ModalContent,
  ModalHeader,
  ModalBody,
  ModalCloseButton,
  useDisclosure,
  Grid,
  Box,
  Text,
  Center,
  Heading,
} from "@chakra-ui/react";

interface MealPlan {
  date: Date | null;
  preference: string;
  exclusions: string[];
}

const MealPlanning: React.FC = () => {
  const [mealPlan, setMealPlan] = useState<MealPlan>({ date: null, preference: '', exclusions: [] });
  const { isOpen, onOpen, onClose } = useDisclosure();

  const handleDateChange = (date: Date) => {
    setMealPlan((prev) => ({ ...prev, date }));
  };

  const handlePreferenceChange = (preference: string) => {
    setMealPlan((prev) => ({ ...prev, preference }));
  };

  const handleExclusionsChange = (exclusions: string[]) => {
    setMealPlan((prev) => ({ ...prev, exclusions }));
  };

  const handleSubmit = () => {
    saveMealPlan(mealPlan); // Save the meal plan to localStorage
    console.log("Meal Plan Saved:", mealPlan);
    onOpen(); // Open the modal to confirm the meal plan was saved
  };

  return (
    <Center minHeight="70vh" flexDirection="column" p={4}>
      <Box textAlign="center" mb={4}>
        <Heading color="black" as="h1" size="lg" my={10}>Meal Planning</Heading>
      </Box>

      <Grid templateColumns="1fr 1fr 1fr" gap={4} mb={4} width="100%" maxWidth="1200px">
        <Box textAlign="center" mb={4}>
          <Heading color="black" as="h2" size="md" my={10}>Step 1</Heading>
          <Text bg='rgba(0, 128, 0, 0.1)' borderRadius="12px">Select Date</Text>
        </Box>
        <Box textAlign="center" mb={4}>
          <Heading color="black" as="h2" size="md" my={10}>Step 2</Heading>
          <Text bg='rgba(0, 128, 0, 0.1)' borderRadius="12px">Select Dietary Preferences</Text>
        </Box>
        <Box textAlign="center" mb={4}>
          <Heading color="black" as="h2" size="md" my={10}>Step 3</Heading>
          <Text bg='rgba(0, 128, 0, 0.1)' borderRadius="12px">Verify Selected Plan</Text>
        </Box>
      </Grid>

      <Grid templateColumns="1fr 1fr 1fr" gap={4} mb={4} width="100%" maxWidth="1200px">
        <Box display="flex" justifyContent="center" alignItems="center">
          <MealCalendar onDateChange={handleDateChange} />
        </Box>
        <Box display="flex" justifyContent="center" alignItems="center">
          <DietaryPreferences onPreferenceChange={handlePreferenceChange} onExclusionsChange={handleExclusionsChange} />
        </Box>
        <Box display="flex" flexDirection="column" justifyContent="center" alignItems="center">
          <Text>You have Selected</Text>
          <Text>Date: {mealPlan.date?.toLocaleDateString()}</Text>
          <Text>Dietary Preference: {mealPlan.preference}</Text>
          <Text>Exclusions: {mealPlan.exclusions.join(', ')}</Text>
          <Button onClick={handleSubmit} my={12}>Submit</Button>
        </Box>
      </Grid>

      <Modal isOpen={isOpen} onClose={onClose}>
        <ModalOverlay />
        <ModalContent>
          <ModalHeader>Preference Saved!</ModalHeader>
          <ModalCloseButton />
          <ModalBody>Your dietary preference and exclusions have been saved.</ModalBody>
        </ModalContent>
      </Modal>
    </Center>
  );
};

export default MealPlanning;
