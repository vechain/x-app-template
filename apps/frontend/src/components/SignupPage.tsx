import React, { useState, FC } from 'react';
import { useNavigate } from 'react-router-dom'; // Updated import
import { Box, Input, Button, Stack, FormControl, FormLabel, Text } from '@chakra-ui/react';

interface SignUpPageProps {
  onSignUp?: (credentials: { email: string; password: string }) => void; // Make it optional
}

const SignUpPage: FC<SignUpPageProps> = ({ onSignUp }) => {
  const [email, setEmail] = useState<string>('');
  const [password, setPassword] = useState<string>('');
  const [confirmPassword, setConfirmPassword] = useState<string>('');
  const [error, setError] = useState<string>('');
  const navigate = useNavigate(); // Updated hook

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    if (!email || !password || !confirmPassword) {
      setError('All fields are required');
      return;
    }

    if (password !== confirmPassword) {
      setError('Passwords do not match');
      return;
    }

    if (onSignUp) {
      onSignUp({ email, password });
    }

    navigate('/login'); // Redirect to login after successful sign-up
  };

  return (
    <Box maxW="md" mx="auto" p={4}>
      <Stack spacing={4} as="form" onSubmit={handleSubmit}>
        <Text fontSize="2xl" fontWeight="bold" textAlign="center">
          Sign Up
        </Text>
        {error && (
          <Text color="red.500" textAlign="center">
            {error}
          </Text>
        )}
        <FormControl id="email" isRequired>
          <FormLabel>Email</FormLabel>
          <Input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="Enter your email"
          />
        </FormControl>
        <FormControl id="password" isRequired>
          <FormLabel>Password</FormLabel>
          <Input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="Enter your password"
          />
        </FormControl>
        <FormControl id="confirm-password" isRequired>
          <FormLabel>Confirm Password</FormLabel>
          <Input
            type="password"
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            placeholder="Confirm your password"
          />
        </FormControl>
        <Button colorScheme="teal" type="submit">
          Sign Up
        </Button>
        <Text textAlign="center">
          Already have an account? <Button variant="link" onClick={() => navigate('/login')}>Login here</Button>
        </Text>
      </Stack>
    </Box>
  );
};

export default SignUpPage;


