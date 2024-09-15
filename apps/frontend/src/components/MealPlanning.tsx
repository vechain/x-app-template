import React, { useState } from 'react';
import { saveMealPlan } from '../utils/localStorageUtils';
import MealCalendar from './MealCalendar';
import DietaryPreferences from './DietaryPreferences';
import { Link } from 'react-router-dom';
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
  VStack,
} from "@chakra-ui/react";

interface MealPlan {
  date: Date | null;
  preference: string;
  exclusions: string[];
  recipe?: string;
}

const MealPlanning: React.FC = () => {
  const [mealPlan, setMealPlan] = useState<MealPlan>({ date: null, preference: '', exclusions: [] });
  const [isGeneratingRecipe, setIsGeneratingRecipe] = useState(false);
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

  const generateRecipe = async () => {
    setIsGeneratingRecipe(true);
    try {
      const response = await fetch('https://api-inference.huggingface.co/models/gpt2', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer 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`, // Replace with your actual Hugging Face API key
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          inputs: `Generate a recipe based on the following dietary preference and exclusions:\n
            Dietary Preference: ${mealPlan.preference}\n
            Exclusions: ${mealPlan.exclusions.join(', ')}\n
            Recipe:\n`,
          parameters: {
            max_new_tokens: 150,
            temperature: 0.7,
          },
        }),
      });

      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`Failed to generate recipe: ${errorText}`);
      }

      const data = await response.json();
      const recipe = data[0].generated_text || 'No recipe generated.';
      setMealPlan((prev) => ({ ...prev, recipe }));
    } catch (error) {
      // Type assertion for 'error'
      const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred.';
      console.error('Error generating recipe:', error);
      alert(`Failed to generate recipe. Please try again.\n\nError: ${errorMessage}`);
    } finally {
      setIsGeneratingRecipe(false);
    }
  };

  const handleSubmit = async () => {
    if (!mealPlan.date) {
      alert("Please select a date before submitting.");
      return;
    }
    await generateRecipe();
    saveMealPlan(mealPlan);
    console.log("Meal Plan Saved:", mealPlan);
    onOpen();
  };

  return (
    <Center minHeight="70vh" flexDirection="column" p={4}>
      <Box textAlign="center" mb={4}>
        <Heading color="black" as="h1" size="lg" my={10}>Meal Planning</Heading>
      </Box>

      <Grid templateColumns="1fr 1fr 1fr" gap={4} mb={4} width="100%" maxWidth="1200px">
        <Box textAlign="center" mb={4}>
          <Heading color="black" as="h2" size="md" my={10}>Step 1</Heading>
          <Text bg='rgba(0, 128, 0, 0.1)' borderRadius="12px" p={4} fontWeight={700}>Select Date</Text>
        </Box>
        <Box textAlign="center" mb={4}>
          <Heading color="black" as="h2" size="md" my={10}>Step 2</Heading>
          <Text bg='rgba(0, 128, 0, 0.1)' borderRadius="12px" p={4} fontWeight={700}>Select Dietary Preferences</Text>
        </Box>
        <Box textAlign="center" mb={4}>
          <Heading color="black" as="h2" size="md" my={10}>Step 3</Heading>
          <Text bg='rgba(0, 128, 0, 0.1)' borderRadius="12px" p={4} fontWeight={700}>Verify Selected Plan</Text>
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
          <VStack spacing={2} align="start">
            <Text>You have Selected</Text>
            <Text>Date: {mealPlan.date?.toLocaleDateString()}</Text>
            <Text>Dietary Preference: {mealPlan.preference}</Text>
            <Text>Exclusions: {mealPlan.exclusions.join(', ')}</Text>
          </VStack>
          <Button onClick={handleSubmit} my={12} isLoading={isGeneratingRecipe}>
            {isGeneratingRecipe ? 'Generating Recipe...' : 'Generate Recipe and Submit'}
          </Button>
        </Box>
      </Grid>

      <Modal isOpen={isOpen} onClose={onClose} size="xl">
  <ModalOverlay />
  <ModalContent>
    <ModalHeader>Meal Plan Saved!</ModalHeader>
    <ModalCloseButton />
    <ModalBody>
      <VStack spacing={4} align="start">
        <Text>Your meal plan has been saved with the following details:</Text>
        <Text>Date: {mealPlan.date?.toLocaleDateString()}</Text>
        <Text>Dietary Preference: {mealPlan.preference}</Text>
        <Text>Exclusions: {mealPlan.exclusions.join(', ')}</Text>
        <Text fontWeight="bold">Generated Recipe:</Text>
        
        {/* Scrollable Box for the Recipe */}
        <Box bg="gray.100" p={4} borderRadius="md" w="100%" maxHeight="200px" overflowY="auto">
          <Text whiteSpace="pre-wrap">{mealPlan.recipe}</Text>
        </Box>
        
        <Button colorScheme="blue">
          <Link to="/viewSavedPlans" style={{ color: 'inherit', textDecoration: 'none' }}>View Saved Meals</Link>
        </Button>
      </VStack>
    </ModalBody>
  </ModalContent>
</Modal>

    </Center>
  );
};

export default MealPlanning;
