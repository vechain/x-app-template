import React, { useState } from 'react';
import MealCalendar from './MealCalendar';
import DietaryPreferences from './DietaryPreferences';
import { Button, Modal, ModalOverlay, ModalContent, ModalHeader, ModalBody, ModalCloseButton, useDisclosure } from "@chakra-ui/react";

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
    console.log("Meal Plan Saved:", mealPlan);
    onOpen(); // Open the modal when the button is clicked
  };

  return (
    <div>
      <h1>Meal Planning</h1>
      <MealCalendar onDateChange={handleDateChange} />
      <DietaryPreferences
        onPreferenceChange={handlePreferenceChange}
        onExclusionsChange={handleExclusionsChange}
      />
      <div>
        <h2>Selected Plan</h2>
        <p>Date: {mealPlan.date?.toLocaleDateString()}</p>
        <p>Dietary Preference: {mealPlan.preference}</p>
        <p>Exclusions: {mealPlan.exclusions.join(', ')}</p>
      </div>

      <Button colorScheme="teal" onClick={handleSubmit}>
        Submit
      </Button>

      {/* Modal */}
      <Modal isOpen={isOpen} onClose={onClose}>
        <ModalOverlay />
        <ModalContent>
          <ModalHeader>Preference Saved!</ModalHeader>
          <ModalCloseButton />
          <ModalBody>
            Your dietary preference and exclusions have been saved.
          </ModalBody>
        </ModalContent>
      </Modal>
    </div>
  );
};

export default MealPlanning;
