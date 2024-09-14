import React, { useState } from 'react';
import {
  Box,
  Select,
  Checkbox,
  VStack,
  FormControl,
  FormLabel,
  CheckboxGroup,
  Heading,
} from '@chakra-ui/react';

interface DietaryPreferencesProps {
  onPreferenceChange: (preference: string) => void;
  onExclusionsChange: (exclusions: string[]) => void;
}

const DietaryPreferences: React.FC<DietaryPreferencesProps> = ({
  onPreferenceChange,
  onExclusionsChange,
}) => {
  const preferences = ['Vegan', 'Vegetarian', 'Keto', 'Paleo', 'Gluten-Free'];
  const exclusions = ['Nuts', 'Dairy', 'Soy', 'Eggs', 'Seafood'];

  const [selectedExclusions, setSelectedExclusions] = useState<string[]>([]);

  const handlePreferenceChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    onPreferenceChange(e.target.value);
  };

  const handleExclusionChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { value, checked } = e.target;
    setSelectedExclusions((prev) =>
      checked ? [...prev, value] : prev.filter((exclusion) => exclusion !== value)
    );
    onExclusionsChange(
      checked
        ? [...selectedExclusions, value]
        : selectedExclusions.filter((exclusion) => exclusion !== value)
    );
  };

  return (
    <Box p={5} borderWidth="1px" borderRadius="md" boxShadow="lg" maxWidth="400px" bg="gray.50">
      
      {/* Meal Type Dropdown */}
      <FormControl mb={6}>
        <FormLabel>Meal Type</FormLabel>
        <Select placeholder="Select" onChange={handlePreferenceChange}>
          {preferences.map((preference, index) => (
            <option key={index} value={preference}>
              {preference}
            </option>
          ))}
        </Select>
      </FormControl>

      {/* Dietary Exclusions Checklist */}
      <FormControl>
        <FormLabel>Dietary Exclusions</FormLabel>
        <CheckboxGroup colorScheme="green">
          <VStack align="start">
            {exclusions.map((exclusion, index) => (
              <Checkbox
                key={index}
                value={exclusion}
                onChange={handleExclusionChange}
                isChecked={selectedExclusions.includes(exclusion)}
              >
                {exclusion}
              </Checkbox>
            ))}
          </VStack>
        </CheckboxGroup>
      </FormControl>
    </Box>
  );
};

export default DietaryPreferences;
