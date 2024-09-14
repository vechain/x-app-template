import React, { useState } from 'react';

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
    onExclusionsChange(checked ? [...selectedExclusions, value] : selectedExclusions.filter((exclusion) => exclusion !== value));
  };

  return (
    <div>
      <label>Choose Dietary Preference:</label>
      <select onChange={handlePreferenceChange}>
        {preferences.map((preference, index) => (
          <option key={index} value={preference}>
            {preference}
          </option>
        ))}
      </select>

      <div>
        <h4>Dietary Exclusions:</h4>
        {exclusions.map((exclusion, index) => (
          <div key={index}>
            <input
              type="checkbox"
              value={exclusion}
              onChange={handleExclusionChange}
              id={`exclusion-${index}`}
            />
            <label htmlFor={`exclusion-${index}`}>{exclusion}</label>
          </div>
        ))}
      </div>
    </div>
  );
};

export default DietaryPreferences;
