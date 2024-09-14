import React, { useState } from "react";
import { Box, Button, HStack, Text } from "@chakra-ui/react";
import { Dropzone } from "../components";
import { Link } from "react-router-dom";
import "./form.css";

export default function Form({ type }: { type: "reduce" | "offset" }) {
  const [category, setCategory] = useState("Transport");

  // Define categories based on the type prop
  const categories =
    type === "reduce"
      ? ["Transport", "Self care"]
      : ["Tree planting", "Volunteering"];

  return (
    <Box
      bg="#efefef"
      minHeight="100vh"
      position="relative"
      padding="5"
      color="#2a3d29"
    >
      <div style={{ position: "absolute", top: "10px", right: "10px" }}>
        <Link to="/" style={{ textDecoration: "none" }}>
          <Button
            bg="#2a3d29"
            color="#c5dcc2"
            _hover={{ bg: "#c5dcc2", color: "#2a3d29" }}
            width="200px"
          >
            Go back
          </Button>
        </Link>
      </div>
      <Text textAlign="center" fontSize="5xl" fontWeight="bold">
        How to get your vet?{" "}
      </Text>

      {/* Category area */}
      <Text fontSize="2xl" fontWeight="bold">
        {" "}
        Step 1{" "}
      </Text>
      <Text paddingTop="1"> Step 1asdkjndsfkjcnkjsd </Text>
      <HStack spacing={3} overflowX="auto">
        {categories.map((categoryName) => (
          <Button
            key={categoryName}
            px={4}
            borderRadius="full"
            variant={category === categoryName ? "solid" : "outline"}
            bg={category === categoryName ? "#4e6b4c" : "#c5dcc2"}
            color={category === categoryName ? "#c5dcc2" : "#2a3d29"}
            onClick={() => setCategory(categoryName)}
          >
            {categoryName}
          </Button>
        ))}
      </HStack>

      {/* Dropzone area */}
      <Text fontSize="2xl" fontWeight="bold" paddingTop="2">
        {" "}
        Step 2{" "}
      </Text>
      <Text> Step 1asdkjndsfkjcnkjsd </Text>
      <Dropzone promptType={category} />

      {/* Submit area */}
      <Text fontSize="2xl" fontWeight="bold" paddingTop="2">
        {" "}
        Step 3{" "}
      </Text>
      <Text> Step 1asdkjndsfkjcnkjsd </Text>

      <div style={{ position: "absolute", bottom: "10px", right: "10px" }}>
        <Button
          bg="#2a3d29"
          color="#c5dcc2"
          _hover={{ bg: "#c5dcc2", color: "#2a3d29" }}
          width="100px"
          marginRight="15"
        >
          Generate
        </Button>

        <Button
          bg="#2a3d29"
          color="#c5dcc2"
          _hover={{ bg: "#c5dcc2", color: "#2a3d29" }}
          width="100px"
        >
          Confirm
        </Button>
      </div>
    </Box>
  );
}
