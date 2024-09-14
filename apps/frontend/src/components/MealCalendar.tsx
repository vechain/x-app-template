import React, { useState } from 'react';
import Calendar from 'react-calendar';
import 'react-calendar/dist/Calendar.css';

interface MealCalendarProps {
  onDateChange: (date: Date) => void;
}

type ValuePiece = Date | null;
type Value = ValuePiece | [ValuePiece, ValuePiece];

const MealCalendar: React.FC<MealCalendarProps> = ({ onDateChange }) => {
  const [selectedDate, setSelectedDate] = useState<Value>(new Date());

  const handleDateChange = (value: Value) => {
    console.log('Selected Date Value:', value); // Debugging output
    setSelectedDate(value);
    if (Array.isArray(value)) {
      // Handle date range case if needed
      console.log('Selected Date Range:', value);
    } else if (value instanceof Date) {
      onDateChange(value);
    }
  };

  return (
    <div>
      <Calendar 
        onChange={handleDateChange} 
        value={selectedDate} 
      />
    </div>
  );
};

export default MealCalendar;
