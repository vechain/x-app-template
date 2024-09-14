import React, { useState } from 'react';
import Calendar from 'react-calendar';
import 'react-calendar/dist/Calendar.css';

interface MealCalendarProps {
  onDateChange: (date: Date) => void;
}

const MealCalendar: React.FC<MealCalendarProps> = ({ onDateChange }) => {
  const [selectedDate, setSelectedDate] = useState<Date | null>(new Date());

  const handleDateChange = (date: Date) => {
    setSelectedDate(date);
    onDateChange(date); // Callback to handle the date in the parent component
  };

  return (
    <div>
      <Calendar onChange={handleDateChange} value={selectedDate} />
    </div>
  );
};

export default MealCalendar;
