import React, { useState } from 'react';
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
    console.log("Meal Plan Saved:", mealPlan);
    onOpen(); // Open the modal when the button is clicked
  };

  return (
    <Center minHeight="70vh" flexDirection="column" p={4}>
      <Box textAlign="center" mb={4}>
        <Heading color="black" as="h1" size="lg" my={10}>Meal Planning</Heading>
      </Box>

      <Grid
        templateColumns="1fr 1fr 1fr"
        gap={4}
        mb={4}
        width="100%"
        maxWidth="1200px" // Adjust as needed
      >
        <Box textAlign="center" mb={4}>
          <Heading display="flex" justifyContent="center" alignItems="center" color="black" as="h2" size="md" my={10}>Step 1</Heading>
          <Text display="flex" justifyContent="center" alignItems="center" height="50px" bg='rgba(0, 128, 0, 0.1)' borderRadius="12px">Select Date</Text>
        </Box>
        <Box textAlign="center" mb={4}>
          <Heading display="flex" justifyContent="center" alignItems="center" color="black" as="h2" size="md" my={10}>Step 2</Heading>
          <Text display="flex" justifyContent="center" alignItems="center" height="50px" bg='rgba(0, 128, 0, 0.1)' borderRadius="12px">Select Dietary Preferences</Text>
        </Box>
        <Box textAlign="center" mb={4}>
          <Heading display="flex" justifyContent="center" alignItems="center" color="black" as="h2" size="md" my={10}>Step 3</Heading>
          <Text display="flex" justifyContent="center" alignItems="center" height="50px" bg='rgba(0, 128, 0, 0.1)' borderRadius="12px">Verify Selected Plan</Text>
        </Box>
      </Grid>

      {/* First Row: Grid Layout */}
      <Grid
        templateColumns="1fr 1fr 1fr"
        gap={4}
        mb={4}
        width="100%"
        maxWidth="1200px" // Adjust as needed
      >
        {/* Calendar (leftmost column) */}
        <Box display="flex" justifyContent="center" alignItems="center" height="100%">
          <MealCalendar onDateChange={handleDateChange} />
        </Box>

        {/* Dietary Preferences (middle column) */}
        <Box display="flex" justifyContent="center" alignItems="center" height="100%" p={8}>
          <DietaryPreferences
            onPreferenceChange={handlePreferenceChange}
            onExclusionsChange={handleExclusionsChange}
          />
        </Box>

        {/* Remaining display (rightmost column) */}
        <Box display="flex" flexDirection="column" justifyContent="center" alignItems="center" height="100%">
          <Text textDecoration="underline">You have Selected</Text>
          <br/>
          <Text>Date : <Text as="span" fontWeight="bold">{mealPlan.date?.toLocaleDateString()}</Text></Text>
          <br/>
          <Text> Dietary Preference : <Text as="span" fontWeight="bold">{mealPlan.preference}</Text></Text>
          <br/>
          <Text>Exclusions : <Text as="span" fontWeight="bold">{mealPlan.exclusions.join(', ')}</Text></Text>
          <br/>
          <Button onClick={handleSubmit} border="solid 1px black" sx={{
                color: 'black', // Default text color
                _hover: {
                  bg: 'rgba(0, 128, 0, 0.2)',  // Background color on hover
                }}} my={12}>
          Submit
        </Button>
        </Box>
      </Grid>

      {/* Second Row: Submit Button */}
      <Box textAlign="center" mb={4}>
        
      </Box>

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
    </Center>
  );
};

export default MealPlanning;