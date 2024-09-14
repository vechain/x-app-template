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
    setSelectedDate(value);
    if (value instanceof Date) {
      onDateChange(value);
    }
  };

  return (
    <div>
      <Calendar onChange={handleDateChange} value={selectedDate} />
    </div>
  );
};

export default MealCalendar;