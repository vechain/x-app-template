import React, { useState, FC } from 'react';
import { useNavigate } from 'react-router-dom'; // Updated import
import { Box, Input, Button, Stack, FormControl, FormLabel, Text } from '@chakra-ui/react';

interface LoginPageProps {
  onLogin: (credentials: { email: string; password: string }) => void;
}

const LoginPage: FC<LoginPageProps> = ({ onLogin }) => {
  const [email, setEmail] = useState<string>('');
  const [password, setPassword] = useState<string>('');
  const [error, setError] = useState<string>('');
  const navigate = useNavigate(); // Updated hook

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!email || !password) {
      setError('Both fields are required');
      return;
    }
    onLogin({ email, password });
    navigate('/'); // Redirect to home after login
  };

  return (
    <Box maxW="md" mx="auto" p={4}>
      <Stack spacing={4} as="form" onSubmit={handleSubmit}>
        <Text fontSize="2xl" fontWeight="bold" textAlign="center">
          Login
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
        <Button colorScheme="teal" type="submit">
          Login
        </Button>
        <Text textAlign="center">
          Don't have an account? <Button variant="link" onClick={() => navigate('/signup')}>Sign up</Button>
        </Text>
      </Stack>
    </Box>
  );
};

export default LoginPage;
