import { Grid, GridItem, Box, Text, Card } from "@chakra-ui/react";

export default function Milestones() {
  return (
    <Box p={4} zIndex={1000} bg="#4e6b4c" minHeight="100vh">
      {/* `toast` prop is not needed unless custom configuration is passed */}
      <Grid
        templateColumns={{ base: "1fr", md: "2fr 1fr 1fr" }}
        gap={4}
        minHeight="96vh"
      >
        {/* Left side of the page */}
        <Card>
          <Box className="left-section">
            {/* Form component */}
            <Box className="task-form" mb={4}>
              {/* <Form type="task" fetchData={fetchTasks} /> */}
            </Box>
          </Box>
        </Card>

        {/* Center column */}
        <Card>
          <Box textAlign="center">
            <Text fontSize="2xl" fontWeight="bold" mb={2}>
              Task Manager
            </Text>
            <Text fontSize="sm">Note your TO-DOs and keep in check!</Text>
            <Box mt={4}>{/* Badges */}hi</Box>
          </Box>
        </Card>

        {/* Right column */}
        <Card>
          {/* Add any additional content for the right column here */}
        </Card>
      </Grid>
    </Box>
  );
}
